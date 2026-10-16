# Document de design - Events du donjon

Ce document resume les events actuellement presents dans le donjon.

Source actuelle: `Scripts/Core/DungeonSystem.gd`

## Fonctionnement global

- Un event peut apparaitre apres avoir nettoye un etage.
- Chance actuelle d'apparition: 28%.
- Si un event apparait, il est choisi au hasard parmi les 4 events disponibles.
- Apres resolution de l'event, le joueur revient en phase "etage nettoye".
- Si l'event tue le joueur, le run echoue et le joueur retourne au checkpoint.

## Liste des events actuels

### 1. Autel fissure

Texte:
"Une pierre froide reclame un prix avant le prochain etage."

Choix disponibles:
- Sacrifier HP pour ATK
- Sacrifier END pour DEF
- Ignorer

Effets:
- Choix HP:
  - Le joueur perd des HP.
  - Perte: maximum entre 5 et 12% des HP max.
  - Le joueur gagne un bonus temporaire d'ATK.
  - Bonus: `3 + rang du donjon`.
- Choix END:
  - Le joueur perd de l'endurance.
  - Cout: `8 + rang du donjon * 2`, limite par l'endurance restante.
  - Le joueur gagne un bonus temporaire de DEF.
  - Bonus: `3 + rang du donjon`.
- Ignorer:
  - Aucun effet.

Role gameplay:
- Event de prise de risque.
- Permet de convertir une ressource de survie en puissance temporaire.
- Utile avant des etages difficiles.

## 2. Marchand cache

Texte:
"Une silhouette propose une potion contre 8 END."

Choix disponibles:
- Acheter la potion
- Passer

Effets:
- Acheter:
  - Possible seulement si le joueur a au moins 8 END.
  - Cout: 8 END.
  - Soin: maximum entre 10 HP et 22% des HP max.
- Passer:
  - Aucun effet.

Role gameplay:
- Event de securite.
- Permet de recuperer des HP contre de l'endurance.
- Utile quand le run devient dangereux.

## 3. Couloir piege

Texte:
"Le sol craque. Il faut agir vite ou lire le mecanisme."

Choix disponibles:
- Esquiver avec AGI
- Analyser avec INT

Effets:
- Le joueur choisit une stat de test:
  - Choix AGI: test base sur AGI.
  - Choix INT: test base sur INT.
- Score:
  - `stat finale + jet aleatoire de 1 a 20`.
- Difficulte:
  - Rang F: `8 + courbe d'etage * 7`.
  - Autres rangs: `10 + rang * 4 + etage * 0.18`.
- Succes:
  - Le joueur gagne 25 energie de combat.
- Echec:
  - Le joueur perd des HP.
  - Degats rang F: `5 + courbe d'etage * 12`, arrondi.
  - Degats autres rangs: `6 + rang * 5 + etage * 0.45`, arrondi.

Role gameplay:
- Event de test de build.
- Valorise AGI et INT.
- Peut accelerer le prochain combat via l'energie.

## 4. Deux chemins

Texte:
"Un raccourci dangereux descend dans la roche. L'autre contourne lentement."

Choix disponibles:
- Chemin court
- Chemin long

Effets:
- Chemin court:
  - Le joueur perd des HP.
  - Le joueur gagne un etage immediatement.
  - Degats rang F: `3 + courbe d'etage * 10`, arrondi.
  - Degats autres rangs: `4 + rang * 4 + etage * 0.35`, arrondi.
- Chemin long:
  - Le joueur gagne un bonus temporaire de DEF.
  - Bonus: +2 DEF temporaire.

Role gameplay:
- Event de tempo.
- Le chemin court accelere le run mais coute des HP.
- Le chemin long est plus prudent et renforce la defense.

## Notes d'equilibrage

- Les events actuels donnent surtout des effets temporaires ou de la survie.
- Aucun event ne donne directement du loot.
- Aucun event ne donne directement de l'or ou de l'XP.
- Les events sont simples et lisibles, ce qui est bon pour le mobile.
- Le prochain ajout naturel serait un event "coffre" ou "salle scellee" pour varier les recompenses.

## Idees d'events futurs

### Coffre verrouille

Choix possibles:
- Forcer avec STR
- Crocheter avec AGI
- Ignorer

Recompense possible:
- Or
- Loot commun frequent
- Petite chance de rare

### Fontaine trouble

Choix possibles:
- Boire
- Purifier avec INT
- Ignorer

Effets possibles:
- Soin
- Poison
- Bonus temporaire

### Statue ancienne

Choix possibles:
- Prier
- Briser
- Ignorer

Effets possibles:
- Bonus WIL temporaire
- Malediction
- Gain d'energie

### Salle maudite

Choix possibles:
- Traverser
- Chercher un passage
- Reculer

Effets possibles:
- Combat plus difficile
- Meilleur taux de loot au prochain ennemi
- Perte de HP ou END
