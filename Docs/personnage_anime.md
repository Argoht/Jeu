# Personnage et foret animes

## Integration dans la foret (16 octobre 2026)

La lumiere du personnage est legerement refroidie et desaturee pour correspondre
a la foret ; le bas du corps recoit moins de lumiere ambiante. Deux ombres de
contact et une ombre diffuse relient les bottes au chemin. Le calque d'ombre est
entre la video et le personnage, sans interception des gestes, et suit le meme
rectangle que le personnage lors des changements de taille.

223 assertions reussies en Mobile/Direct3D 12, captures 720 et 360 pixels
inspectees. Benchmark desktop : mediane 11,112 ms, P95 11,353 ms, maximum
12,102 ms ; 599 changements de pose en dix secondes. Le style de dessin reste
celui de la video fournie. Validation sur telephone encore ouverte.

## Correction ciblee : main et echarpe (16 octobre 2026)

La capture utilisateur localise le blanc du cote de la main libre, a droite de
l'image. Quand elle touche l'echarpe, une poche de fond blanc devient enfermee et
echappe au detourage du fond exterieur. Le preparateur retire maintenant aussi les
composantes blanches dans cette zone, sous le revers de manche, sur les 300 poses.
Ce masque est specifique a ce clip ; pas de suppression globale du blanc.

223 assertions reussies en Mobile/Direct3D 12, dont transparence des poches dans
les poses 75, 125 et 275, et preservation du revers blanc, de la peau et du gant.
Capture de la pose 75 inspectee : `tmp/hunter_hand_gap.png`.
Benchmark desktop : mediane 11,106 ms, P95 11,359 ms, maximum 11,980 ms,
599 changements de pose sur dix secondes. Cadence des animations inchangee.

## Version actuelle : contours et transitions (16 octobre 2026)

Retour utilisateur : petits restes blancs surtout autour du bras, et fluidite encore
insuffisante. Le masque retire maintenant aussi les petites composantes blanches
enfermees dans la zone bras/torse, avec des limites pour conserver chemise et poignets.
Le shader `hunter_interpolation.gdshader` melange deux poses voisines a chaque
rafraichissement, y compris entre deux atlas ; les couleurs premultipliees evitent
un halo blanc aux contours. Les faibles franges de compression sont attenuees.
Les 300 poses a 60 images/s et leur duree restent identiques.

La foret active est `forest_animated_120.ogv` : 432 x 768, 120 images/s calculees
hors ligne, 1438 pas temporels, boucle aller-retour de 11,98 secondes, environ 7,5 Mio.
PyAV decode 826 images codees : Theora conserve les images identiques sur plusieurs
pas, notamment lorsque le faible mouvement devient identique apres quantification.
La cadence nominale de 120 images/s ne signifie donc pas 120 contenus differents/s.
Commande reproductible avec FFmpeg :

```text
ffmpeg -i SOURCE_FORET -an -filter_complex "[0:v]scale=432:768:flags=lanczos,setsar=1,tpad=stop_mode=clone:stop_duration=0.125,minterpolate=fps=120:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,trim=duration=6,split[f][r];[r]reverse,trim=start_frame=1:end_frame=719,setpts=PTS-STARTPTS[back];[f][back]concat=n=2:v=1:a=0[out]" -map "[out]" -r 120 -c:v libtheora -q:v 7 -pix_fmt yuv420p Assets/Avatar/Backgrounds/forest_animated_120.ogv
```

Validation Mobile/Direct3D 12 : 217 assertions ; 901 rafraichissements sur dix
secondes, mediane 11,107 ms, P95 11,473 ms, maximum 16,319 ms ; 598 changements
de pose, avec transitions supplementaires par shader entre ces changements.
Lecture de pixels separee : 124 images du fond differentes en deux secondes
(106 au controle precedent). Ce test ajoute un cout de lecture GPU/CPU et ne
prouve pas une presentation a 120 images/s. Captures 720 et 360 pixels inspectees,
ainsi qu'une transition entre les poses 34 et 35 sur deux atlas differents.
La performance et les contours en mouvement sur telephone restent a verifier.

## Historique : interpolation 60 images/s

La version 25/24 images/s decrite plus bas est historique. Suite au nouveau retour
utilisateur, les deux animations utilisent des images intermediaires calculees par
FFmpeg minterpolate (compensation de mouvement MCI/AOBMC), pas une acceleration
de lecture ni une simple duplication. Calcul effectue hors ligne uniquement.

- Personnage : 300 images sur 5 secondes, 60 images/s, neuf atlas 256 x 384 par pose.
  Compression GPU haute qualite BPTC/ASTC activee pour limiter le cout memoire ;
  environ 30,3 Mio pour neuf atlas BC7 sans mipmaps, contre 121 Mio RGBA bruts.
- Foret : `forest_animated_60.ogv`, 432 x 768, 60 images/s, 718 images en boucle
  aller-retour (11,97 secondes), sans audio.
- Le detourage utilise maintenant les composantes connexes OpenCV, pour eviter
  un traitement Python lent des 300 masques. Aucun OpenCV dans le jeu exporte.
- Le preparateur refuse un clip autre que 300 images a 60 images/s avant d'ecrire
  les atlas, pour ne pas desynchroniser les assets et AvatarView.

Preparation du personnage avant `prepare_hunter_animation.py` :

```text
ffmpeg -i SOURCE_PERSONNAGE -an -vf "tpad=stop_mode=clone:stop_duration=0.12,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,trim=duration=5" -c:v libx264 -crf 14 -preset fast tmp/hunter_60fps.mp4
python Tools/prepare_hunter_animation.py tmp/hunter_60fps.mp4 Assets/Avatar/Hunter --preview tmp/hunter_60_preview.png
```

Pour la foret, avant le split de la commande historique ci-dessous, ajouter
`tpad=stop_mode=clone:stop_duration=0.125,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,trim=duration=6`.
Remplacer end_frame=143 par end_frame=359, -r 24 par -r 60 et le nom de sortie par
`forest_animated_60.ogv`.

Reference du filtre : https://www.ffmpeg.org/ffmpeg-filters.html#minterpolate
Compression GPU : https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html

Controle Mobile/Direct3D 12 sur RTX 3060 : 215 assertions reussies ; sur dix
secondes, 901 rafraichissements, mediane 11,108 ms, P95 11,326 ms, maximum 11,926 ms,
601 changements de pose. Controle separe des pixels du fond : 106 images differentes
observees en deux secondes. Cette lecture GPU/CPU ajoute son propre cout ; ce resultat
n'est pas une garantie de 60 images effectivement presentees sur tout appareil.
Captures finales inspectees, y compris les contours et la transparence. L'interpolation
peut introduire des artefacts entre les poses ; validation tactile/mobile toujours ouverte.

## Historique de la premiere integration

Integration du 16 octobre 2026, a partir des deux videos fournies par l'utilisateur.

## Sources conservees

- `C:/Users/matis/Downloads/perso_base_anime` (nom reel avec accent sur le e final) :
  MP4 sans extension, 640 x 960, 125 images, 25 images/s, 5 secondes.
- `C:/Users/matis/Downloads/Foret-animee.mp4` : 1080 x 1920, 144 images,
  24 images/s, 6 secondes. Les originaux ne sont pas modifies.

## Preparation

`Tools/prepare_hunter_animation.py` utilise PyAV, numpy et Pillow uniquement pendant
la preparation. Ils ne sont pas requis par le jeu exporte. PyAV et FFmpeg ont ete
installes localement sous tmp/video_inspection pour cette session.

Le detourage preserve le blanc interieur de la chemise. Il retire le blanc relie
au bord et les poches de fond dans la region entre le bras gauche et le torse.
Cette seconde regle est specifique a cette video : ne pas reutiliser aveuglement
ces coordonnees avec un autre personnage ou une autre pose.

La premiere conversion de 32 poses a ete remplacee apres le signalement de saccades.
Les 125 images sont maintenant conservees, en 256 x 384, dans quatre atlas de
1820 x 1940 avec gouttieres transparentes. Lecture a 25 images/s, aller-retour sans
doublon aux extremites. Pas de decodage, de detourage ni de chargement par image
pendant le jeu. Les quatre atlas RGBA representent environ 54 Mio non compresses :
le budget memoire doit encore etre profile sur les appareils Android cibles.

La foret utilise `Assets/Avatar/Backgrounds/forest_animated.ogv`, Theora, 432 x 768,
24 images/s, sans audio. Elle se lit aussi en aller-retour, sur 286 images, soit
environ 11,92 secondes, pour eviter un saut de camera au raccord.

Commande FFmpeg de preparation (remplacer FFmpeg et SOURCE par leurs chemins) :

```text
FFmpeg -i SOURCE -an -filter_complex "[0:v]scale=432:768:flags=lanczos,setsar=1,split[f][r];[r]reverse,trim=start_frame=1:end_frame=143,setpts=PTS-STARTPTS[back];[f][back]concat=n=2:v=1:a=0[out]" -map "[out]" -r 24 -c:v libtheora -q:v 7 -pix_fmt yuv420p Assets/Avatar/Backgrounds/forest_animated.ogv
```

VideoStreamPlayer assure le decodage du decor, ajuste sans deformation et recadre
au panneau. Reference : https://docs.godotengine.org/en/stable/classes/class_videostreamplayer.html
Les deux animations se suspendent hors de l'onglet, lorsque le personnage sort
entierement de la zone defilante, et lors de la suspension de l'application.

## Apparence et gameplay

Le personnage entier, ses vetements et son epee forment une apparence fixe.
Les objets restent equipables et continuent de modifier les statistiques ; leurs
anciens calques pixel-art ne sont plus dessines sur cette silhouette.
Le clic de rotation de l'ancien sprite est retire : aucune vue de dos n'a ete fournie.
Les anciens assets sont conserves. Aucun inventaire ni progression joueur modifie.

## Verification

```powershell
./Tools/run_mobile_checks.ps1 -Visual
./Tools/run_mobile_checks.ps1 -Visual -MobileRenderer
```

214 assertions reussies avec les deux moteurs sur RTX 3060. Mesure de dix secondes
avec personnage et foret actifs, dans la fixture isolee :

| Rendu desktop | Images mesurees | Mediane | P95 | Maximum | Changements de pose |
| --- | ---: | ---: | ---: | ---: | ---: |
| Compatibility/OpenGL | 901 | 11,112 ms | 11,256 ms | 15,028 ms | 251 |
| Mobile/Direct3D 12 | 901 | 11,112 ms | 11,325 ms | 11,921 ms | 251 |

Cela correspond a environ 90 rafraichissements/s de l'interface, distincts des
25 poses/s du personnage et des 24 images/s du decor. Ces mesures ne prouvent
pas la fluidite sur telephone, la consommation batterie ni la vitesse de demarrage.
Captures : tmp/hunter_360.png, tmp/hunter_720.png, tmp/hunter_motion_720.png.
