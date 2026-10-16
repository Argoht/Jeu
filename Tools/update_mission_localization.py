from __future__ import annotations

import re
from pathlib import Path


TRANSLATIONS = {
    "a_agilite_vi": ("Agility VI", "Do 200 burpees during the day."),
    "a_calcul_de_bataille": ("Battle Calculation", "Learn new skills or develop your knowledge in specific fields."),
    "a_cardio": ("Cardio", "Do 3 hours of continuous effort."),
    "a_controle": ("Control", "Complete an advanced mobility or balance session."),
    "a_corps_delite": ("Elite Body", "Complete a triathlon: swimming, cycling, and running on the same day."),
    "a_corps_en_surcharge": ("Overloaded Body", "Do 90 minutes of continuous physical activity."),
    "a_force_vi": ("Strength VI", "Do 200 push-ups during the day."),
    "a_limiteur_brise": ("Broken Limiter", "Do an intense 45-minute workout."),
    "a_maitrise_corporelle": ("Body Mastery", "Do a street workout session and train on advanced figures."),
    "a_puissance": ("Power", "Do a high-intensity sport session (HIIT) for at least 20 minutes."),
    "a_rigueur": ("Rigor", "Wake up before 6:00."),
    "a_sixieme_sens": ("Sixth Sense", "Spend a full day without music or digital distraction."),
    "a_souffle": ("Breath", "Complete 3 heart-coherence breathing sessions of 5 minutes during the day."),
    "a_souffle_inepuisable": ("Unending Breath", "Run 12 km."),
    "a_volonte_du_predateur": ("Predator's Will", "Do a difficult activity you have been postponing for a long time."),
    "b_agilite": ("Agility", "Complete a full mobility session."),
    "b_agilite_v": ("Agility V", "Do 100 burpees, or four sets of 30."),
    "b_chemin_de_la_sagesse": ("Path of Wisdom", "Meditate 15 to 20 minutes per day for 1 week."),
    "b_endurance_delite": ("Elite Endurance", "Run 8 km."),
    "b_esprit_du_stratege": ("Strategist's Mind", "Read and summarize a book or knowledge about self-development or strategy."),
    "b_force_v": ("Strength V", "Do 100 push-ups, or four sets of 30."),
    "b_instinct_de_combat": ("Combat Instinct", "Do 30 minutes of combat, reflex, and coordination training."),
    "b_lecture": ("Reading", "Read 30 pages of a book or watch 3 educational videos, about 45 minutes total."),
    "b_marathon_mental": ("Mental Marathon", "Work or study for 3 hours."),
    "b_mental": ("Mental", "Take a cold shower."),
    "b_protocole_respiratoire": ("Breathing Protocol", "Complete 3 heart-coherence breathing sessions of 5 minutes during the day."),
    "b_souplesse": ("Flexibility", "Work on mobility and flexibility."),
    "b_volonte_inflexible": ("Unbending Will", "Wake up at 7:00 for 5 days."),
    "c_activite": ("Activity", "Walk 8 km."),
    "c_agilite_iv": ("Agility IV", "Do 70 burpees, or three sets of 25."),
    "c_entrainement_continu": ("Continuous Training", "Train for 45 minutes without interruption."),
    "c_force_explosive": ("Explosive Strength", "Run three 500-meter intervals with 5 minutes of rest between them."),
    "c_force_iv": ("Strength IV", "Do 70 push-ups, or three sets of 25."),
    "c_immersion_glaciale": ("Ice Immersion", "Take a fully cold shower for at least 5 minutes."),
    "c_mental_renforce": ("Reinforced Mind", "Spend 24 hours without junk food or industrial sugar."),
    "c_respiration_du_predateur": ("Predator's Breath", "Run 5 km without stopping."),
    "d_agilite_iii": ("Agility III", "Do 50 burpees, or three sets of 20."),
    "d_bapteme_du_froid": ("Cold Baptism", "Finish your shower with 2 full minutes of cold water."),
    "d_charge_continue": ("Continuous Load", "Take 10,000 steps during the day."),
    "d_coherence_cardiaque": ("Heart Coherence", "Complete 2 heart-coherence breathing sessions during the day."),
    "d_deplacement_fantome": ("Ghost Movement", "Do a 15-minute HIIT workout."),
    "d_entrainements_double": ("Double Training", "Do two training sessions on the same day."),
    "d_etudes": ("Studies", "Read 20 pages or watch 1 hour of educational videos."),
    "d_force": ("Strength", "Complete a full sport session."),
    "d_force_iii": ("Strength III", "Do 50 push-ups, or three sets of 20."),
    "d_mouvement": ("Movement", "Walk 7 km."),
    "d_pleine_conscience": ("Mindfulness", "Meditate for 20 minutes while focusing on your breathing."),
    "d_resistance": ("Resistance", "Complete an intense physical effort."),
    "d_soin_de_soi": ("Self-Care", "Groom your beard or body hair and improve your general style."),
    "d_volonte_aceree": ("Sharpened Will", "Finish an important task without interruption."),
    "e_agilite_ii": ("Agility II", "Do 25 burpees."),
    "e_apparence": ("Appearance", "Take a shower and care for your face."),
    "e_apprentissage": ("Learning", "Read 10 pages of a book or watch about 30 minutes of educational content."),
    "e_concentration_totale": ("Total Concentration", "Spend one hour without social media."),
    "e_corps_en_forme": ("Fit Body", "Complete 5 sport sessions during the week."),
    "e_discipline_hebdomadaire": ("Weekly Discipline", "Hold your routine for the whole week."),
    "e_endurance": ("Endurance", "Walk 5 km during the day."),
    "e_endurance_froide": ("Cold Endurance", "Finish your shower with 1 full minute of cold water."),
    "e_force_ii": ("Strength II", "Do 25 push-ups."),
    "e_lecture": ("Reading", "Read for 30 minutes without checking your phone."),
    "e_rythme_du_combat": ("Combat Rhythm", "Do 3 sets of jump rope for 1 minute each."),
    "e_souffle_etendu": ("Expanded Breath", "Do 10 minutes of controlled breathing during the day."),
    "e_sport": ("Sport", "Complete one sport session."),
    "f_agilite_i": ("Agility I", "Do 10 burpees."),
    "f_concentration_basique_i": ("Basic Concentration I", "Read 10 pages of a book."),
    "f_discipline_i": ("Discipline I", "Go to class or work."),
    "f_fondation_i": ("Foundation I", "Do one physical activity every day for 5 consecutive days."),
    "f_force_i": ("Strength I", "Do 10 push-ups."),
    "f_hygiene_i": ("Hygiene I", "Brush your teeth morning and night."),
    "f_marche_i": ("Walk I", "Travel 2 km."),
    "f_motivation_i": ("Motivation I", "Take a 30-second cold shower."),
    "f_respiration_i": ("Breathing I", "Do 5 minutes of controlled breathing."),
    "f_reveil_i": ("Wake-Up I", "Do 5 minutes of stretching or muscle activation."),
    "f_routine_i": ("Routine I", "Tidy or clean your workspace or bedroom."),
    "s_agilite_vii": ("Agility VII", "Do 300 burpees during the day."),
    "s_calme_max": ("Calm MAX", "Meditate for at least 180 minutes."),
    "s_discipline_max": ("Discipline MAX", "Respect all important habits for 60 days."),
    "s_endurance_max": ("Endurance MAX", "Run 20 km."),
    "s_focus_max": ("Focus MAX", "Complete 3 heart-coherence breathing sessions of 30 minutes."),
    "s_force_vii": ("Strength VII", "Do 300 push-ups during the day."),
    "s_performance_max": ("Performance MAX", "Do 3 hours of cardio."),
    "s_routine_max": ("Routine MAX", "Complete 6 days of training."),
    "s_symbiose_max": ("Symbiosis MAX", "Train agility, mobility, and body flexibility in one workout."),
}


def gd_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_french_missions(root: Path) -> dict[str, tuple[str, str]]:
    missions: dict[str, tuple[str, str]] = {}
    for path in sorted(root.rglob("*.tres")):
        text = path.read_text(encoding="utf-8")
        mission_id = _match_value(text, "id")
        title = _match_value(text, "title")
        description = _match_value(text, "description")
        if mission_id:
            missions[mission_id] = (title, description)
    return missions


def _match_value(text: str, key: str) -> str:
    match = re.search(rf'^{key} = "([^"]*)"', text, re.MULTILINE)
    return match.group(1) if match else ""


def build_block(values: dict[str, tuple[str, str]]) -> str:
    lines: list[str] = []
    for mission_id in sorted(values):
        title, description = values[mission_id]
        lines.append(f'\t"mission_data.{mission_id}.title": {gd_string(title)},')
        lines.append(f'\t"mission_data.{mission_id}.description": {gd_string(description)},')
    return "\n".join(lines)


def replace_mission_block(source: str, const_name: str, new_block: str) -> str:
    header = f"const {const_name} := {{"
    start = source.index(header)
    next_const = source.find("\nconst ", start + len(header))
    end = next_const if next_const != -1 else source.index("\n}\n", start) + 3
    section = source[start:end]
    section = re.sub(r'\n\t"mission_data\.[^"]+": "[^"]*",', "", section)
    insert_at = section.rfind("\n}")
    section = section[:insert_at] + "\n" + new_block + section[insert_at:]
    return source[:start] + section + source[end:]


def main() -> None:
    localization_path = Path("Scripts/Core/Localization.gd")
    missions = parse_french_missions(Path("Data/Missions/Humanized"))
    missing = sorted(set(missions) - set(TRANSLATIONS))
    extra = sorted(set(TRANSLATIONS) - set(missions))
    if missing or extra:
        raise RuntimeError(f"Translation mismatch. Missing={missing}, extra={extra}")

    source = localization_path.read_text(encoding="utf-8")
    source = replace_mission_block(source, "EN", build_block(TRANSLATIONS))
    source = replace_mission_block(source, "FR", build_block(missions))
    localization_path.write_text(source, encoding="utf-8", newline="\n")
    print(f"Updated localization for {len(missions)} missions.")


if __name__ == "__main__":
    main()
