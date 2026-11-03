# Essayer les API avec Swagger UI

AppControl embarque une page de documentation interactive : **API documentation** dans le menu, ou **`https://<votre-instance>/api-docs`**. Elle affiche les routes décrites par la version installée et permet d’essayer les requêtes. Les fichiers de Swagger UI sont livrés avec l’interface ; aucune ressource Swagger hébergée à l’extérieur n’est nécessaire.

Le parcours de génération et de publication décrit ici est disponible à partir
d'**AppControl 1.21.1**. Installer le serveur et l'interface de la même release ;
sur Windows/OpenShift, le kit léger correspondant est **1.21.1-1**. Les anciens
rapports de qualification ne remplacent pas ceux de cette livraison.

La couverture de la documentation progresse par fonctionnalité : elle ne représente pas encore toutes les API du produit. Le parcours de génération de maps par une IA externe, sa validation et ses imports sont décrits avec leurs paramètres, corps de requête et réponses.

## 1. Se connecter

Ouvrez AppControl et connectez-vous normalement, puis ouvrez **API documentation**. Sur la même instance, votre session de navigateur sert aux appels.

Pour tester avec une clé API, utilisez **Authorize**, puis le champ `apiKeyAuth`. Saisissez **`ApiKey ` suivi de la clé**, par exemple `ApiKey <votre-clé>`. L’en-tête utilisé est `Authorization`, pas `X-API-Key`. L’option `bearerAuth` attend un JWT de session AppControl ; elle ne prend pas directement un jeton d’un fournisseur d’identité. Les identifiants saisis ne sont pas conservés après le rechargement de cette page.

| Appels | Accès avec une clé API |
|---|---|
| Contrat générique et validation | Clé valide, y compris une clé restreinte. |
| Contrat avec catalogue de l’organisation | Portée globale `read`, `design` ou `*` ; une portée sur une seule application ne suffit pas. |
| Contexte standard et publication `/map-generation/prepare`, `/map-generation/import` | Portée `maps:import`, `*` ou session autorisée ; droits de site conservés. |
| Contexte et imports dédiés à la simulation | Portée `mock:import`, `maps:import`, `*` ou session autorisée ; `mock:import` ne permet pas le standard. |
| Inventaire et `/import/*` | Dans cette version : clé `*` avec les droits de son propriétaire, ou session utilisateur autorisée. Une clé restreinte à `design` n’ouvre pas ces routes. |

La possession d’une clé ne remplace pas les droits sur les applications et les sites. Le compte qui publie doit être autorisé à importer dans le périmètre choisi.

## 2. Obtenir les instructions pour votre IA

Dépliez **Map generation → GET /map-generation/contract**. Cliquez sur **Try it out**, choisissez `standard`, `mock-linux` ou `mock-windows` dans `profile`, puis **Execute**. Ce choix concerne le prompt : les deux profils mock demandent à votre IA des commandes utilisant des fichiers témoins. Il ne change aucun réglage global ni aucun agent. L’URL affichée sous la requête inclut le préfixe `/api/v1`.

La réponse `200` contient :

- `system_prompt` : les instructions produit complètes à transmettre à votre moteur d’IA ;
- `user_message_template` : le message dans lequel remplacer `{{input_documents}}` par les documents de l’application ;
- `json_schema`, `examples`, `capabilities` et `limitations` : le contrat de génération et ses limites ;
- `contract_version`, `prompt_revision`, `product_version` : les versions à conserver avec votre résultat.

AppControl ne reçoit pas les documents sources et n’appelle pas d’IA dans cette opération. C’est votre moteur qui exécute les messages. Pour commencer sans modèle, un objet `map` de la liste `examples` peut servir à essayer la validation ; ses hôtes et procédures restent illustratifs.

Pour vérifier le cache, copiez l’en-tête de réponse **ETag**, avec ses guillemets, dans le paramètre **If-None-Match** et relancez la même requête. Un `304` signifie « réutiliser le contrat conservé » et n’a pas de corps. Changez de cache si l’instance, l’identité, le profil ou la sélection du catalogue change.

## 3. Vérifier le résultat sans créer d’application

Dépliez **POST /maps/validate**, cliquez sur **Try it out**, puis remplacez l’exemple par :

```json
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
      "dependencies": [
        { "from": "api", "to": "base", "dep_type": "strong" }
      ]
    }
  }
}
```

Utilisez le `contract_version` réellement retourné par votre instance. Ici, l’API dépend de la base ; les commandes et les agents sont volontairement absents.

Cliquez sur **Execute**, puis regardez **`valid`**, pas seulement le code HTTP. Un `200` peut contenir `valid: false`. Les `errors` et `warnings` précisent le chemin JSON, un code et le message. Par exemple, remplacez la cible de la dépendance par `base-inconnue` pour observer un refus, puis remettez `base`.

La validation ne crée aucune map et n’exécute aucune commande. Elle ne vérifie pas la fidélité aux documents, la sécurité des procédures, la présence des agents ou leur disponibilité. Un `409` indique qu’il faut rafraîchir le contrat.

## 4. Choisir l’environnement et publier

Le parcours général est dans **Map generation** :

1. `GET /map-generation/context` (ou `?profile=standard`) pour connaître les sites et agents accessibles.
2. `POST /map-generation/prepare` sans champ `profile`, avec le site administratif, les `placements` par composant, les `team_grants` explicites éventuels et la `map` sous forme d'objet JSON. La réponse doit avoir `ready: true` ; examiner également les avertissements et cibles résolues.
3. `POST /map-generation/import` avec la même requête après revue. Le serveur revalide les cibles et crée la nouvelle application.

L'[exemple multi-sites complet](MAP_GENERATION.fr.md#parcours-recommande-placements-par-composant-et-equipes) place une base à Paris et son API à Lyon en même temps. Ce parcours conserve exactement les commandes fournies, y compris celles issues des prompts mock. Il utilise des agents ordinaires, sans registre mock obligatoire. `profile` absent vaut `standard` ; ne recopiez pas le profil de génération dans cette enveloppe. Applications réelles et simulées coexistent dans la même instance. Une cible hors ligne n’est pas une preuve d’exploitabilité. Un profil de rattachement ou PRA définit des affectations aux agents ; il est distinct du choix de prompt.

Les sections **Teams** et **Permissions** documentent la création d'une équipe, ses membres et le partage d'applications. Les identifiants d'équipes dans `team_grants` viennent de cette configuration, pas de l'IA. La clé `maps:import` ne donne pas les droits d'administration des équipes. Le parcours classique ci-dessous reste disponible pour les affectations avancées et profils alternatifs.

Dans **Sites**, **Gateways** et **Agents**, essayez les listes pour identifier vos ressources :

| Réponse | Valeur à utiliser |
|---|---|
| `GET /sites` → `sites[].id` | Site cible. |
| `GET /gateways` → `sites[].gateways[].id` | Gateway ; la liste est regroupée par site. |
| `GET /agents` → `agents[].id` | Agent enrôlé. Inspectez aussi `hostname`, `connected` et `is_active`. |

Ouvrez ensuite **Map imports**. Les exemples intégrés aux trois requêtes sont des enveloppes JSON valides ; remplacez leurs UUID de démonstration et leur contenu par vos valeurs.

1. **`POST /import/preview`** vérifie la résolution des hôtes dans les gateways sélectionnées. `content` est une **chaîne contenant le JSON sérialisé**, et `gateway_ids` une liste d’UUID de gateways. Le preview reste sans publication et ne remplace pas la validation stricte précédente.
2. **`POST /import/execute`** publie avec des correspondances explicites : `profile.mappings` associe chaque `component_name` à un `agent_id`. Le marqueur `generation_contract_version` réactive les contrôles stricts avant publication. Commencez avec `conflict_action: "fail"`.
3. **`POST /import/json`** est l’alternative pour une map qui contient déjà ses hôtes ou ses `binding_profiles`. Elle attend la map dans la chaîne `json` et crée une nouvelle application. Elle n’est pas un upsert.

Ne cumulez pas les profils intégrés à la map et ceux de l’assistant : l’import strict par `/import/execute` refuse des `binding_profiles` intégrés. Les exemples et le détail des profils DR, du renommage et de la mise à jour sont dans le [guide de génération](MAP_GENERATION.fr.md#choisir-les-agents-au-moment-de-limport).

**Publier peut activer immédiatement les vérifications périodiques sur les agents.** Relisez les commandes avant l’import et choisissez des agents de test pour les profils de simulation. Un clic **Execute** dans Swagger appelle réellement l’API ; ce n’est pas une animation. L’import n’effectue pas lui-même un start/stop de l’application.

Après le retour `201`, conservez `application_id`, lisez les avertissements puis retrouvez la map dans la liste des applications. Une coupure pendant l’import ne justifie pas une répétition automatique : vérifiez d’abord ce qui a été créé ou modifié.

## Quel document sert à quoi ?

| Document | Adresse ou emplacement | Rôle |
|---|---|---|
| Swagger UI | `/api-docs` | Lire les API et effectuer des appels interactifs. |
| OpenAPI JSON | `/api/v1/openapi.json` | Décrire les requêtes et réponses HTTP, pour vos outils d’intégration. |
| Contrat de génération | `/api/v1/map-generation/contract` | Fournir le prompt et le format de map à l’IA du client. |
| JSON Schema de map | Champ `json_schema` du contrat | Décrire précisément le JSON que l’IA doit produire. |
| Guide d’intégration | [Génération de maps](MAP_GENERATION.fr.md) | Cache, profils, catalogue, rattachements et traitement par lots. |

Si `/api-docs` ou les routes de génération sont absentes, mettre à jour
l'instance vers AppControl 1.21.1 ou une version ultérieure compatible. Le numéro
de version de l'OpenAPI est celui du serveur installé.


## Outil historique facultatif : transformation serveur avec défauts par site

Le groupe **Map generation** conserve un outil distinct de transformation serveur : gestion administrative des défauts mock par site et routes `/map-generation/mock/*`. Il remplace les commandes fournies et exige ces défauts. Ce n’est pas le parcours requis pour une map produite avec un prompt mock : celle-ci utilise l’import normal ci-dessus. Le corps `MockMapRequest` contient `contract_version`, `profile`, `site_code` (ou `hosting_name` non ambigu), `dr_site_codes` et l’objet `map`. Une clé `mock:import` suffit à ce parcours, sans ouvrir les imports historiques. Voir le [guide de simulation](SIMULATION_MAPS.fr.md#outil-historique-facultatif-transformation-par-le-serveur).
