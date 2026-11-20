# Préparer, vérifier et enrichir depuis un dossier applicatif

Dans `/x4b/recovery?app=UUID&tab=prepare`, le dossier conserve l’application
et le site choisis. L’onglet **Préparer** relie les skills Markdown validées,
les sources Knowledge sélectionnées, l’architecture actuelle et trois parcours.
Les documents et propositions générés restent des brouillons à relire.

## Procédure ou documentation

Sélectionner une ou plusieurs skills, leurs versions et les sources utiles,
nommer le document et décrire le résultat attendu. Le connecteur IA déjà configuré
pour l’organisation reçoit ces seuls contenus sélectionnés et le contexte
applicatif. Les commandes et paramètres natifs de l’architecture sont masqués.
Le serveur contrôle la réponse, puis enregistre une nouvelle procédure brouillon
avec ses étapes, son site, son instantané et les références exactes des skills.
Une erreur IA ou un contexte périmé conserve les procédures précédentes.

Le document suit la revue indépendante existante. Une révision approuvée peut
être ajoutée explicitement à la Knowledge. Son origine `generated`, son caractère
`inferred`, sa révision, ses sources et son approbation restent visibles. Cette
documentation ne crée aucun fait observé, aucune commande de map ni preuve
d’exécution. Une vérification réelle utilise le parcours des preuves séparément.

## Commandes manquantes d’une map

Choisir la génération IA à partir des skills et sources sélectionnées ou les
valeurs par défaut d’un type exact du catalogue. La proposition conserve un diff
lisible pour chaque `check_cmd`, `start_cmd` ou `stop_cmd` manquant, sa justification,
ses hypothèses et sa provenance. Les valeurs déjà renseignées et les opérations
natives sont conservées ; les composants agrégés et les clusters ne sont pas
convertis en commandes shell individuelles.

Une autre personne habilitée approuve la proposition exacte. Son application
demande une confirmation distincte et l’acceptation explicite des contrôles
périodiques : publier une commande `check` peut la faire exécuter par les agents
affectés. Le serveur vérifie de nouveau le contexte, les sources, les droits et
le verrou applicatif. Il applique tout ou rien, uniquement aux champs encore
vides, sur le site choisi. Une proposition périmée reste consultable.

L’empreinte lie la proposition aux éléments utilisés. Modifier une skill ou une
brique sans rapport n’invalide pas cette proposition. Un changement d’une commande,
de l’affectation effective ou d’une source sélectionnée impose une nouvelle revue.
Les commandes IA restent des inférences, même après approbation : la validation
de leur forme ne garantit pas leur innocuité ni leur résultat.

## Collecte et retour de connaissance

Le dossier réutilise le moteur Discovery et ses missions, sans second exécutant.
Un administrateur peut préparer une mission depuis les skills choisies ou ouvrir
une mission existante. Le même panneau affiche le plan exact, son approbation,
le lancement manuel ou natif, l’import et la consolidation après revue.
Créer une mission ne lance rien. Les limites Linux et les collecteurs existants
restent applicables ; le Markdown n’ajoute pas de shell libre.

Après consolidation, actualiser le contexte permet de sélectionner les nouvelles
observations pour préparer ou affiner un document ou des commandes. Les documents
Markdown approuvés et versés dans Knowledge sont aussi proposés parmi les sources
d’affinage de l’Atelier de cartographie. Une nouvelle proposition conserve la
version validée précédente.

## API et droits

Routes relatives à `/api/v1` :

| Action | Route |
| --- | --- |
| Skills validées pertinentes et missions autorisées | `GET /apps/{app}/procedure-skills` |
| Générer un document brouillon | `POST /apps/{app}/procedures/generate` |
| Ajouter une révision documentaire approuvée à la Knowledge | `POST /apps/{app}/procedures/{p}/revisions/{r}/knowledge` |
| Relire les propositions de commandes | `GET /apps/{app}/command-suggestions?site_id={site}` |
| Préparer une proposition | `POST /apps/{app}/command-suggestions/prepare` |
| Approuver puis appliquer séparément | `POST /apps/{app}/command-suggestions/{id}/approve`, puis `/apply` |

`Edit` autorise la sélection et la rédaction documentaire. `Manage` est requis
pour préparer, approuver et appliquer les propositions de commandes. Une session
humaine est requise pour leur revue et leur application ainsi que la consolidation.
Une clé API avec capacité `design` peut préparer un document dans son périmètre,
sans approuver ni déclencher son exécution. Les missions Discovery restent réservées
aux administrateurs dans cette version.

Pour une procédure ou une proposition ciblée, choisir les sources de reprise et
les documents dérivés du site courant. Discovery conserve le site du lancement
natif ou celui de la cible déclarée à la préparation de la collecte manuelle.
Les observations historiques sans site établi restent consultables dans Knowledge.
Une révision ciblée exige des observations dont le site est connu et correspond
au périmètre choisi. L’identité d’une machine issue d’un import manuel reste
déclarative.

## Mise à jour et limites

La migration V086 ajoute les propositions de commandes et leurs reçus. Les
réglages du connecteur, les agents, les gateways et les maps existantes sont
conservés. Aucun nouveau fournisseur IA ou secret n’est requis.

Avant de revenir à un ancien backend après avoir créé des sources de procédure
ou des observations Discovery avec une provenance de site, restaurer la
sauvegarde antérieure à la mise à jour. Les anciens lecteurs peuvent refuser
les nouvelles données de provenance.

Le parcours réutilise le modèle de procédure pour la documentation Markdown ;
il ne constitue pas un générateur de documents bureautiques général. Le
préremplissage enrichit les commandes des composants existants : il ne génère
pas à lui seul une nouvelle topologie. La création/importation de maps complète
continue d’utiliser l’Atelier et son contrat existants.
