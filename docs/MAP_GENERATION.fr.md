# Générer des maps avec l’IA du client

AppControl fournit les instructions et le format de ses maps. Votre moteur conserve les documents sources, choisit son modèle d’IA et exécute le prompt. AppControl ne reçoit aucun document source pour fournir ce contrat et n’appelle aucun modèle dans ce parcours.

Le parcours principal est celui des **applications réelles** : récupérer le contrat `standard`, appeler votre IA avec vos documents, vérifier le JSON et les commandes, résoudre les placements par composant, puis publier avec les droits des équipes. Une seule application peut fonctionner simultanément sur plusieurs sites.

La démonstration de cycle de vie peut être un **choix de prompt** : `mock-linux` ou `mock-windows` demande à votre IA de produire des commandes fondées sur des fichiers témoins. La map obtenue suit ensuite **le même import normal**, avec des agents ordinaires et des placements explicites. Ce parcours n’exige pas de registre d’agents mock ni de réglage global. Applications réelles et simulées coexistent dans la même instance ; leurs commandes déterminent leur comportement. Le [guide de simulation](SIMULATION_MAPS.fr.md) détaille ce parcours.

**AppControl Embedded est un autre périmètre de sécurité** : à partir d'une map
publiée, le serveur crée une copie avec ses propres commandes de reconstruction,
sur des agents et gateways dédiés, et délivre un jeton limité à cette simulation.
Un profil mock adressé à l'IA ne remplace pas cette isolation imposée côté serveur.
Voir [EMBEDDED.fr.md](EMBEDDED.fr.md).

**Le parcours initial de publication existe depuis AppControl 1.21.1.** Les
enrichissements décrits ici — prompt révision `7`, synchronisation du catalogue et
Embedded — nécessitent un serveur qui expose ces capacités. Vérifier la réponse
du contrat et les routes de l'instance installée ; un script ou un kit récent ne
met pas à jour les images du produit à lui seul.

Le prompt explique aussi le modèle métier, avant la syntaxe JSON :

- **Application / map** : un périmètre applicatif et les éléments nécessaires à son exploitation.
- **Composant** : une unité exploitable avec son état et ses procédures, par exemple une base, un service ou un traitement batch. Un fichier ou une bibliothèque citée dans un document ne devient pas automatiquement un composant.
- **Groupe** : une classification visuelle facultative des composants ; elle ne crée ni sous-application ni ordre d'exécution.
- **Cluster `fan_out` / membres** : un composant et ses instances explicites ; les dépendances portent sur le composant, pas sur chacun de ses membres.
- **Dépendances** : un graphe entre composants, distinct de la hiérarchie de contenance. Un composant peut avoir plusieurs prérequis.

Exemple : l'application Paiements contient une base, une API et un frontal. L'API dépend de la base ; le frontal dépend de l'API. Les groupes « Données », « Traitement » et « Accès » servent à la présentation. Si l'API compte deux instances équivalentes, elles peuvent être les membres de son composant `fan_out`.

Les composants ordinaires restent dans une liste plate : le contrat actuel ne permet pas d'imbriquer des applications. Les références entre applications relèvent d'autres API du produit et ne doivent pas être inventées dans le JSON généré. Le prompt distingue également composants, hôtes, agents et gateways.

Cette fonctionnalité nécessite une version d’AppControl qui expose les routes décrites ci-dessous. Si la récupération retourne `404`, l’instance installée doit être mise à jour ; un prompt récupéré sur une autre version ne remplace pas cette mise à jour.

**Pour essayer les appels sans écrire de client HTTP**, ouvrez **API documentation** dans AppControl, ou `/api-docs` sur la même instance. Le [parcours Swagger](SWAGGER.fr.md) détaille les clics, les identifiants à choisir et les droits nécessaires. Le schéma OpenAPI est disponible à `/api/v1/openapi.json` ; le schéma des **maps** est un autre document, contenu dans `json_schema` du contrat.

## 1. Récupérer le prompt et conserver un cache

Appelez l’instance AppControl dans laquelle vous importerez les maps :

```http
GET /api/v1/map-generation/contract
Authorization: ApiKey <clé AppControl>
```

La réponse JSON contient notamment :

| Champ | Utilisation |
|---|---|
| `contract_version` | Version des règles de génération, à transmettre lors de la validation et de l’import. |
| `product_version` | Version du serveur ayant fourni le contrat. |
| `prompt_revision` | Révision des instructions. |
| `system_prompt` | Instructions complètes, avec le schéma et les exemples intégrés, à transmettre à votre IA. |
| `user_message_template` | Modèle de message utilisateur ; remplacer `{{input_documents}}` par les documents de l’application. |
| `json_schema` | Schéma JSON du profil de génération. Peut aussi configurer la sortie structurée de votre moteur, s’il accepte ce dialecte de JSON Schema. |
| `examples` | Exemples nommés : chacun contient un champ `map`. |
| `capabilities` et `limitations` | Fonctionnalités du profil et limites à prendre en compte par l’intégration. Le schéma reste la référence pour les champs acceptés. |

La révision actuelle des instructions est `prompt_revision: "7"`. L’IA reprend
dans `source_site` le code ou le nom du site explicitement documenté pour un
composant. Lorsque les hôtes sont inconnus, elle laisse `binding_profiles`
et `host` absents. L'intégration peut fournir les placements autorisés.
`contract_version: "1"` et `format_version: "4.2"` ne sont pas des numéros de
révision du prompt. Conserver la réponse du contrat plutôt que coder ces
instructions en dur.

Stockez la réponse et son en-tête `ETag` dans un cache **séparé pour chaque instance, identité de connexion et ensemble d’options**. Avant le lot suivant, vérifiez sa fraîcheur :

```http
GET /api/v1/map-generation/contract
Authorization: ApiKey <clé AppControl>
If-None-Match: "<empreinte reçue précédemment>"
```

- **`304 Not Modified`** : réutiliser le contenu déjà conservé ; le corps de la réponse est vide.
- **`200 OK`** : remplacer le contenu du cache et son `ETag`.
- **Erreur de connexion ou d’authentification** : ne pas considérer le cache comme validé pour une publication automatique.

Une seule vérification suffit pour un lot de plusieurs centaines de documents. Conservez le même contrat pendant le lot, ainsi que sa version et son empreinte dans votre suivi de génération. Un contrat incompatible sera refusé lors de la validation ou de l’import.

### Choisir un profil et réutiliser le catalogue

Le paramètre `profile` choisit les instructions de génération :

| Profil | Usage |
|---|---|
| `standard` (défaut) | Décrire l’application à partir des informations et commandes fournies, sans inventer de procédure d’exploitation. |
| `mock-linux` | Générer une map de démonstration avec des commandes simulées pour un agent Linux. |
| `mock-windows` | Même objectif, avec des commandes simulées pour un agent Windows. |

Exemple :

```http
GET /api/v1/map-generation/contract?profile=mock-linux
```

Le paramètre `profile` du contrat choisit uniquement les instructions adressées à l’IA. Il ne sélectionne pas un mode d’exécution et ne doit pas être recopié dans l’enveloppe d’import normale. Un **profil de rattachement** associe les composants aux agents ; un profil PRA fournit une affectation alternative. Ces objets sont distincts du profil de génération.

Les profils mock servent à tester le parcours de génération et l’exploitation simulée. Ils ne constituent pas les commandes de production de l’application décrite. Relisez les commandes générées avant d’importer et utilisez des agents de test adaptés. **Une map importée et rattachée à un agent peut activer immédiatement ses commandes de vérification périodique.** L’import ne lance pas à lui seul un démarrage ou un arrêt de l’application.

Pour donner à l’IA les briques de votre catalogue AppControl, ajoutez `include_catalog=true`. Le paramètre facultatif `catalog_types` limite les briques aux clés indiquées, séparées par des virgules :

```http
GET /api/v1/map-generation/contract?profile=standard&include_catalog=true&catalog_types=payments-service,batch-worker
```

Le champ `catalog` contient alors les briques de **votre organisation**, avec leur clé, leur description et leurs commandes de vérification, démarrage et arrêt. Les variables d’environnement du catalogue sont exclues. L’IA reprend la clé dans `component_type` et développe les commandes retenues dans la map ; il ne s’agit pas d’un lien vivant qui modifierait ultérieurement les maps déjà importées.

Cette option expose du contenu propre à l’organisation : une clé API doit avoir `catalog:read`, ou une capacité globale `read`, `design` ou `*`. Une clé limitée à une seule application peut obtenir le contrat générique, mais pas le catalogue de toute l’organisation. Les commandes et descriptions du catalogue peuvent contenir des informations internes : leur transmission au modèle relève du moteur du client.

La réponse est limitée à 100 briques et 256 Kio de données de catalogue. Si le catalogue dépasse ces limites, utilisez `catalog_types` pour sélectionner les briques pertinentes au traitement.

Un changement du profil, de la sélection de briques ou du contenu retourné du catalogue change l’`ETag`. Il faut conserver ces options dans la clé du cache et utiliser la même URL lors de la vérification conditionnelle.

Pour combiner publication et génération guidée par le catalogue, attribuer
explicitement `maps:import` et `catalog:read`. `catalog:write` permet les mutations
du catalogue, toujours sous les droits administrateur de son propriétaire ; il
ne remplace pas `catalog:read` pour obtenir ce snapshot dans le prompt.

Le catalogue accepte un [import atomique avec aperçu et mise à jour](EMBEDDED.fr.md#alimenter-le-catalogue-du-client).
Le mode `add` conserve les clés existantes ; `upsert` exige un aperçu `dry_run`
puis son `digest` dans `expected_digest`. Une modification du catalogue n'applique
pas rétroactivement ses commandes aux maps déjà publiées.

### Exemple de cache en PowerShell

Le dépôt fournit `examples/map-generation-client.ps1`, compatible PowerShell 5.1 et 7, sans Python. Il fournit une fonction de récupération avec cache en mémoire, sans appel de modèle ni import automatique :

```powershell
. .\map-generation-client.ps1
$cache = @{}

# La cle provient de votre gestionnaire de secrets ou de l'environnement.
# Ne pas l'ecrire en clair dans le script ou dans l'historique du terminal.
$contrat = Get-AppControlGenerationContract `
    -BaseUrl 'https://appcontrol.banque.example' `
    -ApiKey $env:APPCONTROL_API_KEY -Cache $cache

# Au lot suivant, reutiliser le meme cache : la fonction envoie If-None-Match.
$contrat = Get-AppControlGenerationContract `
    -BaseUrl 'https://appcontrol.banque.example' `
    -ApiKey $env:APPCONTROL_API_KEY -Cache $cache

$document = Get-Content -LiteralPath '.\application.json' -Raw
$messageSysteme = $contrat.system_prompt
$messageUtilisateur = $contrat.user_message_template.Replace('{{input_documents}}', $document)
# Transmettre ces deux messages a votre propre moteur d'IA.
```

Les options `-Profile mock-linux`, `-IncludeCatalog` et `-CatalogTypes 'payments-service','batch-worker'` sont disponibles. Le cache est séparé par instance, clé et options, ne stocke pas la clé en clair et n’est pas écrit sur disque. L’URL doit être HTTPS et son certificat approuvé par le poste ; la fonction ne désactive pas la vérification TLS. Elle refuse de réutiliser silencieusement le cache en cas d’échec de connexion ou d’autorisation.

## 2. Appeler votre IA

Envoyez `system_prompt` comme instruction système et le message préparé à partir de `user_message_template` comme contenu utilisateur. Les documents restent des **données à analyser**, séparées des instructions du produit. Si votre API de modèle utilise d’autres noms pour ces rôles, adaptez uniquement cet appel.

Pour un schéma ou une autre image, votre moteur doit transmettre l’image dans le format multimodal accepté par son modèle, avec son nom ou sa référence. Coller une chaîne Base64 dans le texte du prompt ne remplace pas ce traitement. Le contrat donne les règles de génération ; le moteur du client reste responsable de la lecture et de la préparation de ses formats documentaires.

Le résultat attendu, lorsqu’une map peut être produite, est **un objet JSON de map**, sans balises Markdown. Votre moteur peut l’enregistrer dans un fichier, mais ce n’est pas nécessaire pour l’envoyer à l’API.

Si le résultat contient `generation_error`, traitez-le comme un diagnostic et ne tentez pas de l’importer. Le `json_schema` décrit uniquement une map réussie : un moteur imposant une sortie structurée doit gérer cette alternative d’erreur séparément, sans contraindre l’IA à inventer une map pour satisfaire le schéma.

Le prompt explique notamment le sens des dépendances, les commandes et les [clusters à membres explicites](FAN_OUT.md). Un cluster `fan_out` contient les membres connus et leurs éventuelles variantes de commandes ; il ne déclenche pas une découverte automatique de machines par sélecteur. Le prompt interdit d’inventer des commandes, des machines ou des secrets absents des sources. Les champs manquants peuvent entraîner des avertissements ; une réponse signalant une impossibilité de génération ne doit jamais être envoyée comme une map.

Le coût du modèle dépend du volume documentaire et du modèle choisi par le client. AppControl ne déclenche aucun appel de modèle dans ce parcours. Le cache HTTP évite de retransférer le contrat depuis AppControl, mais le prompt reste transmis au modèle pour chaque génération. Une éventuelle mise en cache des tokens du prompt dépend des capacités du fournisseur ou du moteur d’IA utilisé.

### Exemple externe avec plusieurs documents et correction bornée

Le client de démonstration `demo-rebuild/map-generation/generate.py` récupère le
contrat installé, appelle un fournisseur externe, puis valide le JSON. Il ne
publie aucune map et n'exécute aucune commande. Il utilise `APPCONTROL_API_KEY`
ou `APPCONTROL_TOKEN` pour le contrat et la validation ; la clé du fournisseur
reste dans son propre processus.

```sh
python3 demo-rebuild/map-generation/generate.py \
  --url https://appcontrol.banque.example \
  --profile standard \
  --include-catalog \
  --catalog-types web-portal payments-api ibm-mq oracle-rac \
  --documents dossier-architecture.fr.md procedures-exploitation.fr.md \
  --repair-attempts 1 \
  --anthropic-key-file /chemin/prive/cle-anthropic.txt \
  --output resultat-generation
```

`--documents` combine uniquement les fichiers UTF-8 explicitement sélectionnés,
avec leurs noms. `--include-catalog` ajoute le catalogue autorisé au contrat ;
`--catalog-types` limite les briques demandées et implique cette option.
`--repair-attempts` accepte `0`, `1` ou `2` (défaut `1`) : si le candidat JSON est
refusé par le schéma, les erreurs structurées sont renvoyées au modèle pour au plus
ce nombre de corrections, chacune à nouveau validée. Un JSON illisible, une
réponse tronquée ou un `generation_error` arrête le parcours. Le client ne corrige
pas lui-même la topologie ou les commandes pour faire passer la validation.

Le dossier de sortie conserve le contrat, les réponses du modèle, les candidats
rejetés, les rapports de validation et les empreintes de génération. `--replay`
ne rappelle pas le modèle et exige des documents, contrat, modèle et candidat
inchangés ; il revalide le candidat enregistré. Un replay ne prouve pas un nouvel
appel à l'IA. Ces fichiers contiennent les connaissances fournies au modèle :
ils restent privés. Python est ici un outil de démonstration, pas un prérequis
pour intégrer les API HTTP d'AppControl.

## 3. Vérifier le JSON sans modifier AppControl

```http
POST /api/v1/maps/validate
Authorization: ApiKey <clé AppControl>
Content-Type: application/json

{
  "contract_version": "1",
  "map": {
    "format_version": "4.2",
    "application": {
      "name": "Paiements",
      "components": [
        { "name": "api", "component_type": "service" },
        { "name": "base", "component_type": "database" }
      ],
      "dependencies": [ { "from": "api", "to": "base", "dep_type": "strong" } ]
    }
  }
}
```

Dans cet exemple, `api` dépend de `base`. L’absence de commandes et de rattachement à des agents est volontaire : l’exemple représente une structure, pas une application prête à exploiter.

La réponse contient `valid`, `errors` et `warnings`. Chaque diagnostic comporte `path` (chemin JSON), `code` et `message`.

- `200` avec `valid: true` : le JSON respecte le profil structurel et les règles vérifiables sans accès aux ressources d’exécution. Examiner aussi les avertissements.
- `200` avec `valid: false` : corriger les erreurs, éventuellement avec un nouvel appel à votre IA, puis revérifier.
- `409` : version du contrat incompatible ; récupérer le contrat actuel et régénérer ou adapter le candidat.
- `400` ou `422` : requête mal formée ; corriger son enveloppe ou son JSON.
- `401` ou `403` : problème d’authentification ou d’autorisation.

La validation ne crée aucune application et n’exécute aucune commande. **Elle ne prouve pas la fidélité aux documents, l’existence d’un agent, la justesse d’une procédure shell ou la disponibilité d’un serveur.** Ces vérifications et la revue des commandes restent nécessaires **avant l’import**, car les agents rattachés peuvent commencer les vérifications périodiques dès réception de la map. Le profil de génération est strict : un champ inconnu est rejeté au lieu d’être ignoré.

## 4. Importer la map validée

### Parcours recommandé : placements par composant et équipes

Créez une clé **Import new application maps — real or simulated** dans AppControl : sa portée `maps:import` donne accès au contexte filtré et aux nouvelles routes de préparation/publication. Elle ne permet ni de modifier une application existante, ni d'appeler start/stop. Elle permet cependant de publier des commandes de vérification qui peuvent s'exécuter immédiatement : la revue des commandes précède la publication. Le catalogue complet conserve son contrôle séparé `catalog:read` (ou une capacité globale `read`/`design`).

1. `GET /api/v1/map-generation/context` (équivalent à `?profile=standard`) retourne les sites accessibles et leurs agents enrôlés, avec leur état. Le client peut exploiter les noms/codes pour rapprocher son référentiel.
2. `POST /api/v1/map-generation/prepare` vérifie la map et résout chaque placement, sans créer d'application. Examiner `ready`, `issues`, `bindings`, `member_bindings` et `warnings`.
3. `POST /api/v1/map-generation/import` reçoit **le même corps**, refait les contrôles puis crée l'application. Il retourne `application_id`. Il ne faut pas remplacer l'entrée par les UUID ou commandes de la prévisualisation.

Exemple de requête pour une application répartie :

```json
{
  "contract_version": "1",
  "site_code": "PARIS",
  "placements": [
    {"component_name": "base", "site_code": "PARIS", "host": "db-paris.example"},
    {"component_name": "api", "site_code": "LYON", "host": "api-lyon.example"}
  ],
  "team_grants": [
    {"team_id": "44444444-4444-4444-8444-444444444444", "permission_level": "operate"}
  ],
  "map": {
    "format_version": "4.2",
    "application": {
      "name": "Paiements",
      "components": [
        {"name": "base", "component_type": "database"},
        {"name": "api", "component_type": "service"}
      ],
      "dependencies": [{"from": "api", "to": "base", "dep_type": "strong"}]
    }
  }
}
```

Remplacez les hôtes et l'identifiant d'équipe par ceux de votre instance, et utilisez la map issue des documents avec ses procédures relues. Cet exemple montre les affectations ; il ne contient volontairement aucune procédure de production. `ready` signifie que la préparation accepte la configuration, pas que les procédures sont éprouvées.

Omettez `profile` dans cette enveloppe. L’import normal utilise `standard` par défaut et conserve les commandes fournies, y compris celles d’un prompt mock. L’écriture explicite `"profile": "standard"` reste compatible. Une entrée dans `placements` définit en priorité le site du composant. À défaut, AppControl rapproche `source_site` du code ou du nom d’un site de l’organisation, en ignorant la casse et les espaces en bordure. Une correspondance unique avec un site actif permet de préparer le placement. Une référence introuvable, inactive ou ambiguë demande une affectation explicite. En l’absence des deux champs, le `site_code` administratif de l’enveloppe sert de site par défaut.

En `standard`, choisissez **soit** `agent_id`, **soit** `host` dans `placements`. À défaut, le `host` du composant sert de référence. AppControl recherche l’hôte ou l’IP exacte dans le site résolu. Un code de site seul laisse le choix de l’agent à compléter. Un agent enregistré mais hors ligne produit un avertissement. Vérifiez le rapport de préparation avant la publication.

L'intégration construit ces placements à partir du référentiel structuré et du contexte AppControl. Ils restent séparés du JSON de map : les documents ne peuvent pas attribuer eux-mêmes des droits ou inventer des UUID. Le contexte est relu par lot et les cibles sont recontrôlées à chaque publication.

Une map issue d’un prompt mock utilise ces mêmes placements avec `host` ou `agent_id`, les mêmes agents enrôlés et les mêmes `team_grants`. Le serveur ne réécrit ni ses commandes ni son nom. Une base à Paris et une API à Lyon s’exécutent simultanément, qu’elles représentent des services réels ou des fichiers témoins. Un profil DR reste une destination alternative du parcours classique ci-dessous.

L’outil historique `simulation_workflow` est facultatif et distinct : il transforme les commandes côté serveur et exige des défauts mock enregistrés par site. Seuls ses appels dédiés, ou un `profile: "mock-linux"` / `"mock-windows"` explicitement demandé à la publication, activent cette transformation. Choisir un prompt mock ne l’active pas. Voir la [section de compatibilité](SIMULATION_MAPS.fr.md#outil-historique-facultatif-transformation-par-le-serveur).

Les membres `fan_out` du parcours général utilisent le site de leur composant. Pour des membres répartis sur plusieurs sites, le parcours classique avec `member_mappings` explicites permet de choisir leurs agents. Les profils DR avec membres restent soumis aux limites de réaffectation documentées.

### Automatiser un lot depuis Windows

Le kit léger inclut `map-publication-client.ps1`, compatible PowerShell 5.1 et 7, sans outil supplémentaire. Après avoir récupéré le contrat et produit les maps avec votre moteur, utilisez :

```powershell
. .\map-publication-client.ps1
$url = 'https://appcontrol.banque.example'
$contexte = Get-AppControlPublicationContext -BaseUrl $url `
  -ApiKey $env:APPCONTROL_API_KEY -Profile standard
$lot = @(Get-Content '.\lot-publications.json' -Raw -Encoding UTF8 | ConvertFrom-Json)
$preparations = @(Import-AppControlMaps -BaseUrl $url `
  -ApiKey $env:APPCONTROL_API_KEY -Requests $lot)
# Apres revue des commandes, des placements et des droits :
$resultats = @(Import-AppControlMaps -BaseUrl $url `
  -ApiKey $env:APPCONTROL_API_KEY -Requests $lot -Importer)
$resultats | Select-Object index,success,ready,imported,error
```

Chaque élément du lot est une enveloppe complète comme l'exemple précédent. Le helper retourne un résultat par application, avec les problèmes de préparation dans `issues`. `ready: false` bloque la publication de cet élément ; les autres éléments continuent. Il ne réessaie pas les imports et ne remplace pas les applications existantes. Conserver les résultats et vérifier la présence de l'application avant toute reprise après une coupure réseau. Les communications utilisent HTTPS avec la confiance TLS du poste.

### Créer les équipes et attribuer les applications

Dans **Teams**, créez par exemple « Exploitation Paiements », ajoutez ses membres, puis ouvrez son onglet **Applications** pour attribuer une application et choisir le niveau `view`, `operate`, `edit`, `manage` ou `owner`. Le partage depuis la fiche de l'application reste disponible. Gérer une équipe ne donne pas automatiquement le droit de partager toutes les applications : l'acteur doit avoir au moins `manage` sur l'application et ne peut accorder un niveau supérieur au sien.

Pour automatiser, créez l'équipe et ses membres une fois via `/teams` et `/teams/{id}/members`, avec une identité autorisée. Conservez son UUID côté intégration. L'enveloppe `team_grants` associe ensuite les nouvelles applications aux équipes au moment de l'import, avec un niveau explicite et une expiration facultative. Les équipes ne sont ni des groupes graphiques, ni des champs de la map générée par l'IA. Une application peut être attribuée à plusieurs équipes.

Les droits hérités dépendent des membres actuels. Quand les restrictions de sites par workspace sont configurées, l'équipe doit avoir accès à tous les sites concernés par l'attribution, et l'utilisateur à tous les sites actuellement utilisés par l'application. Le retrait d'un membre ou d'un accès de site est pris en compte lors des requêtes suivantes. Sans configuration de workspaces/sites, la politique d'accès de l'organisation reste ouverte sur ses sites.

### Imports classiques et affectations explicites

Les routes historiques `/import/*`, `/agents`, `/gateways` et `/sites` demandent une session utilisateur autorisée, ou une clé `*` soumise aux droits de son propriétaire. Les portées `maps:import` et `mock:import` n'ouvrent pas ces routes historiques. Les exemples suivants restent utiles pour les profils DR, les mises à jour explicites et les affectations avancées.

L’import est une publication de configuration, pas une simple validation : lorsqu’un agent est rattaché, la configuration lui est transmise et les commandes de vérification peuvent être exécutées automatiquement. Pour un premier essai, choisissez un agent de test et des commandes relues. Le profil mock guide l’IA, mais ne constitue pas une garantie que toute commande renvoyée par le modèle est une simulation.

```http
POST /api/v1/import/json
Authorization: Bearer <session autorisée à importer>
Content-Type: application/json

{
  "generation_contract_version": "1",
  "site_id": "11111111-1111-4111-8111-111111111111",
  "json": "{\"format_version\":\"4.2\",\"application\":{\"name\":\"Paiements\",\"components\":[{\"name\":\"api\",\"component_type\":\"service\"},{\"name\":\"base\",\"component_type\":\"database\"}],\"dependencies\":[{\"from\":\"api\",\"to\":\"base\",\"dep_type\":\"strong\"}]}}"
}
```

Remplacez l’UUID d’exemple par un `sites[].id` obtenu avec `GET /api/v1/sites`. Le champ `json` est une **chaîne**, contrairement au champ `map` de la validation, qui est un objet. Utilisez le sérialiseur JSON de votre langage plutôt qu’un assemblage manuel de guillemets. Réutilisez `contract_version` reçu du serveur ; ne fixez pas cette valeur dans votre intégration.

Le marqueur `generation_contract_version` active à nouveau la validation stricte avant l’import : un fichier modifié après sa vérification n’échappe donc pas aux contrôles. Les rattachements aux agents et les droits sont vérifiés par le parcours d’import. Une map sans commandes ou sans rattachement complet peut rester une map à compléter, pas une autorisation d’exécution.

### Associer la map à la fiche source

Au départ de la génération, le job retient l’identifiant stable de l’application
dans le référentiel de l’hôte, par exemple `PAI-042`. Utilisez la même valeur pour
les versions successives du Knowledge Document et pour l’URL de la fiche.
Ajoutez ce champ facultatif à l’enveloppe de préparation et d’import, à côté de
`map` et des paramètres de placement.

```json
{"source_reference":{"system":"documentation","id":"PAI-042"}}
```

AppControl réserve la référence à la création et la rend disponible à la
résolution après réussite de la publication. La réponse d’import donne toujours
l’`application_id`. Une référence réservée par une autre application produit un
conflit `409`. Après une erreur réseau ou une publication incomplète, vérifiez
l’état de la map avant de relancer l’import. Une réservation incomplète est
masquée à la résolution. Traitez l’éventuelle map partielle avec le parcours
habituel de revue et de suppression autorisée avant de republier.

Le portail peut demander l’UUID correspondant à l’identifiant de la fiche avec
`GET /api/v1/embedded/resolve`. Voir [Relier les fiches à leur map AppControl](EMBEDDED.fr.md#relier-les-fiches-a-leur-map-appcontrol).

### Choisir les agents au moment de l’import

L’IA décrit l’application ; l’intégration peut choisir les agents après la génération. Un **agent** est un processus déjà installé et enrôlé, qui exécute les commandes sur une machine. Une **gateway** relie ces agents à AppControl. Un **site** représente une implantation ou un environnement logique ; ce n’est pas le projet/namespace OpenShift.

| Appel d’inventaire | Valeur à récupérer | Usage |
|---|---|---|
| `GET /api/v1/sites` | `sites[].id` | `site_id` du parcours d’import. |
| `GET /api/v1/gateways` | `sites[].gateways[].id` | Sélection des gateways ; la réponse est regroupée par site. |
| `GET /api/v1/agents` | `agents[].id`, `hostname`, `gateway_id`, `connected`, `is_active` | Choisir les agents déjà enrôlés et vérifier leur état. |

Les UUID ci-dessous sont uniquement des exemples syntaxiquement valides. Copiez les valeurs de votre instance. Un nom de machine dans une map n’installe ni n’enrôle un agent.

Deux parcours sont disponibles :

- **Import direct `/import/json`** : la map contient ses `host` ou ses `binding_profiles`, avec les noms d’hôtes. AppControl résout les cibles réelles et leurs droits. Une cible explicitement nommée mais inconnue ou ambiguë bloque l’import strict. Un composant ordinaire sans hôte peut être importé sans agent, avec avertissement, puis complété ; les membres `fan_out` doivent avoir des cibles résolues.
- **Assistant `/import/preview` puis `/import/execute`** : les rattachements sont fournis à côté de la map, dans `profile.mappings`. Chaque entrée associe un nom exact de composant à un UUID d’agent. C’est le parcours adapté pour décider de l’environnement au moment de la publication.

Pour un premier essai de l’assistant, prévisualisez la résolution dans les gateways choisies :

```http
POST /api/v1/import/preview
Content-Type: application/json

{
  "format": "json",
  "gateway_ids": ["22222222-2222-4222-8222-222222222222"],
  "content": "{\"format_version\":\"4.2\",\"application\":{\"name\":\"Paiements\",\"components\":[{\"name\":\"api\",\"component_type\":\"service\",\"host\":\"test-agent.example\"}],\"dependencies\":[]}}"
}
```

`content` est la map sérialisée. Le preview renvoie `components[].resolution.status` (`resolved`, `multiple`, `unresolved` ou `no_host`), les agents disponibles et l’éventuelle application de même nom. Une sélection vide de gateways ne fournit aucun agent candidat. Le preview ne modifie pas l’application, ne lance aucune commande et ne remplace pas `/maps/validate` : il ne reçoit pas le marqueur de contrat strict.

Après validation, revue des commandes et choix des cibles, publiez avec les UUID explicites :

```http
POST /api/v1/import/execute
Content-Type: application/json

{
  "generation_contract_version": "1",
  "format": "json",
  "site_id": "11111111-1111-4111-8111-111111111111",
  "content": "{\"format_version\":\"4.2\",\"application\":{\"name\":\"Paiements\",\"components\":[{\"name\":\"api\",\"component_type\":\"service\"}],\"dependencies\":[]}}",
  "profile": {
    "name": "Evaluation",
    "profile_type": "primary",
    "gateway_ids": ["22222222-2222-4222-8222-222222222222"],
    "mappings": [
      {
        "component_name": "api",
        "agent_id": "33333333-3333-4333-8333-333333333333",
        "resolved_via": "manual"
      }
    ]
  },
  "conflict_action": "fail"
}
```

Cet exemple sans commandes sert à comprendre le rattachement. Pour une démonstration opérationnelle, utilisez à sa place la map validée et revue générée avec `mock-linux` ou `mock-windows`. Rattachez chaque composant au bon agent, et conservez les cibles explicites des membres `fan_out` lorsqu’il y en a.

**Ne mélangez pas les deux mécanismes** : avec `generation_contract_version`, l’assistant refuse une map qui contient déjà `binding_profiles`. Utilisez alors l’import direct, ou produisez une map sans profils intégrés et passez les profils explicitement dans l’enveloppe de l’assistant. Les profils secondaires se renseignent dans `dr_profiles`, chacun avec son nom distinct, son type (`dr` ou `custom`), ses gateways et ses correspondances.

### Créer ou mettre à jour une application existante

Dans `/import/execute`, `conflict_action` concerne une application **de même nom** :

| Valeur | Comportement |
|---|---|
| `fail` (défaut) | Si le nom existe, refus `409`. Sinon, création. |
| `rename` | Si le nom existe, création sous `new_name`, qui doit être renseigné et libre. |
| `update` | Si le nom existe, remplacement de sa configuration importée après les vérifications de droits, profils et cibles. Sinon, création. |

Une mise à jour se prépare à partir d’un export ou d’une version de référence conservée, puis se valide et se revoit. Ce parcours n’offre pas une transaction globale ni un mécanisme d’annulation complet. En cas d’erreur serveur ou de coupure réseau, inspectez l’application avant de relancer. Le champ historique `merge_into_app_id` de `/import/json` **n’est pas pris en charge** : sa présence avec un UUID est refusée.

## Organiser un traitement par lots

Pour chaque document, conservez sa référence et sa version, la version du contrat, le JSON produit, le rapport de validation et, si l’import a réussi, l’identifiant de l’application. Traitez les erreurs document par document afin qu’un candidat incomplet ne bloque pas tout le lot.

Commencez par un petit lot représentatif et contrôlez les commandes et dépendances obtenues. La génération peut ensuite être parallélisée avec une concurrence bornée, selon les limites de votre modèle et de votre instance. Le cache réduit les transferts du contrat ; il ne remplace pas les vérifications de qualité des maps.

Les profils historiques d’import et les exports peuvent contenir des métadonnées supplémentaires. Le schéma fourni par cette API décrit le **profil de génération**, pas l’ensemble des anciens formats acceptés par AppControl.
