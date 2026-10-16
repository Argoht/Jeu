# IRL Leveling : diagnostic mobile et preparation commerciale

Date : 14 octobre 2026. Cible choisie : Android / Google Play.
Modele choisi : jeu gratuit, publicites facultatives recompensees, achats cosmetiques.

## Positionnement

Le projet combine des missions dans la vie reelle, un avatar equipe, des rangs F a S,
un journal de progression et des donjons. Sa proposition distinctive est de transformer
des actions quotidiennes en progression RPG visible. Il faut tester cette proposition
avec des joueurs avant de multiplier les mecaniques commerciales.

Le rapport [Sensor Tower 2026](https://sensortower.com/blog/state-of-gaming-2026)
decrit une baisse des telechargements mobiles, accompagnee d'une hausse des revenus
et d'un besoin accru de retention. La strategie connait une forte croissance, mais cela
ne justifie pas de transformer IRL Leveling en jeu 4X : notre audience et nos moyens
sont differents. Conclusion de conception : privilegier le retour volontaire et la
progression comprise par le joueur. Ce choix est une interpretation, pas une garantie
de rentabilite.

Comparaisons utiles, sans supposer que leurs chiffres commerciaux sont accessibles :

| Reference | Observation publique | Application au projet |
| --- | --- | --- |
| [Habitica](https://habitica.com/static/plans) | Progression ludique et avantages de personnalisation dans ses offres | Donner une valeur durable a l'avatar et au journal |
| [Finch](https://finchcare.com/about-finch) | Fonctions essentielles gratuites, personnalisation supplementaire optionnelle | Garder les missions accessibles et vendre l'expression personnelle |
| RPG mobiles traditionnels | Marche bien plus large que celui des habitudes ludifiees | Les donnees generales ne mesurent pas notre niche |

Les documents publics consultes ne permettent pas de predire le revenu de ce jeu,
son cout d'acquisition ou la conversion a un prix donne.

## Diagnostic du projet

L'examen couvre l'architecture Godot, les scripts de progression, les ressources de
missions et d'objets, les ecrans principaux, l'avatar, le donjon, les sauvegardes,
la localisation, les assets et les reglages d'export Android. Il ne remplace pas
des sessions longues sur plusieurs telephones ni un audit complet de toutes les
combinaisons de combat.

| Surface | Constat | Action |
| --- | --- | --- |
| Sauvegarde | Ecriture directe du seul fichier, vulnerable a une interruption | Fichier temporaire valide, remplacement et copie de secours |
| Compatibilite | Risque d'ecraser un fichier illisible ou provenant d'une version future | Ecritures bloquees dans ces cas, originaux conserves |
| Missions | Acceptation repetee et echec repete possibles via l'API | Controle du statut et de l'identite de la mission |
| Regeneration | Petites sessions hors ligne perdaient leurs fractions | Accumulateurs partages et sauvegardes |
| Cycle Android | Retour apres suspension non pris en compte explicitement | Sauvegarde a la suspension et rattrapage au retour |
| Boutique | Onglet vide | Atelier, cadres, solde, equipement et etats d'indisponibilite |
| Services commerciaux | Aucun SDK, compte ou serveur de verification configure | Frontiere de raccordement explicite, services desactives |
| Campement et social | Fonctionnalites encore annoncees a venir | A terminer apres validation de la boucle principale |
| Missions longues | Des objectifs de plusieurs jours ont encore des regles a revoir | Examiner le catalogue, conserver les objectifs actifs |
| Localisation | Certaines formulations existantes sont maladroites | Relecture editoriale complete avant publication |
| Assets | Plusieurs grandes images et un WAV musical de plus de 8 Mo | Profiler RAM, taille installee et chargement sur telephone |
| Distribution | Le script existant produit un APK de debug | Preparer ensuite un AAB release signe pour Google Play |

Le nom interne Godot reste `Jeu` afin de conserver le repertoire de sauvegarde desktop
existant. Le nom d'application Android du preset est deja `IRL Leveling`. Renommer le
nom interne necessitera une migration explicite des donnees utilisateur.

## Ce qui fonctionne maintenant

- Un cadre Azur gratuit ; Emeraude, Rose et Aurore a 20, 40 et 60 jetons.
- Le cadre choisi modifie effectivement la bordure de l'ecran du personnage.
- Une mission recompensee donne un jeton, avec un plafond de cinq par jour UTC.
- Les publicites preparees donnent cinq jetons de style, jamais des statistiques.
- Plafond de trois publicites recompensees par jour, delai de 120 secondes entre gains.
- Une fermeture sans recompense, un callback inconnu ou repete ne donne rien.
- Un cadre Perle de soutien correspond au produit non consommable
  `irlleveling.supporter_frame`. Le prix doit venir de Google Play, en devise locale.
- Le paiement en attente ne donne aucun cadre. La restauration est preparee et peut
  retirer un droit rembourse lorsque le serveur retourne un etat valide.
- Les boutons de pub et d'achat restent desactives sans fournisseur disponible.
- Les textes de la boutique sont disponibles en anglais et en francais.

Ces plafonds et couts sont des hypotheses de depart a tester. Aucun abonnement,
tirage payant ou vente de puissance n'est ajoute. Le cadre de soutien est une premiere
offre modeste ; un pack d'illustrations originales apporte probablement plus de valeur,
mais cette hypothese doit etre confrontee aux retours des joueurs.

## Connexion des services reels

Les comptes, SDK natifs, identifiants publicitaires et backend ne sont pas fournis.
`MobileCommerceProvider.gd` definit le contrat, avec des methodes inactives par defaut.
`CommerceSystem.gd` gere les regles du jeu. Aucun revenu ne peut etre genere par
la version actuelle. Aucun achat de test n'est offert dans les builds du jeu.

1. Creer l'application Play Console avec le package du preset
   `io.itch.jean1243.irlleveling`, puis configurer la signature release. Conserver ce
   package si une distribution existe deja. Creer le produit `irlleveling.supporter_frame`.
2. Creer l'application et un bloc rewarded dans AdMob. Garder les IDs publics dans une
   configuration dediee ; ne jamais embarquer de cle privee ou de compte de service.
3. Installer une version compatible Godot 4.6 du plugin officiel
   [GodotGooglePlayBilling](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html)
   et un plugin AdMob maintenu, par exemple
   [Poing Studios](https://github.com/poingstudios/godot-admob-plugin).
   Verifier leurs versions et licences au moment de l'installation.
4. Installer les templates Android, activer Gradle, les plugins et leurs dependances,
   puis les permissions reseau necessaires. Le preset actuel reste adapte a l'APK
   sans ces plugins. Exclure `Tools/*,Docs/*,tmp/*,Scripts/Tests/*` des ressources exportees.
5. Implementer un fournisseur qui herite de `MobileCommerceProvider.gd`, l'ajouter
   comme enfant du moteur, puis appeler `commerce_system.set_provider(provider)` apres
   le chargement des donnees. Le fournisseur doit resynchroniser les droits au lancement.
6. Suivre [UMP](https://developers.google.com/admob/android/privacy) : mise a jour des
   informations au lancement, formulaire si necessaire, puis demande de pub uniquement
   si `canRequestAds()` l'autorise. Relier les choix de confidentialite au vrai formulaire.
7. Relier le callback [rewarded officiel](https://developers.google.com/admob/android/rewarded)
   au `request_id` recu. Emettre `reward_earned` une seule fois et avant `reward_closed`.
   Si le SDK presente un autre ordre, adapter cet ordre avant d'emettre ces signaux.
   Emettre `reward_closed` apres un echec ou une fermeture sans gain, puis recharger une pub.
8. Interroger les produits et leurs prix localises avant de permettre l'achat.
   Utiliser [Play Billing](https://developer.android.com/google/play/billing/integrate).
   Le serveur authentifie le joueur, verifie le purchase token, le package, le produit
   et l'etat PURCHASED, enregistre le droit de facon idempotente, puis acquitte l'achat.
   Suivre la [verification Google](https://developer.android.com/google/play/billing/security).
9. Emettre `purchase_verified(product_id)` uniquement apres cette verification.
   Emettre `purchase_finished(product_id, status)` pour `pending`, `cancelled` ou une
   erreur. Un retour `success` tout seul ne debloque rien. Une verification tardive
   doit toujours pouvoir accorder le droit apres reprise ou reconnexion.
10. Pour la restauration, emettre `entitlements_restored(product_ids)` seulement apres
    une reponse serveur complete et valide. Une panne reseau ne doit jamais etre
    representee par une liste vide, car celle-ci retire les droits payants.

La sauvegarde locale des droits est un cache, pas une preuve d'achat. Avant activation,
la verification serveur et le traitement des remboursements sont indispensables.
Les quotas locaux resistent aux callbacks doubles et aux petits retours de l'horloge,
mais pas a la modification du fichier ou a une avance volontaire de l'horloge.
Si l'economie cosmétique le justifie, utiliser une heure et un portefeuille serveur.

## Validation et sortie

Commande reproductible, sans toucher a la sauvegarde du joueur :

```powershell
./Tools/run_mobile_checks.ps1
./Tools/run_mobile_checks.ps1 -Visual
```

Le lanceur utilise des jonctions vers les ressources du projet et le repertoire
utilisateur distinct `IRLLevelingValidation`. Les tests couvrent les recompenses,
quotas, callbacks doubles, consentement, paiements en attente, restauration,
sauvegardes anciennes et corrompues, identite des missions et regeneration fractionnee.
Les captures de la boutique sont placees dans `tmp/shop_720.png` et `tmp/shop_360.png`.

Verification de cette iteration : 64 assertions reussies dans Godot 4.6.2, dont
le rendu de la boutique a deux resolutions et l'absence d'effet des cadres sur les stats.
Mise a jour du 15 octobre 2026 : le chemin JDK invalide a ete remplace par Microsoft
OpenJDK 17 portable (archive officielle verifiee par SHA-256), configure dans Godot.
L'export de debug fonctionne et sa signature a ete verifiee. Le lanceur exige maintenant
apksigner et controle la signature avant de remplacer le dernier APK genere.

```powershell
./build_android.ps1 -Godot 'C:\Users\matis\OneDrive\Desktop\Godot_v4.6.2-stable_win64.exe'
```

Resultat : `build/android/jeu-mobile.apk`. Le JDK est sous `build/toolchains` : ne pas
supprimer ce repertoire sans reconfigurer Godot. Aucun telephone ADB connecte lors
du controle : installation, rendu Mobile/Vulkan et lancement restent a tester.

L'avertissement aapt2 sur `mipmap/themed_icon` correspond au traitement du modele
par l'exporteur Godot 4.6.2 : il retire `themed_icon.xml` et, si une image monochrome
est configuree, reutilise son contenu pour `icon.xml`. Changer seulement l'image
ne restaure donc pas ce fichier. Ne pas modifier l'APK signe pour masquer ce diagnostic.
Source : https://github.com/godotengine/godot/blob/4.6.2-stable/platform/android/export/export_plugin.cpp
L'icone actuelle est encore celle de Godot ; une identite propre reste a preparer.

Avant une premiere publication :

- Tester sur des appareils Android reels : pause, arret force, reprise, bouton retour,
  perte reseau, petites resolutions, notch, performance et consommation batterie.
- Verifier les licences de toutes les images, polices et musiques.
- Terminer un premier parcours simple : premiere mission, premiere recompense, donjon,
  premier cosmetique ; observer ou les joueurs bloquent.
- Installer une build interne via Google Play et tester les achats avec les comptes
  de test : annulation, attente, restauration apres reinstallation, remboursement.
- Utiliser les publicites de test AdMob pendant le developpement.
- Preparer la politique de confidentialite, les declarations Data Safety, la presence
  de publicites, la classification du contenu et les autres informations Play Console.
- Verifier les exigences SDK et Billing en vigueur au moment du depot ; exporter
  un AAB release signe. Ne pas distribuer une cle de signature dans le depot.

Suivre ensuite D1/D7, premieres missions terminees, progression du premier donjon,
premier cosmetique debloque, choix de voir une pub, taux de completion et conversion
d'achat. Ce sont des mesures a mettre en place, pas des statistiques deja collectees.
Ne pas envoyer les notes de preuve IRL du joueur dans la telemetrie commerciale.

Ordre recommande pour les prochaines iterations : boucle de debut et lisibilite mobile,
validation sur telephone, services commerciaux, contenu cosmetique plus riche,
puis campement/social et evenements. Une promesse de jeu "parfait" ne peut pas etre
verifiee sans ces retours et ces essais.
