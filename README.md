# IRL Leveling

Jeu Godot pour Android : missions quotidiennes, personnage anime, donjons,
base et progression RPG. Jeu gratuit, publicites recompensees facultatives
et achats cosmetiques. Les connexions AdMob / Google Play restent a configurer.

## Ouvrir le projet

Utiliser Godot 4.6.2, importer `project.godot`, laisser terminer l'import des
assets puis lancer avec F6 pour la scene ouverte ou F5 pour le jeu complet.
Les atlas du personnage et la video du decor sont inclus ; leur regeneration
n'est pas necessaire pour jouer.

## Verifications sous Windows

```powershell
./Tools/run_mobile_checks.ps1 -Godot "C:/chemin/Godot_v4.6.2-stable_win64.exe" -Visual -MobileRenderer
```

La fixture cree ses propres sauvegardes, distinctes de celles du jeu. Le mode
`-MobileRenderer` utilise Direct3D 12 sous Windows. Les captures et journaux sont
generes dans `tmp/`. Les resultats desktop ne garantissent pas les performances
sur telephone.

## Android

Configurer le SDK Android, le JDK 17 et les modeles d'export Godot 4.6.2,
puis creer localement un preset nomme `Android APK`.

```powershell
./build_android.ps1 -Godot "C:/chemin/Godot_v4.6.2-stable_win64.exe"
```

Le script genere `build/android/jeu-mobile.apk` et verifie sa signature.
Les presets locaux, cles, APK, caches et fichiers temporaires sont exclus de Git.

## Suivi

- [Objectifs et preuves](Docs/objectifs_et_suivi.md)
- [Animations et preparation des assets](Docs/personnage_anime.md)
- [Marche mobile et preparation de publication](Docs/mobile_market_and_release.md)
- [Mesures et essais joueurs](Docs/playtest_metrics.md)
