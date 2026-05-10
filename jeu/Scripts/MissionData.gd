class_name MissionData
extends Resource

## Énumérations pour structurer les données proprement
enum Rank { F, E, D, C, B, A, S }
enum MissionType { QUOTIDIENNE, HEBDOMADAIRE }
enum Stat { AUCUNE, STR, DEX, END, INT, WIS, CHA, PER, WIL }

@export_category("Informations Générales")
@export var id: String = "mission_001"
@export var title: String = "Nouvelle Mission"
@export_multiline var description: String = "Description de la tâche IRL..."
@export var rank: Rank = Rank.F
@export var type: MissionType = MissionType.QUOTIDIENNE

@export_category("Pré-requis des Statistiques")
@export var req_str: int = 0
@export var req_dex: int = 0
@export var req_end: int = 0
@export var req_int: int = 0
@export var req_wis: int = 0
@export var req_cha: int = 0
@export var req_per: int = 0
@export var req_wil: int = 0

@export_category("Récompenses de Base")
@export var base_xp: int = 50
@export var reward_stat: Stat = Stat.AUCUNE
@export var reward_stat_amount: int = 0

## Cette fonction servira plus tard pour le système d'adaptation dynamique
func get_adapted_xp(player_rank: int) -> int:
	# La logique de calcul du multiplicateur d'XP selon l'écart de rang ira ici
	return base_xp
