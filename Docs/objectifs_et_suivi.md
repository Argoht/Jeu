# Objectifs et suivi - IRL Leveling

## Source et portee

Objectif utilisateur du 14 octobre 2026 : un jeu mobile engageant, une forte retention
quotidienne avec plusieurs retours par jour, une interface ergonomique et intuitive,
et un travail autonome quotidien pour avancer.

Choix deja confirmes : Android / Google Play, jeu gratuit, publicites facultatives
recompensees et achats cosmetiques.

Ce document est une fiche de suivi construite a partir des demandes retrouvees.
Il ne remplace pas la fiche d'objectifs originale mentionnee par l'utilisateur, qui
se trouverait dans un ancien message. Les discussions Codex archivees relatives aux
avatars et a la documentation du projet ont ete consultees sans la retrouver.
Quand elle sera identifiee, y rattacher ses exigences explicites et corriger les priorites.
La discussion "Jeux similaires recommandes" a aussi ete consultee : elle ne concerne
pas la conception de ce projet et ne contient pas la fiche recherchee.

## Resultat attendu et preuves

| Exigence | Preuve necessaire | Etat |
| --- | --- | --- |
| Plusieurs retours volontaires par jour | Sessions distinctes observees sur plusieurs jours et retours de joueurs | A mesurer |
| Retention quotidienne forte | Cohortes D1 et D7, echantillon et definition documentes | A mesurer, aucun chiffre affirme |
| Interface intuitive | Premiere mission et premier equipement accomplis sans assistance | A tester avec des joueurs |
| Ergonomie mobile | Captures, controles tactiles et essais sur plusieurs telephones | Verification desktop partielle |
| Boucle IRL / donjon / cosmetiques | Parcours complet et sauvegarde verifies | Premier parcours quotidien implemente |
| Pubs et achats reels | Tests AdMob et Google Play, verification serveur, restauration | Connexions non configurees |
| Travail quotidien autonome | Automatisation active, execution et progres enregistrables | Active a 9 h Europe/Paris ; premieres executions a observer |
| Respect de la fiche originale | Message source retrouve et exigences reliees aux preuves | Recherche encore ouverte |

La retention est un resultat mesure, pas une propriete prouvee par l'ajout d'un timer.
Ne pas declarer l'objectif termine sur la seule base de tests de code.

## Iteration du 14 octobre 2026

- Ajout d'un parcours quotidien de trois etapes. Une mission recompensee ou la victoire
  sur un nouvel etage peut faire progresser le parcours.
- Deux heures entre les etapes, avec au maximum trois etapes par jour UTC.
- Recompenses de 2, 3 et 5 jetons cosmetiques. Les missions et les donjons restent
  jouables pendant l'attente ; seul le bonus du parcours attend la prochaine etape.
- Les recompenses gagnees restent recuperables apres le changement de jour.
- Un callback de victoire repete ne transforme pas un ancien etage en nouvelle activite.
- Progression et recompenses sauvegardees, avec migration compatible des saves v6.
- Le jeu s'ouvre sur les missions. Etat du parcours et recuperation sont visibles en haut.
- L'onglet actif est indique par sa bordure et son texte, avec une selection exclusive.
- Tests automatises du delai, des plafonds, du rechargement, de minuit, des callbacks
  doubles et du credit du portefeuille ; controle du rendu de la boutique et du parcours.

Reprise quotidienne configuree a 9 h, heure Europe/Paris, dans ce chat.
Automatisation active : `avancer-irl-leveling-chaque-jour`. Le poste doit rester allume
et l'application ouverte pour travailler sur les fichiers locaux.

Les horaires de jeu sont des hypotheses de conception. La journee de progression
reste UTC, comme les quotas precedents ; l'horaire de l'automatisation est Europe/Paris.
La progression par etages compte une victoire sur un etage distinct, pas une entree
dans le donjon. Les achats et les publicites n'avancent pas ce parcours.

## Prochaines priorites

### Ergonomie : deuxieme iteration du 14 octobre 2026

- Agrandissement des boutons de navigation, de mission, du parcours et de la boutique.
  Les tests verifient au moins 44 pixels rendus pour la navigation et le bouton rewarded
  dans la simulation desktop 360 x 800. Cela ne remplace pas une mesure sur telephone.
- Augmentation des tailles fixes de texte dans les missions et la boutique, et suppression
  de la troncature du resume de progression. Les textes longs peuvent passer a la ligne.
- Une seule liste defilante pour les quotidiennes, l'hebdomadaire et le journal ouvert.
  Le parcours et le resume restent visibles en haut. Le bouton de l'hebdomadaire est
  entierement accessible en bas de la liste, controle par geometrie et capture.
- Correction de la detection des fenetres : le calque d'effets ne bloque plus les gestes.
  Un seul routeur gere les gestes des missions integrees a l'ecran principal.
- Retour : fermeture de la fenetre ouverte, puis retour aux missions depuis un autre
  onglet. Sur Android, le retour depuis les missions sauvegarde et quitte l'application.
  Le fonctionnement du bouton physique reste a valider sur appareil reel.
- Les missions masquees attendent leur reaffichage pour etre reconstruites. Cela corrige
  une disposition qui pouvait deplacer le contenu devant la navigation lors d'un retour.
- Tests supplementaires : changement de langue et de missions pendant que l'onglet est
  masque, retour, gestes derriere une fenetre, tailles rendues et acces a l'hebdomadaire.

Ces corrections ameliorent les parcours existants ; elles ne prouvent pas un taux de
retention. La mesure des sessions et les essais joueurs restent les prochaines preuves
a reunir. Les controles des autres ecrans et les popups doivent encore etre examines.

1. Retrouver la fiche originale, puis relier chaque exigence a une implementation et un test.
2. Verifier l'ensemble de l'interface sur telephone : tailles physiques des controles,
   lisibilite, premiers ecrans, defilement, bouton retour et gestes concurrents.
3. Poursuivre la simplification des parcours apres essais joueurs en conservant les
   huit onglets, notamment Base et Social demandes explicitement par l'utilisateur.
4. Utiliser les compteurs locaux et le protocole `Docs/playtest_metrics.md` avec de
   vrais joueurs, puis fixer des objectifs de retention justifies par ces observations.
5. Regler les incoherences du catalogue et proposer un premier parcours adapte au joueur.
6. Installer et tester l'APK Android genere sur appareils reels ; le JDK et l'export
   de debug sont maintenant fonctionnels. Verifier aussi les icones avant publication.
7. Brancher AdMob/UMP, Play Billing et la verification serveur lorsque les comptes existent.
8. Enrichir les recompenses visuelles, le campement et le contenu des donjons selon les retours.

### Navigation : troisieme iteration du 14 octobre 2026

- Premiere ligne : Missions, Personnage, Donjon. Deuxieme : Grimoire, Boutique, Options.
- Campement et Social avaient ete masques dans cette iteration ; decision annulee
  a la demande de l'utilisateur dans l'iteration de restauration ci-dessous.
- Controle visuel de la navigation en 360 x 800 : six libelles lisibles, selection
  active visible et boutons conservant leur hauteur tactile precedente.
- Suite existante executee : 107 assertions reussies. Cette verification ne mesure
  ni la comprehension d'un nouveau joueur ni la retention ; les essais restent ouverts.

### Missions : quatrieme iteration du 14 octobre 2026

- Abandonner demande maintenant confirmation dans la carte, avec la penalite exacte
  en PV avant validation. Continuer conserve la mission et la sante.
- Textes francais et anglais. Capture 360 x 800 inspectee : avertissement et deux
  actions lisibles dans la carte, sans recouvrement.
- Tests du premier appui sans effet, annulation et confirmation effective ; 111
  assertions reussies. Capture : `tmp/journey_abandon_360.png`.

## Regles de travail quotidien

### Notes : cinquieme iteration du 14 octobre 2026

- La saisie passe par le gestionnaire de missions, avec verification de l'identite
  et de l'etat de la mission ; l'interface ne modifie plus directement la note.
- Validation actualisee a chaque saisie. Sauvegarde apres 0,6 seconde sans frappe,
  sans attendre de quitter le champ. Soumission, perte de focus et suspension
  conservent la sauvegarde immediate existante.
- Tests de normalisation, rejet d'une copie detachee, sauvegarde du brouillon sans
  perte de focus et arret du delai apres ecriture : suite de 116 assertions reussies.

### Retours hors ligne : sixieme iteration du 14 octobre 2026

- Calcul commun des compteurs de missions en jeu, au chargement et au retour de
  suspension. Une absence ne repousse plus artificiellement la prochaine echeance.
- Les renouvellements simultanes donnent une seule mise a jour ; une absence de
  plusieurs semaines ne rejoue pas tous les renouvellements intermediaires.
- Missions actives conservees avec leur identite, debut, progression et note.
- Tests des limites exactes, longues absences et durees invalides : 123 assertions
  reussies. Le test visuel attend la fin de l'effet d'echec avant sa fermeture ;
  le dernier passage ne signale plus de ressources restantes a la sortie.

### Reprise des missions : septieme iteration du 14 octobre 2026

- Les missions en cours apparaissent avant les disponibles, puis les terminees ou
  abandonnees. L'ordre initial reste stable au sein de chaque groupe.
- Ce classement est uniquement visuel : les dictionnaires actifs et leur ordre
  sauvegarde restent intacts, afin de conserver les controles d'identite des actions.
- Suite visuelle executee avec 125 assertions reussies, dont l'ordre et l'identite
  des missions presentees. Les essais joueurs restent necessaires.

### Preparation Android : huitieme iteration du 14 octobre 2026

- `build_android.ps1 -CheckOnly` verifie les chemins Godot, JDK, SDK Android,
  modele d'export et preset avant compilation. Le diagnostic execute signale
  java.exe, javac.exe et keytool.exe absents du chemin JDK configure.
- Export vers un APK temporaire, avec attente du processus et controle du journal
  avant remplacement de l'ancien APK. Le chemin de succes reste a tester avec un JDK.
- Tentative d'acces a l'API Adoptium echouee sur verification du certificat, y compris
  hors bac a sable. Aucun JDK installe et aucun nouvel APK genere.
- Godot recommande OpenJDK 17 :
  https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

### Recompenses : neuvieme iteration du 14 octobre 2026

- Les cartes quotidiennes disponibles et en cours n'annoncent plus XP et statistiques
  lorsque le plafond autorise uniquement une entree au journal.
- Les missions terminees respectent leur etat de recompense sauvegarde ; un echec
  affiche aucune recompense. Le plafond quotidien ne change pas les hebdomadaires.
- Texte recalcule pendant l'affichage, notamment au changement de jour ; retour a la
  ligne pour les avertissements. Suite visuelle : 130 assertions reussies.

### Restauration des onglets : dixieme iteration du 14 octobre 2026

- Demande explicite de l'utilisateur : conserver Base et Social. Les deux onglets
  sont retablis et leurs ecrans accessibles ; ne pas les masquer pour simplifier l'UI.
- Huit onglets sur deux lignes, Missions toujours selectionne au lancement.
- Capture 360 x 800 inspectee sans chevauchement. Suite : 133 assertions reussies,
  incluant visibilite et ouverture des deux destinations restaurees.
- Cette restauration de navigation ne complete pas les fonctions Base et Social :
  leur contenu restait a developper. La Base est raccordee dans l'iteration suivante.

### Base jouable : onzieme iteration du 14 octobre 2026

- Activation du BaseManager existant et raccordement de BasePanel a l'onglet Base.
  Les missions recompensees donnent les materiaux prevus par le systeme existant.
- Feu de camp et forge selectionnables sur la scene illustree ; ameliorations avec
  couts, rang requis, bonus passifs et sauvegarde. Aucun achat de materiaux ajoute.
- Textes et boutons de fiche agrandis ; correction du conteneur qui etirait la fiche
  sur toute la scene. Retour ferme la fiche avant de revenir aux missions.
- Tests des materiaux insuffisants, gains, amelioration via le bouton, cout exact,
  sauvegarde et bonus du feu de camp. 140 assertions reussies.
- Captures inspectees : `tmp/journey_base_360.png` et
  `tmp/journey_base_scene_360.png`. Essais tactiles sur telephone encore necessaires.
- Le gestionnaire contient cinq batiments mais seuls les deux disposant de visuels
  sont presentes ici. Les autres constructions et le contenu Social restent a traiter.

### Chargement des bonus : douzieme iteration du 14 octobre 2026

- Conservation des PV et de l'endurance sauvegardes jusqu'au calcul des maxima avec
  equipement et batiments, avant regeneration hors ligne. Cela evite qu'une jauge
  partielle superieure au maximum de base soit consideree pleine au rechargement.
- Restauration unique, avec limitation aux maxima actuels si des bonus ont disparu.
- Tests de jauges partielles, restauration unique et retrait de bonus : 143 assertions
  reussies avec la suite visuelle. Aucun changement des vitesses de regeneration.

### Observations locales : treizieme iteration du 14 octobre 2026

- Sauvegarde v8 : compteurs locaux de sessions (absence >= 30 minutes), jours UTC
  observes et cinq premiers jalons. Aucun reseau ni contenu des notes IRL enregistre.
- Fenetre de 90 jours observes ; delais des jalons calendaires, pas temps de jeu actif.
  Une application laissee ouverte ne prouve pas que la personne joue effectivement.
- Script de rapport `Tools/read_playtest_metrics.ps1`, verifie sur la sauvegarde de
  validation. Protocole de test joueur et limites dans `Docs/playtest_metrics.md`.
- Tests de retours courts/longs, double notification, rechargement, minuit, recul
  d'horloge, liste de jalons autorises, limite de stockage et sauvegarde : 152 assertions.
- Aucun resultat de retention revendique : les donnees generees automatiquement
  servent seulement a valider le fonctionnement des compteurs.

### Materiaux visibles : quatorzieme iteration du 14 octobre 2026

- Stock affiche en permanence en haut de la Base. Les missions disponibles et en
  cours montrent les materiaux prevus, sauf lorsque leur recompense est plafonnee.
- Apercu et attribution partagent un calcul unique ; consulter une carte ne credite
  aucun materiau. Le rang utilise est le rang actuel, comme lors de l'attribution.
- Les missions deja terminees n'affichent pas de gain materiel reconstitue a posteriori.
- Capture mission et Base 360 x 800 inspectees. Tests du calcul, de son absence
  d'effet de bord et des montants attribues : 156 assertions reussies.
- Historique de la fixture visuelle remis a zero pour eviter que les echecs generes
  par les tests masquent les apercus lors des passages suivants.

### Premier contenu Social : quinzieme iteration du 14 octobre 2026

- Remplacement de l'ecran d'attente Social par un bilan local : pseudo, niveau, rang,
  total de missions accomplies et meilleure serie. Textes en francais et anglais.
- Bouton de copie du bilan dans le presse-papiers, uniquement sur action du joueur.
  Aucun envoi automatique. La note de mission ne fait pas partie du texte partage.
- Amis et classements restent explicitement non connectes ; cette fonction ne
  remplace pas le futur service social en ligne.
- Capture 360 x 800 inspectee, contenu et cible tactile verifies : 160 assertions.
  Le presse-papiers Android reste a essayer sur telephone ; les tests n'ecrivent pas
  dans le presse-papiers du poste pour verifier la composition du bilan.

### Activite des ecrans masques : seizieme iteration du 14 octobre 2026

- Les trois boucles decoratives de la Base sont desactivees lorsque l'onglet est
  masque, puis reactivees a son affichage. Les changements de stats ne reconstruisent
  plus ses vues masquees ; le retour dans l'onglet actualise toujours les donnees.
- Tests sur plusieurs frames de suspension et reprise des animations : 163 assertions
  reussies. Aucun gain chiffre de batterie ou de FPS revendique sans profilage mobile.
- Les systemes de progression, missions et regeneration continuent leur fonctionnement.

### Fenetres mobiles : iteration du 15 octobre 2026

- Boutons des popups portes a 96 unites logiques et police 28. Fenetre commune
  elargie a 640 unites pour conserver les libelles lisibles ; champ et titre de
  renommage agrandis egalement.
- Premier rendu trop etroit detecte par capture puis corrige. Capture finale
  `tmp/journey_rename_360.png` inspectee : commandes lisibles et contenues a l'ecran.
- 166 assertions reussies, dont hauteur rendue, largeur du bouton et inclusion dans
  la fenetre. Le dernier passage ne signale pas de ressources restantes a la sortie.
- Les fiches d'objet longues et le clavier virtuel Android restent a verifier.
- Execution en lecture seule : modifications et tests effectues via les demandes
  d'elevation prevues par l'environnement, sans changement des permissions generales.

### Fiches d'equipement : deuxieme iteration du 15 octobre 2026

- Agrandissement du nom, type, rarete, puissance et bonus des objets. Les boutons
  conservent les cibles tactiles agrandies lors de l'iteration precedente.
- Test visuel en 360 x 640 d'un nom long, six bonus et trois actions. Titre et
  fermeture contenus dans l'ecran ; capture `tmp/journey_item_360.png` inspectee.
- 168 assertions reussies. Le test utilise un objet synthetique et ne modifie pas
  l'inventaire du joueur. Les essais tactiles Android restent ouverts.

### Export Android : troisieme iteration du 15 octobre 2026

- JDK Microsoft OpenJDK 17.0.20.1 portable installe sous
  `build/toolchains/microsoft-jdk-17/jdk-17.0.20.1+1` et configure dans Godot.
  Archive officielle verifiee par SHA-256 :
  `3d9006956fc8af5601cd24ffc4f468bef48279c7ebd8171b9bdf90d0aabfbf1f`.
- Source : https://learn.microsoft.com/en-us/java/openjdk/download-major-urls
  Adoptium reste inaccessible a cause du certificat ; Microsoft fonctionne.
- Export de debug reussi : `build/android/jeu-mobile.apk`, 61979106 octets.
  Journal : `build/android/export.log`. Aucune erreur de compilation dans ce journal.
- Signature APK v2/v3 verifiee avec apksigner. aapt2 confirme le package
  `io.itch.jean1243.irlleveling`, version 0.1.0, ARM64, SDK minimum 24, cible 35.
- aapt ancien ne lit pas certains attributs Vulkan generes ; aapt2 les lit mais
  signale une reference d'icone thematique absente. A examiner avant publication.
- `adb devices -l` ne trouve aucun appareil : installation et lancement non verifies.
  Ce fichier est un APK de test, pas une livraison Google Play ; services commerciaux
  toujours non connectes. Le rendu du projet reste Mobile/Vulkan, distinct de la
  fixture desktop Compatibility : verifier ce rendu sur l'appareil cible.
- Le JDK est dans build : ne pas supprimer ce dossier sans reconfigurer son chemin.

### Verification des APK : quatrieme iteration du 15 octobre 2026

- `build_android.ps1` exige maintenant apksigner dans les Build Tools stables et
  verifie la signature du fichier provisoire avant de remplacer l'APK precedent.
  Le controle reutilise le JDK configure dans Godot et restaure ensuite JAVA_HOME.
- Controle reutilisable : `Tools/verify_android_apk.ps1` avec les parametres
  `-ApkPath`, `-JavaHome`, `-ApkSigner`.
- Export Godot 4.6.2 execute avec le nouveau controle : signatures v2/v3 valides,
  un signataire, aucune ERROR/SCRIPT ERROR dans `build/android/export.log`.
- Test negatif : copie temporaire tronquee rejetee, JAVA_HOME restaure apres
  l'echec et hash de l'APK valide inchange. Copie temporaire supprimee.
- Diagnostic d'icone confirme dans le source officiel Godot 4.6.2 : l'exporteur
  retire themed_icon.xml du modele, meme sans icone monochrome configuree.
  Ce diagnostic n'est pas corrige ici ; pas de modification de l'APK signe.
- Guide Android actualise : il ne presente plus le JDK comme manquant. L'icone
  par defaut Godot reste a remplacer, et le lancement sur telephone reste a tester.
- Aucun changement de gameplay ou d'interface dans cette iteration ; suite de
  168 assertions non relancee. Aucun resultat nouveau de retention ou d'essai joueur.

### Reglages mobiles : iteration du 16 octobre 2026

- Options : textes agrandis, boutons et curseurs de 96 unites logiques, liste
  defilante pour maintenir les reglages accessibles sur les petits ecrans.
- La molette ne modifie plus le volume en faisant defiler les options.
- 178 assertions reussies dans la fixture Godot : selection de langue, volumes,
  valeurs affichees, sourdine, hauteur tactile et acces au dernier curseur.
- Capture `tmp/options_360.png` inspectee en 360 x 640 : aucune superposition,
  reglages lisibles, huit onglets preserves dont Base et Social.
- APK de debug reconstruit avec succes, signatures v2/v3 verifiees avant remplacement.
  Aucun essai tactile sur telephone ni nouvelle mesure de retention dans cette iteration.
- Git status reste indisponible (operation must be run in a work tree) ; aucun
  nettoyage ni reinitialisation Git tente. Modifications limitees aux options et tests.

### Retours utilisateur : inventaire, navigation et boutique (16 octobre 2026)

- Inventaire : recalcul de la grille lorsque son panneau recoit sa taille reelle.
  Suppression de la largeur minimale cumulative du contenu defilant.
- Navigation : huit boutons de largeur egale, texte de taille fixe 24 ; controle
  que les libelles francais tiennent sans troncature, notamment Personnage.
- Boutique : zone du personnage masquee hors de son onglet ; espace reserve a la
  barre verticale et separation avec le contenu. Reference API :
  https://docs.godotengine.org/en/4.6/classes/class_scrollcontainer.html
- 198 assertions reussies, dont premiere page d'inventaire avant/apres pagination,
  redimensionnement mobile, largeur des huit onglets et absence de chevauchement
  entre contenu et barre de la boutique. Captures shop_360.png et inventory_360.png
  inspectees. Essais sur telephone toujours necessaires.
- Demande de refonte complete de la base et du personnage : concepts et cinq prompts
  dans `Docs/refonte_base_et_personnage.md`. Direction conseillee : Refuge du Seuil,
  lie aux rangs et paliers du donjon. Proposition artistique, pas refonte deja livree.
  Conserver les assets et la progression existants avant choix de la direction et
  migration ; ne pas poursuivre l'embellissement du village actuel par defaut.

### Personnage et fond fournis par l'utilisateur (16 octobre 2026)

- Personnage webtoon detoure et anime integre ; foret animee fournie integree aussi.
  Details et reproduction : `Docs/personnage_anime.md`.
- Correction de la conversion initiale trop saccadee : 125 images conservees a
  25 images/s, au lieu de 32 poses. Foret a 24 images/s en video basse resolution.
- Animations en pause hors onglet, hors zone visible et en suspension application.
  Tenue/epee visuelles fixes ; equipement et statistiques de gameplay conserves.
- 214 assertions reussies en Compatibility puis Mobile/Direct3D 12. Sur ce PC :
  environ 90 rafraichissements/s, 251 changements de pose en dix secondes.
  Captures inspectees ; detourage corrige dans l'espace entre le bras et le torse.
- Performance et memoire sur telephone encore non mesurees. La refonte de la base
  reste une proposition, pas une implementation terminee.

### Nouvelle correction de fluidite : 60 images/s (16 octobre 2026)

- Retour utilisateur : les cadences sources 25/24 images/s restent trop saccadees.
  Interpolation de mouvement hors ligne vers 60 images/s pour les deux animations.
- Personnage : 300 poses, atlas compresses GPU ; foret : video 60 images/s.
  Aucune generation d'images pendant le jeu, pauses hors ecran conservees.
- 215 assertions reussies en Mobile/Direct3D 12 : 601 changements de pose/10 s,
  106 images du fond reellement differentes observees/2 s par lecture des pixels.
  Le test de pixels est distinct du benchmark pour ne pas le fausser.
- Benchmark desktop : mediane 11,108 ms, P95 11,326 ms, maximum 11,926 ms.
  Performance sur telephone non mesuree ; aucune retention prouvee par ce controle.
- Guide et commandes a jour dans `Docs/personnage_anime.md`. Le lanceur de tests
  refuse maintenant les erreurs de script detectees pendant l'import.

### Contours du bras et transitions (16 octobre 2026)

- Precisions utilisateur : petits elements blancs surtout autour du bras.
  Detourage affine pour les petits fragments enfermes dans cette zone ; chemise
  et poignets conserves. Shader de transition entre poses avec traitement des
  franges et passage entre atlas. Sources originales conservees.
- Foret interpolee hors ligne a 120 images/s, 432 x 768, boucle aller-retour.
  Le personnage garde 300 poses a 60 images/s, melangees a chaque rafraichissement.
- 217 assertions reussies en Mobile/Direct3D 12 ; captures desktop et 360 x 800
  inspectees, transition entre atlas incluse. Benchmark dix secondes : 901 frames,
  mediane 11,107 ms, P95 11,473 ms, maximum 16,319 ms, 598 changements de pose.
- Pixels du fond : 124 images differentes observees en deux secondes contre 106
  precedemment. Ce controle avec lecture GPU ne mesure pas 120 images/s presentees.
  Verification sur telephone et retours joueurs encore necessaires.
- Export Android de cette correction reussi ; signature APK verifiee (v2 et v3).
  Video controlee : duree 11,98 s, cadence nominale 120, 826 images codees pour
  1438 pas temporels (images identiques conservees par Theora).

### Correction precise apres capture : main libre (16 octobre 2026)

- La capture montre une poche blanche entre la main libre et l'echarpe, a droite
  de l'image. La correction precedente du bras oppose ne couvrait pas cette zone.
- Les composantes de fond enfermees sous la manche de ce cote sont maintenant
  retirees sur les 300 poses, sans changer les cadences ni les videos sources.
- 223 assertions reussies en Mobile/Direct3D 12 : transparence verifiee dans trois
  poses concernees, revers blanc, peau et gant preserves. Capture de la pose 75
  inspectee dans le jeu (`tmp/hunter_hand_gap.png`).
- Sur ce PC : mediane 11,106 ms, P95 11,359 ms, maximum 11,980 ms ; 599 changements
  de pose/10 s. Le controle sur telephone reste a faire.

### Integration et sauvegarde GitHub (16 octobre 2026)

- Harmonisation legere des couleurs du personnage avec la lumiere de la foret,
  attenuation de la lumiere en bas du corps et ombres de contact sous les bottes.
  Ombres alignees sur le rectangle du sprite et repositionnees au redimensionnement.
- 223 assertions reussies en Mobile/Direct3D 12 et captures 720 / 360 inspectees.
  Mediane 11,112 ms, P95 11,353 ms, maximum 12,102 ms sur ce PC.
- Demande utilisateur explicite de pousser le projet sur GitHub apres correction.
  Depot configure : Argoht/Jeu, branche existante claude/large-project-upload-tVURL.
  Exclusions completees pour tmp, caches Python, fichiers .env et cles de signature.

A chaque reprise, lire cette fiche et `Docs/mobile_market_and_release.md`, puis verifier
les fichiers actuels et les changements de l'utilisateur. Choisir une priorite qui avance
le resultat final, implementer une amelioration coherente et la verifier avant de conclure.
Actualiser ce suivi avec ce qui a reellement change, les tests, les limites et la suite.
Ne pas refaire un travail valide sans raison, ni remplacer le but par une tache plus facile.

Continuer dans ce chat avec le contexte existant. Ne pas publier, engager de depenses
ou envoyer des messages a d'autres personnes sans autorisation specifique. Garder le
modele commercial confirme et les fichiers de l'utilisateur. Signaler une avancee
substantielle, une erreur ou une information necessaire ; rester discret si rien ne change.

## Verification reproductible

```powershell
./Tools/run_mobile_checks.ps1 -Visual
```

La fixture utilise son propre repertoire utilisateur. Les captures sont dans
`tmp/shop_360.png`, `tmp/shop_720.png`, `tmp/journey_360.png` et `tmp/journey_weekly_360.png`.
Derniere verification : 223 assertions reussies dans Godot 4.6.2, avec inspection
des captures 360 x 800, gestes simules et verification de la navigation. Les avertissements
de sauvegardes corrompues/futures correspondent aux scenarios de test intentionnels.
Dernier export Android : reussi le 16 octobre 2026 ; APK de debug signe genere.
Installation sur telephone encore non verifiee, aucun appareil ADB connecte.
