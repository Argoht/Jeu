# Catalogue des missions

Source chargee en jeu: `Data/Missions/Humanized/` uniquement, car `MissionManager` ne charge les anciennes missions que si ce dossier est vide.
Nombre de missions: **83**.

## Regles globales

- Le jeu affiche 5 missions quotidiennes et 1 mission hebdomadaire.
- Cout de lancement: 15 END pour une quotidienne, 40 END pour une hebdomadaire.
- Reset quotidien: 4 heures. Reset hebdomadaire: 7 jours.
- Les recompenses completes des quotidiennes sont limitees a 10 missions consommees par jour; ensuite elles passent en journal uniquement.
- En cas de succes recompense: XP + stat. Les materiaux de base sont coupes pendant que l onglet Base est en `A VENIR`.
- En cas d echec: perte de HP selon le rang de la mission, avec +12 HP de penalite pour une hebdomadaire.
- Tranches de rang joueur: F 1-10, E 11-25, D 26-40, C 41-55, B 56-70, A 71-85, S 86-100.

## Repartition

- Rang F: 11 missions (10 quotidiennes, 1 hebdomadaires)
- Rang E: 13 missions (11 quotidiennes, 2 hebdomadaires)
- Rang D: 14 missions (13 quotidiennes, 1 hebdomadaires)
- Rang C: 8 missions (8 quotidiennes, 0 hebdomadaires)
- Rang B: 13 missions (12 quotidiennes, 1 hebdomadaires)
- Rang A: 15 missions (14 quotidiennes, 1 hebdomadaires)
- Rang S: 9 missions (6 quotidiennes, 3 hebdomadaires)

## Points d audit

- Corrige: les objectifs avec espaces dans les nombres, comme `10 000 pas`, sont maintenant lus comme 10000.
- A surveiller: certaines missions vagues reposent sur la duree par defaut, par exemple `b_mental` demande seulement "Douche Froide" mais impose 18 minutes car c est une quotidienne rang B.
- A surveiller: `s_discipline_max` demande 60 jours alors que le reset hebdomadaire dure 7 jours; le joueur peut progresser manuellement, mais l intention est incoherente.
- A corriger plus tard: `c_force_explosive` contient une phrase cassee, et `f_fondation_i` contient `5 joues cons?cutifs`.
- A noter: l interface Base est maintenant en `A VENIR`; ses bonus et ses gains de materiaux sont desactives tant que la feature est cachee.

## Rang F

| Type | ID | Titre | EN | XP | Stat | END | Validation | Echec | Req. |
|---|---|---|---|---:|---|---:|---|---:|---|
| Quotidienne | `f_agilite_i` | Agilité I | Agility I | 100 | +1 AGI | 15 | 3 min + 10 reps | -10 HP | - |
| Quotidienne | `f_concentration_basique_i` | Concentration Basique I | Basic Concentration I | 100 | +1 INT | 15 | 3 min + 10 pages | -10 HP | - |
| Quotidienne | `f_discipline_i` | Discipline I | Discipline I | 100 | +1 INT | 15 | 3 min | -10 HP | - |
| Quotidienne | `f_force_i` | Force I | Strength I | 100 | +1 STR | 15 | 3 min + 10 reps | -10 HP | - |
| Quotidienne | `f_hygiene_i` | Hygiène I | Hygiene I | 100 | +1 WIL | 15 | 3 min | -10 HP | - |
| Quotidienne | `f_marche_i` | Marche I | Walk I | 100 | +1 HP | 15 | 3 min + 2 km | -10 HP | - |
| Quotidienne | `f_motivation_i` | Motivation I | Motivation I | 100 | +1 WIL | 15 | 3 min | -10 HP | - |
| Quotidienne | `f_respiration_i` | Respiration I | Breathing I | 100 | +1 WIL | 15 | 5 min | -10 HP | - |
| Quotidienne | `f_routine_i` | Routine I | Routine I | 100 | +1 INT | 15 | 3 min | -10 HP | - |
| Quotidienne | `f_reveil_i` | Réveil I | Wake-Up I | 100 | +1 WIL | 15 | 5 min | -10 HP | - |
| Hebdomadaire | `f_fondation_i` | Fondation I | Foundation I | 600 | +1 HP | 40 | 20 min + preuve | -22 HP | END 5 |

## Rang E

| Type | ID | Titre | EN | XP | Stat | END | Validation | Echec | Req. |
|---|---|---|---|---:|---|---:|---|---:|---|
| Quotidienne | `e_agilite_ii` | Agilité II | Agility II | 250 | +1 AGI | 15 | 5 min + 25 reps | -15 HP | AGI 8 |
| Quotidienne | `e_apparence` | Apparence | Appearance | 250 | +1 WIL | 15 | 5 min | -15 HP | WIL 8 |
| Quotidienne | `e_apprentissage` | Apprentissage | Learning | 250 | +1 INT | 15 | 30 min + 10 pages | -15 HP | INT 8 |
| Quotidienne | `e_concentration_totale` | Concentration Totale | Total Concentration | 250 | +1 WIL | 15 | 5 min | -15 HP | WIL 8 |
| Quotidienne | `e_endurance` | Endurance | Endurance | 250 | +1 HP | 15 | 5 min + 5 km | -15 HP | END 8 |
| Quotidienne | `e_endurance_froide` | Endurance froide | Cold Endurance | 250 | +1 HP | 15 | 1 min | -15 HP | END 8 |
| Quotidienne | `e_force_ii` | Force II | Strength II | 250 | +1 STR | 15 | 5 min + 25 reps | -15 HP | STR 8 |
| Quotidienne | `e_lecture` | Lecture | Reading | 250 | +1 INT | 15 | 30 min | -15 HP | INT 8 |
| Quotidienne | `e_rythme_du_combat` | Rythme du Combat | Combat Rhythm | 250 | +1 WIL | 15 | 1 min | -15 HP | WIL 8 |
| Quotidienne | `e_souffle_etendu` | Souffle Étendu | Expanded Breath | 250 | +1 WIL | 15 | 10 min | -15 HP | WIS 8 |
| Quotidienne | `e_sport` | Sport | Sport | 250 | +1 HP | 15 | 5 min | -15 HP | END 8 |
| Hebdomadaire | `e_corps_en_forme` | Corps en forme | Fit Body | 1000 | +1 HP | 40 | 3j 00h + preuve | -27 HP | END 13 |
| Hebdomadaire | `e_discipline_hebdomadaire` | Discipline hebdomadaire | Weekly Discipline | 1000 | +1 WIL | 40 | 3j 00h + preuve | -27 HP | WIL 13 |

## Rang D

| Type | ID | Titre | EN | XP | Stat | END | Validation | Echec | Req. |
|---|---|---|---|---:|---|---:|---|---:|---|
| Quotidienne | `d_agilite_iii` | Agilité III | Agility III | 600 | +1 AGI | 15 | 8 min + 50 reps | -20 HP | AGI 16 |
| Quotidienne | `d_bapteme_du_froid` | Baptême du Froid | Cold Baptism | 600 | +1 WIL | 15 | 2 min | -20 HP | WIL 16 |
| Quotidienne | `d_charge_continue` | Charge continue | Continuous Load | 600 | +1 WIL | 15 | 8 min + 10000 pas | -20 HP | WIL 16 |
| Quotidienne | `d_coherence_cardiaque` | Cohérence cardiaque | Heart Coherence | 600 | +1 WIL | 15 | 8 min + 2 sessions | -20 HP | WIS 16 |
| Quotidienne | `d_deplacement_fantome` | Déplacement fantôme | Ghost Movement | 600 | +1 HP | 15 | 15 min | -20 HP | END 16 |
| Quotidienne | `d_entrainements_double` | Entraînements Double | Double Training | 600 | +1 WIL | 15 | 8 min | -20 HP | WIL 16 |
| Quotidienne | `d_force` | Force | Strength | 600 | +1 STR | 15 | 8 min | -20 HP | STR 16 |
| Quotidienne | `d_force_iii` | Force III | Strength III | 600 | +1 STR | 15 | 8 min + 50 reps | -20 HP | STR 16 |
| Quotidienne | `d_mouvement` | Mouvement | Movement | 600 | +1 HP | 15 | 8 min + 7 km | -20 HP | END 16 |
| Quotidienne | `d_pleine_conscience` | Pleine conscience | Mindfulness | 600 | +1 WIL | 15 | 20 min | -20 HP | WIS 16 |
| Quotidienne | `d_soin_de_soi` | Soin de soi | Self-Care | 600 | +1 WIL | 15 | 8 min | -20 HP | WIL 16 |
| Quotidienne | `d_volonte_aceree` | Volonté Acérée | Sharpened Will | 600 | +1 WIL | 15 | 8 min | -20 HP | WIL 16 |
| Quotidienne | `d_etudes` | Études | Studies | 600 | +1 INT | 15 | 1h00 + 20 pages | -20 HP | INT 16 |
| Hebdomadaire | `d_resistance` | Résistance | Resistance | 1800 | +1 HP | 40 | 45 min + preuve | -32 HP | END 21 |

## Rang C

| Type | ID | Titre | EN | XP | Stat | END | Validation | Echec | Req. |
|---|---|---|---|---:|---|---:|---|---:|---|
| Quotidienne | `c_activite` | Activité | Activity | 1300 | +1 HP | 15 | 12 min + 8 km | -25 HP | END 26 |
| Quotidienne | `c_agilite_iv` | Agilité IV | Agility IV | 1300 | +1 AGI | 15 | 12 min + 70 reps | -25 HP | AGI 26 |
| Quotidienne | `c_entrainement_continu` | Entraînement Continu | Continuous Training | 1300 | +1 WIL | 15 | 45 min | -25 HP | WIL 26 |
| Quotidienne | `c_force_explosive` | Force explosive | Explosive Strength | 1300 | +1 STR | 15 | 5 min | -25 HP | STR 26 |
| Quotidienne | `c_force_iv` | Force IV | Strength IV | 1300 | +1 STR | 15 | 12 min + 70 reps | -25 HP | STR 26 |
| Quotidienne | `c_immersion_glaciale` | Immersion glaciale | Ice Immersion | 1300 | +1 WIL | 15 | 5 min | -25 HP | WIL 26 |
| Quotidienne | `c_mental_renforce` | Mental Renforcé | Reinforced Mind | 1300 | +1 WIL | 15 | 1j 00h | -25 HP | WIL 26 |
| Quotidienne | `c_respiration_du_predateur` | Respiration du prédateur | Predator's Breath | 1300 | +1 HP | 15 | 12 min + 5 km | -25 HP | END 26 |

## Rang B

| Type | ID | Titre | EN | XP | Stat | END | Validation | Echec | Req. |
|---|---|---|---|---:|---|---:|---|---:|---|
| Quotidienne | `b_agilite` | Agilité | Agility | 2800 | +2 AGI | 15 | 18 min | -30 HP | AGI 36 |
| Quotidienne | `b_agilite_v` | Agilité V | Agility V | 2800 | +2 AGI | 15 | 18 min + 100 reps | -30 HP | AGI 36 |
| Quotidienne | `b_endurance_delite` | Endurance d’élite | Elite Endurance | 2800 | +2 HP | 15 | 18 min + 8 km | -30 HP | END 36 |
| Quotidienne | `b_esprit_du_stratege` | Esprit du stratège | Strategist's Mind | 2800 | +2 INT | 15 | 18 min | -30 HP | INT 36 |
| Quotidienne | `b_force_v` | Force V | Strength V | 2800 | +2 STR | 15 | 18 min + 100 reps | -30 HP | STR 36 |
| Quotidienne | `b_instinct_de_combat` | Instinct de combat | Combat Instinct | 2800 | +2 AGI | 15 | 30 min | -30 HP | AGI 36 |
| Quotidienne | `b_lecture` | Lecture | Reading | 2800 | +2 INT | 15 | 45 min + 30 pages | -30 HP | INT 36 |
| Quotidienne | `b_marathon_mental` | Marathon Mental | Mental Marathon | 3000 | +2 INT | 15 | 3h00 | -30 HP | INT 44 |
| Quotidienne | `b_mental` | Mental | Mental | 2800 | +2 WIL | 15 | 18 min | -30 HP | WIL 36 |
| Quotidienne | `b_protocole_respiratoire` | Protocole respiratoire | Breathing Protocol | 2800 | +2 WIL | 15 | 5 min + 3 sessions | -30 HP | WIS 36 |
| Quotidienne | `b_souplesse` | Souplesse | Flexibility | 2800 | +2 AGI | 15 | 18 min | -30 HP | AGI 36 |
| Quotidienne | `b_volonte_inflexible` | Volonté inflexible | Unbending Will | 2800 | +2 WIL | 15 | 18 min + 5 days | -30 HP | WIL 36 |
| Hebdomadaire | `b_chemin_de_la_sagesse` | Chemin de la sagesse | Path of Wisdom | 7000 | +2 WIL | 40 | 3j 00h + preuve | -42 HP | WIL 41 |

## Rang A

| Type | ID | Titre | EN | XP | Stat | END | Validation | Echec | Req. |
|---|---|---|---|---:|---|---:|---|---:|---|
| Quotidienne | `a_agilite_vi` | Agilité VI | Agility VI | 6400 | +2 AGI | 15 | 25 min + 200 reps | -35 HP | AGI 55 |
| Quotidienne | `a_calcul_de_bataille` | Calcul de Bataille | Battle Calculation | 6000 | +2 INT | 15 | 25 min | -35 HP | INT 48 |
| Quotidienne | `a_cardio` | Cardio | Cardio | 6500 | +2 HP | 15 | 3h00 | -35 HP | END 56 |
| Quotidienne | `a_controle` | Contrôle | Control | 6000 | +2 AGI | 15 | 25 min | -35 HP | AGI 48 |
| Quotidienne | `a_corps_en_surcharge` | Corps en surcharge | Overloaded Body | 6500 | +2 HP | 15 | 1h30 | -35 HP | END 56 |
| Quotidienne | `a_force_vi` | Force VI | Strength VI | 6400 | +2 STR | 15 | 25 min + 200 reps | -35 HP | STR 55 |
| Quotidienne | `a_limiteur_brise` | Limiteur Brisé | Broken Limiter | 6000 | +2 WIL | 15 | 45 min | -35 HP | WIL 48 |
| Quotidienne | `a_maitrise_corporelle` | Maîtrise Corporelle | Body Mastery | 6000 | +2 AGI | 15 | 25 min | -35 HP | AGI 48 |
| Quotidienne | `a_puissance` | Puissance | Power | 6000 | +2 HP | 15 | 20 min | -35 HP | END 48 |
| Quotidienne | `a_rigueur` | Rigueur | Rigor | 6000 | +2 WIL | 15 | 25 min | -35 HP | WIL 48 |
| Quotidienne | `a_sixieme_sens` | Sixième Sens | Sixth Sense | 6000 | +2 STR | 15 | 25 min | -35 HP | STR 48 |
| Quotidienne | `a_souffle` | Souffle | Breath | 6000 | +2 WIL | 15 | 5 min + 3 sessions | -35 HP | WIS 48 |
| Quotidienne | `a_souffle_inepuisable` | Souffle Inépuisable | Unending Breath | 6500 | +2 HP | 15 | 25 min + 12 km | -35 HP | END 56 |
| Quotidienne | `a_volonte_du_predateur` | Volonté du Prédateur | Predator's Will | 6000 | +2 WIL | 15 | 25 min | -35 HP | WIL 48 |
| Hebdomadaire | `a_corps_delite` | Corps d’Elite | Elite Body | 16500 | +3 HP | 40 | 2h00 + preuve | -47 HP | END 63 |

## Rang S

| Type | ID | Titre | EN | XP | Stat | END | Validation | Echec | Req. |
|---|---|---|---|---:|---|---:|---|---:|---|
| Quotidienne | `s_agilite_vii` | Agilité VII | Agility VII | 12000 | +3 AGI | 15 | 35 min + 300 reps + preuve | -40 HP | AGI 71 |
| Quotidienne | `s_calme_max` | Calme MAX | Calm MAX | 13000 | +3 WIL | 15 | 3h00 + preuve | -40 HP | WIL 82 |
| Quotidienne | `s_focus_max` | Focus MAX | Focus MAX | 12000 | +3 WIL | 15 | 30 min + 3 sessions + preuve | -40 HP | WIS 74 |
| Quotidienne | `s_force_vii` | Force VII | Strength VII | 12000 | +3 STR | 15 | 35 min + 300 reps + preuve | -40 HP | STR 71 |
| Quotidienne | `s_performance_max` | Performance MAX | Performance MAX | 13000 | +3 HP | 15 | 3h00 + preuve | -40 HP | END 82 |
| Quotidienne | `s_symbiose_max` | Symbiose MAX | Symbiosis MAX | 12000 | +3 AGI | 15 | 35 min + preuve | -40 HP | AGI 74 |
| Hebdomadaire | `s_discipline_max` | Discipline MAX | Discipline MAX | 24000 | +4 WIL | 40 | 3j 00h + 60 days + preuve | -52 HP | WIL 79 |
| Hebdomadaire | `s_endurance_max` | Endurance MAX | Endurance MAX | 26000 | +4 HP | 40 | 3h00 + 20 km + preuve | -52 HP | END 87 |
| Hebdomadaire | `s_routine_max` | Routine MAX | Routine MAX | 24000 | +4 WIL | 40 | 3j 00h + 6 days + preuve | -52 HP | WIL 79 |

