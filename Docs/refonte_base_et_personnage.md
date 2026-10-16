# Direction artistique : refuge et chasseur

Proposition du 16 octobre 2026, a choisir avant remplacement des assets.
Les fonctions et sauvegardes de la base actuelle restent en place pour l'instant.

## Ce que le donjon impose deja

- Rangs F a S : Sous-bois, Caves, Cryptes, Tour, Fosse, Citadelle, Abime.
- Jusqu'a 100 etages, points de reprise tous les 10 etages.
- Entree contre endurance, combats, equipements et regeneration existants.
- Le personnage actuel est un sprite 64 x 64 avec equipements superposes.
  Un portrait webtoon ne peut pas remplacer directement cette spritesheet.

## Trois concepts de base

### 1. Le Refuge du Seuil (direction recommandee)

Une seule scene illustree, habitable, entre le monde reel et les donjons. Au debut,
un modeste atelier dans une serre abandonnee ; plus tard, un quartier general
dont les objets et les materiaux racontent les expeditions. Pas de grille de village.

Quatre points d'interaction, accessibles aussi par des commandes lisibles :
- Table d'expedition : choisir un rang, voir le dernier point de reprise et le cout
  d'endurance. Reutiliser les regles du donjon, sans nouveau cout cache.
- Vestiaire et etabli : equipement, comparaison et apparence du chasseur.
- Alcove de repos : vie/endurance et heure estimee de recuperation existante.
  Ne pas ajouter une seconde jauge, une file de soin ou un accelerateur payant.
- Mur des souvenirs : trophees de paliers et apparences de salle debloquees.
  Premiere proposition : une recompense visuelle de region au palier 10,
  puis des variantes aux jalons importants, a equilibrer apres essais.

Boucle proposee : mission IRL > progression et ressources > preparation au refuge
> expedition > trophee visible au retour. Le refuge montre ce qui a change, sans
obliger le joueur a recolter des productions toutes les heures.

Revenir doit permettre une vraie decision : changer son equipement, reprendre une
expedition apres recuperation ou decouvrir un decor gagne. Aucun bonus perdu parce
que le joueur n'est pas revenu a une heure imposee.

### 2. Le Wagon des Failles

Un train immobile entre les mondes, avec une piece par fonction et des fenetres
sur la region exploree. Tres distinctif, mais demande davantage de decors coherents
et une justification narrative nouvelle.

### 3. L'Observatoire de l'Abime

Une salle circulaire de cartographie, avec la progression des sept rangs gravee
dans une grande porte. Fort lien avec les etages ; moins chaleureux et personnel.

## Refonte du personnage

Direction : illustration 2D originale de fantasy urbaine, langage visuel de webtoon,
anatomie naturelle, lignes precises, ombres franches, matieres lisibles sur mobile.
Ne pas combiner un portrait tres detaille avec les petites pieces pixel-art actuelles.

Premiere version conseillee : personnage entier en pose trois-quarts fixe,
declinaisons de tenue completes, portrait derive du meme modele. Le gameplay
continue d'utiliser les vrais objets ; ne pas promettre qu'une image generee contient
deja toutes les combinaisons d'armures. Une version modulaire necessitera des calques
alignes, des masques d'occlusion et des retouches, ou un rig 2D dedie.

Une seule silhouette de reference approuvee avant de produire des variantes.
Garder visage, proportions, camera et pose ; modifier seulement la tenue demandee.
Le genre, la carnation et la coiffure restent personnalisables : les exemples
ci-dessous ne definissent pas un protagoniste obligatoire.

## Prompts prets a utiliser

Les prompts sont en anglais pour etre reutilisables dans differents generateurs.
Remplacer les champs entre crochets avant generation. Produire un asset par image.

### A. Personnage de reference

Original adult dungeon hunter for IRL Leveling, [gender presentation], [skin tone],
[hairstyle], approachable determined expression, full body visible from head to boots,
relaxed standing three-quarter front pose, hands separated from torso, natural adult
proportions, grounded urban fantasy clothing, charcoal utility jacket, ivory shirt,
muted teal fabric accent, worn steel details, modest beginner equipment. Premium
full-color webtoon character illustration, precise clean linework, expressive face,
controlled cel shading, readable material separation, restrained highlights, clear
silhouette at phone size. Eye-level camera, neutral lighting, centered composition,
generous empty border, transparent background, portrait 2:3. No text, no logo,
no interface, no scenery, no aura covering the body, no cropped feet, no extra limbs,
no chibi proportions, no pixel art, no photorealistic skin, no existing franchise character.

### B. Tenue de rang superieur (avec reference A)

Use the attached approved character as the identity and pose reference. Keep exactly
the same face, hair, body proportions, camera, lighting, body placement and canvas.
Change only the outfit into an original veteran crypt explorer ensemble: layered
ivory and graphite textiles, brushed silver protection, restrained garnet details,
practical boots, subtle engraved relic motifs. Strong progression in craftsmanship,
not a different person or exaggerated body. Premium clean-lined webtoon rendering,
same cel-shading treatment as reference. Full body, transparent background, no weapon
obscuring the torso, no text, no floating effects, no scenery, no crop.

### C. Portrait pour l'interface (avec reference A)

Create a square head-and-shoulders portrait of the exact attached original character.
Preserve identity, hairstyle, outfit neckline and color palette. Calm confident
expression, slight three-quarter view, clear eyes, readable at 96 pixels, clean
webtoon linework, two-level cel shadows, soft neutral fill light. Entire hair silhouette
inside frame with generous safe margins for a circular crop. Transparent background,
no frame, no text, no UI, no excessive highlights, no new accessories.

### D. Refuge du Seuil : decor principal

Portrait 9:16 environment illustration for an original urban fantasy mobile RPG,
The Threshold Refuge, a small abandoned greenhouse converted into a dungeon hunter's
home and workshop. Clear eye-level three-quarter architectural perspective, coherent
floor and human-scale furniture. Expedition table on the left, equipment workbench
on the right, resting alcove at rear left, modest trophy wall at rear right, central
floor kept open for a character. Pale stone, weathered green metal, neutral linen,
small warm lamps balanced by natural daylight, a restrained garnet map cloth.
Premium full-color webtoon background, precise linework, confident painted shadows,
inviting lived-in details, crisp readable objects. Keep essential interaction areas
within the central 70 percent; low-detail top and bottom margins for separate game UI.
No characters, no written labels, no interface, no buttons, no floating cards,
no isometric village, no purple fog, no visual clutter, no photorealism.

### E. Evolution du refuge apres les Cryptes (avec reference D)

Use the attached refuge illustration as an exact composition reference. Preserve
architecture, camera, furniture placement, lighting direction and all interaction
zones. Show earned progression through a few original crypt expedition souvenirs:
a restored carved stone fragment on the trophy wall, a silver lantern near the
expedition map, a folded garnet cloak on the equipment stand. Repair some worn
surfaces without turning the room into a palace. Same clean webtoon background style,
same palette balance, same empty central floor and UI-safe margins. No characters,
no text, no interface, no new doorways, no moved furniture, no excessive glow.

## Integration et garde-fous

- Choisir d'abord une direction et un personnage de reference, puis produire les assets.
- Exporter personnage/portrait avec vraie transparence, decor opaque ; inspecter les
  contours, mains, pieds et contrastes a la taille d'affichage, pas seulement en grand.
- Animer legerement respiration et tissus apres separation des calques, pas en deformant
  toute l'image. Prevoir reduction des animations et consommation mobile.
- Conserver progression, ressources et bonus acquis de la base : etablir une migration
  explicite vers les nouvelles stations avant de retirer les anciens batiments.
- Les variantes achetables restent visuelles ; aucun avantage de combat ni soin payant.
- Faire tester l'acces au donjon et a l'equipement sans explication. Les concepts ne
  constituent pas une preuve d'intuitivite ou de retention.
