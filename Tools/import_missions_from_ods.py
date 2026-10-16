from __future__ import annotations

import argparse
import re
import unicodedata
import zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET


TABLE_NS = "urn:oasis:names:tc:opendocument:xmlns:table:1.0"
TEXT_NS = "urn:oasis:names:tc:opendocument:xmlns:text:1.0"

RANKS = {"F": 0, "E": 1, "D": 2, "C": 3, "B": 4, "A": 5, "S": 6}
STAT = {
    "AUCUNE": 0,
    "STR": 1,
    "DEX": 2,
    "VIT": 3,
    "INT": 4,
    "WIS": 5,
    "CHA": 6,
    "PER": 7,
    "WIL": 8,
}

DAILY_XP = {"F": 100, "E": 250, "D": 600, "C": 1300, "B": 2800, "A": 6000, "S": 11000}
WEEKLY_XP = {"F": 600, "E": 1000, "D": 1800, "C": 3600, "B": 7000, "A": 15000, "S": 22000}
REQ_BASE = {"F": 0, "E": 8, "D": 16, "C": 26, "B": 36, "A": 48, "S": 64}
REWARD_AMOUNT = {"F": 1, "E": 1, "D": 1, "C": 1, "B": 2, "A": 2, "S": 3}


def read_ods_rows(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("content.xml"))

    table = root.find(f".//{{{TABLE_NS}}}table")
    if table is None:
        raise RuntimeError("No table found in ODS file")

    rows: list[list[str]] = []
    for tr in table.findall(f"{{{TABLE_NS}}}table-row"):
        row: list[str] = []
        for tc in tr.findall(f"{{{TABLE_NS}}}table-cell"):
            repeat = int(tc.attrib.get(f"{{{TABLE_NS}}}number-columns-repeated", "1"))
            value = " ".join(
                "".join(p.itertext()).strip()
                for p in tc.findall(f"{{{TEXT_NS}}}p")
            ).strip()
            if repeat > 20 and not value:
                repeat = 1
            row.extend([value] * repeat)
        while row and row[-1] == "":
            row.pop()
        if any(row):
            rows.append(row)
    return rows


def extract_quests(rows: list[list[str]]) -> list[dict[str, str]]:
    quests: list[dict[str, str]] = []
    for row in rows[2:]:
        if len(row) < 4:
            continue
        title, description, rank, mission_type = [cell.strip() for cell in row[:4]]
        if not title or rank.upper() not in RANKS:
            continue
        quests.append({
            "title": title,
            "description": description,
            "rank": rank.upper(),
            "type": mission_type,
        })
    return quests


def slugify(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")
    return slug or "mission"


def infer_primary_stat(title: str, description: str) -> str:
    text = f"{title} {description}".lower()
    checks = [
        ("STR", ["pompe", "force", "musculation", "traction"]),
        ("DEX", ["burpee", "agilit", "mobilit", "equilibre", "réflex", "reflex", "street workout", "figure"]),
        ("VIT", ["courir", "course", "cardio", "km", "endurance", "effort", "hiit", "sport", "physique", "marche", "triathlon"]),
        ("INT", ["lire", "livre", "apprendre", "compétence", "competence", "culture", "étude", "etude", "cours", "travail"]),
        ("CHA", ["social", "groupe", "leadership", "coaching", "conversation"]),
        ("PER", ["observation", "perception", "précision", "precision", "sixième sens", "sixieme sens"]),
        ("WIS", ["méditation", "meditation", "respiration", "cohérence", "coherence", "silence"]),
        ("WIL", ["discipline", "volonté", "volonte", "réveil", "reveil", "douche froide", "habitude", "difficile", "contrôle", "controle"]),
    ]
    for stat, markers in checks:
        if any(marker in text for marker in markers):
            return stat
    return "WIL"


def mission_type_index(raw_type: str) -> int:
    lower = raw_type.lower()
    if "hebdo" in lower or "mens" in lower:
        return 1
    return 0


def difficulty_bonus(text: str) -> int:
    lower = text.lower()
    bonus = 0
    if re.search(r"\b(90|120|180)\s*(min|minute)", lower) or re.search(r"\b[23]\s*h", lower):
        bonus += 8
    if re.search(r"\b(12|20)\s*km", lower):
        bonus += 8
    if re.search(r"\b(200|300)\s*(pompes|burpees)", lower):
        bonus += 7
    if any(marker in lower for marker in ["triathlon", "60 jours", "7 jours", "extrême", "extreme", "max"]):
        bonus += 10
    return bonus


def round_xp(value: int) -> int:
    step = 500 if value >= 10000 else 100 if value >= 1000 else 50
    return max(step, round(value / step) * step)


def build_mission(quest: dict[str, str], used_ids: Counter[str]) -> dict[str, object]:
    rank = quest["rank"]
    type_index = mission_type_index(quest["type"])
    title = quest["title"]
    description = quest["description"].strip()
    if description and description[-1] not in ".!?":
        description += "."

    stat = infer_primary_stat(title, description)
    text = f"{title} {description}"
    base = WEEKLY_XP[rank] if type_index == 1 else DAILY_XP[rank]
    xp = round_xp(base + base * difficulty_bonus(text) // 100)

    req = REQ_BASE[rank] + difficulty_bonus(text)
    if type_index == 1:
        req += 5
    reward_amount = REWARD_AMOUNT[rank] + (1 if type_index == 1 and rank in {"A", "S"} else 0)
    reward_amount = min(4, reward_amount)

    base_id = f"{rank.lower()}_{slugify(title)}"
    used_ids[base_id] += 1
    mission_id = base_id if used_ids[base_id] == 1 else f"{base_id}_{used_ids[base_id]}"

    return {
        "id": mission_id,
        "title": title,
        "description": description,
        "rank": RANKS[rank],
        "rank_letter": rank,
        "type": type_index,
        "raw_type": quest["type"],
        "base_xp": xp,
        "reward_stat": STAT[stat],
        "reward_stat_amount": reward_amount,
        "req_stat": stat,
        "req_value": req,
        "proof_required": rank == "S" or type_index == 1 or any(
            marker in text.lower()
            for marker in ["triathlon", "coaching", "60 jours", "extrême", "extreme"]
        ),
    }


def godot_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def mission_to_tres(mission: dict[str, object]) -> str:
    lines = [
        '[gd_resource type="Resource" script_class="MissionData" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://Scripts/Resources/MissionData.gd" id="1_mission"]',
        "",
        "[resource]",
        'script = ExtResource("1_mission")',
        f"id = {godot_string(str(mission['id']))}",
        f"title = {godot_string(str(mission['title']))}",
        f"description = {godot_string(str(mission['description']))}",
        f"rank = {mission['rank']}",
        f"type = {mission['type']}",
    ]

    req_key = {
        "STR": "req_str",
        "DEX": "req_dex",
        "VIT": "req_end",
        "INT": "req_int",
        "WIS": "req_wis",
        "CHA": "req_cha",
        "PER": "req_per",
        "WIL": "req_wil",
    }[str(mission["req_stat"])]
    if int(mission["req_value"]) > 0:
        lines.append(f"{req_key} = {mission['req_value']}")

    lines.extend([
        f"base_xp = {mission['base_xp']}",
        f"reward_stat = {mission['reward_stat']}",
        f"reward_stat_amount = {mission['reward_stat_amount']}",
    ])
    if bool(mission["proof_required"]):
        lines.append("proof_required = true")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ods_path", type=Path)
    parser.add_argument("--out", type=Path, default=Path("Data/Missions/Humanized"))
    args = parser.parse_args()

    quests = extract_quests(read_ods_rows(args.ods_path))
    used_ids: Counter[str] = Counter()
    missions = [build_mission(quest, used_ids) for quest in quests]

    args.out.mkdir(parents=True, exist_ok=True)
    for old_file in args.out.rglob("*.tres"):
        old_file.unlink()
    for rank in RANKS:
        (args.out / rank).mkdir(parents=True, exist_ok=True)

    for mission in missions:
        target = args.out / str(mission["rank_letter"]) / f"{mission['id']}.tres"
        target.write_text(mission_to_tres(mission), encoding="utf-8", newline="\n")

    by_rank = Counter(str(mission["rank_letter"]) for mission in missions)
    by_type = Counter("Hebdomadaire" if int(mission["type"]) == 1 else "Quotidienne" for mission in missions)
    adapted = [mission for mission in missions if str(mission["raw_type"]).lower().startswith("mens")]
    print(f"Imported {len(missions)} missions into {args.out}")
    print("By rank:", dict(sorted(by_rank.items())))
    print("By type:", dict(sorted(by_type.items())))
    if adapted:
        print("Adapted monthly missions as weekly:", ", ".join(str(mission["title"]) for mission in adapted))


if __name__ == "__main__":
    main()
