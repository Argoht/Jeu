# Mesure locale des essais

La sauvegarde v8 ajoute `metrics`, sans reseau, identifiant utilisateur, nom de
mission ni texte libre. Les anciennes sauvegardes commencent leur observation au
premier lancement de cette version : cette date n'est pas une date d'installation.

## Definitions

- Session : ouverture ou retour apres au moins 30 minutes hors application.
  Un redemarrage rapide ne cree pas une nouvelle session.
- Jour observe : jour UTC pendant lequel l'application est au premier plan.
  Minuit peut ajouter un jour sans ajouter de session. Les 90 derniers jours
  observes sont conserves ; les jours absents ne sont pas ajoutes artificiellement.
- Premiers jalons : mission commencee, mission terminee, equipement, entree dans
  un donjon et amelioration de base. Le delai est en secondes calendaires depuis
  le debut de l'observation, pas du temps de jeu actif.
- Les notes IRL et les objets equipes ne figurent pas dans ces compteurs.

Une application laissee ouverte compte comme presente au premier plan. Une horloge
modifiee ou un arret brutal entre deux sauvegardes peut fausser la mesure. Aucun
compteur local ne constitue une preuve anti-triche ou un taux de retention global.

## Lire un rapport

```powershell
./Tools/read_playtest_metrics.ps1 -SavePath "$env:APPDATA/Godot/app_userdata/Jeu/save_game.dat"
```

Le script lit sans modifier la sauvegarde et n'affiche que les compteurs autorises.
Les donnees des tests automatiques utilisent le repertoire distinct
`IRLLevelingValidation` : ne pas les melanger avec des essais joueurs.

## Protocole de test joueur

1. Utiliser une nouvelle sauvegarde avec la meme version pour chaque participant.
2. Observer sans guider : choix et lancement d'une mission, validation, equipement,
   puis comprehension des materiaux et de la Base. Noter blocages et demandes d'aide.
3. Laisser jouer librement sept jours, sans demander de revenir pour remplir un quota.
4. Avec l'accord des participants, recuperer uniquement les rapports de compteurs,
   leur version de jeu et leurs commentaires. Aucun envoi automatique n'est implemente.
5. Compter les retours J1 et J7 pour les participants dont la fenetre est ecoulee,
   avec jours UTC definis avant l'essai. Publier numerateur, denominateur et exclusions.
6. Examiner les jours a plusieurs sessions et les raisons declarees du retour.
   Comparer ensuite une modification du parcours avec la meme methode.

Il n'existe encore ni cohorte observee ni objectif chiffre valide par les donnees.
Les compteurs preparent ces observations ; ils ne prouvent pas l'objectif de retention.
