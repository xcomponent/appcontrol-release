# Raccorder une source documentaire à X4B

Le [contrat OpenAPI](knowledge-engine.openapi.yaml) décrit les opérations
du connecteur. **Côté client, deux opérations suffisent au parcours de
génération**. Lister les documents courants et exécuter un prompt sur la
révision demandée. La lecture directe du JSON est facultative.

X4B fournit le prompt et le schéma AppControl. Le Knowledge Engine présente
le document dans son format d’origine à l’IA interne. Pour vérifier une brique
proposée que le premier inventaire n’a pas identifiée, X4B peut lire la révision
exacte du document une fois. Il vérifie l’empreinte et cherche le nom du
composant et le produit dans le même enregistrement JSON. Ce contrôle est
facultatif et le document est traité en mémoire. Une source sans cette opération
continue à générer des propositions dont les rapprochements incertains restent à
confirmer.

**Une URL de base** dessert le catalogue et l’exécution du prompt. Par
exemple, avec `https://knowledge.example/api/v1`, X4B appelle
`https://knowledge.example/api/v1/knowledge-documents` et
`https://knowledge.example/api/v1/prompt-executions`. L’interface X4B
s’appelle **Génération de maps** et désigne ce raccordement comme la
**source documentaire**.

| Opération | Ce que le Knowledge Engine fournit |
| --- | --- |
| `GET /knowledge-documents` | Une liste paginée des clés applicatives autorisées et de l’empreinte SHA-256 de leur document courant. Le filtre `application_key` vérifie la révision courante d’une application. |
| `GET /knowledge-documents/{application_key}/versions/{sha256}` | Le JSON d’une révision précise, pour la prévisualisation, le diagnostic ou la vérification d’un rapprochement. |
| `POST /prompt-executions` | L’exécution synchrone d’un prompt générique sur le document désigné par sa clé applicative et son empreinte. Le service renvoie le texte de l’IA et la référence effectivement utilisée. |

## Exemple de raccordement

La liste renvoie des métadonnées uniquement.

```json
{
  "items": [
    {
      "application_key": "00142",
      "sha256": "5c7a066fce3161f2ac727f983aa1c877a646c2f7b27608d8ff244e7cc4b6f982"
    }
  ]
}
```

Pour générer la map de cette application, X4B envoie les instructions au
Knowledge Engine avec la référence du document.

```json
{
  "document": {
    "application_key": "00142",
    "sha256": "5c7a066fce3161f2ac727f983aa1c877a646c2f7b27608d8ff244e7cc4b6f982"
  },
  "prompt": "Génère la map conformément aux instructions et au schéma fournis par AppControl."
}
```

En pratique, X4B utilise le champ `system_prompt` du
[contrat de génération AppControl](MAP_GENERATION.fr.md), qui contient déjà le
schéma. X4B ajoute l’instruction de produire une map à partir du document joint.
Le Knowledge Engine charge localement la version demandée et joint le document
comme donnée d’entrée. Si l’IA interne accepte un seul texte, le service
concatène le prompt et le document dans un bloc délimité. Le corps du document
reste côté Knowledge Engine pendant le parcours nominal.

La clé applicative reprend l’identifiant exact du référentiel, casse et zéros
initiaux compris. Pour un portail documentaire externe, utiliser le CIA comme `application_key`.
Un autre référentiel peut fournir sa propre clé. Calculer le SHA-256 sur
les octets UTF-8 du JSON versionné et conserver ces octets pour la lecture
et l’exécution. Servir une révision
indisponible en `404`. La rétention des versions doit couvrir la durée des
lots et de leurs reprises. Le profil d’authentification utilise un
jeton de service sur HTTPS, limité aux opérations et documents autorisés.

## Cycle de mise à jour côté X4B

1. **Synchroniser le catalogue.** À la demande ou selon une planification, X4B
   parcourt les pages et compare, par source et clé applicative, les empreintes observées
   à celles des générations précédentes. Il met en file les nouvelles révisions.
   Un document sans changement réutilise son résultat pour la même configuration.
2. **Générer.** Le traitement de fond limite le nombre d’appels simultanés et
   conserve l’état de chaque application dans PostgreSQL. Il identifie une
   génération par la source, la clé applicative, l’empreinte du document et le
   contexte de génération, dont le prompt, les références du catalogue de
   composants et les codes et noms des sites actifs. Un retour `429` déclenche une reprise différée. Un délai
   dépassé ou une coupure après envoi est signalé pour relance. Après un
   arrêt du backend pendant un appel, sa reprise peut consommer un deuxième
   appel à l’IA. La déduplication des générations et des maps est
   gérée dans X4B. Une ancienne révision devenue indisponible déclenche une
   nouvelle lecture du catalogue.
3. **Valider et publier.** X4B vérifie la référence retournée, valide le JSON
   avec AppControl et conserve le résultat candidat. Il vérifie la révision
   courante avant publication. Pour une première map, il enregistre la
   référence externe `{"system":"documentation","id":"00142"}`, avec un nom de
   source stable configuré côté X4B. Pour une map existante, il affiche les
   écarts entre la proposition et la version publiée et permet d’appliquer la
   mise à jour après confirmation. X4B garde
   séparément l’empreinte source de la map publiée et celle de la dernière
   génération. Une disparition du catalogue est signalée et la map est conservée.

Avec un catalogue de composants AppControl, X4B demande d’abord à l’IA de relever
les briques et les indices techniques dans le document. Il compare ces éléments
aux clés, libellés et alias du catalogue de l’organisation. Le prompt final est
exécuté sur le même document avec l’ensemble des clés, libellés, descriptions et
alias du catalogue, les suggestions par composant et les codes et noms des sites
actifs. Un choix sémantique de l’IA non confirmé par le rapprochement déterministe
est signalé pour revue. Une brique sans correspondance est marquée **À qualifier**
dans le graphe. Dans **Rapprochements catalogue**, cliquez sur une suggestion
pour l’affecter au brouillon, ou ouvrez le sélecteur pour rechercher une autre
brique. Si vous confirmez la publication d’une brique sans type, elle utilise le type générique
`custom`. Ses commandes et son agent déjà configurés sont conservés. Pour une
nouvelle brique, configurez ces éléments dans AppControl avant de l’exécuter.
Les commandes, icônes et couleurs du catalogue restent dans AppControl.
Sans catalogue de composants, X4B exécute directement le prompt final avec les
sites disponibles.

L’aperçu de la proposition permet d’ouvrir l’éditeur. Le zoom et le bouton
**Plein écran** sont disponibles dans les deux vues. Sélectionnez un composant
pour rechercher une brique par libellé, description ou mot-clé. Vous pouvez
aussi modifier son libellé, sa description et ses sites documentés, déplacer
les composants ou ajuster leurs dépendances. Enregistrez la proposition, examinez les écarts
et confirmez la publication. X4B refuse la publication si la proposition ou
la map a changé depuis la revue et vous invite à recharger. Les sites
documentés servent à décrire l’architecture. L’affectation des agents se fait
dans AppControl.

L’aperçu et la map publiée indiquent l’obsolescence renseignée par la source,
avec le niveau s’il est fourni. Les états reconnus sont **À jour**, **Obsolète**
et **Obsolescence inconnue**. Une brique sans information documentée n’affiche aucun
badge d’obsolescence. Pour récupérer l’information sur une proposition déjà
générée, utilisez **Relancer la génération** et relisez le résultat avant de
publier.

Sur une map déjà publiée, X4B reconnaît les composants existants par leur nom.
La mise à jour conserve leurs identifiants, leurs commandes et leurs agents,
ainsi que le site de rattachement de la map. Elle applique la topologie
relue, dont les ajouts et changements de dépendances. Tout composant de la
map publiée absent de la proposition bloque la publication. Réintégrez-le
avec son nom d’origine dans la proposition ou retirez-le de la map dans
AppControl après vérification.
La relance manuelle remplace la proposition en attente, même si la source n’a
pas changé ; elle ne modifie pas la map publiée.

Le JSON de la proposition peut être téléchargé pour une revue Git manuelle.
Cet export ne crée ni commit ni pull request et ne synchronise pas le dépôt.

## Préparer et rejouer l’installation OpenShift

Copiez `configuration.example.json` en `configuration.json`. Le fichier
décrit les sites, hébergements, gateways, agents Linux persistants,
catalogue, comptes, équipes et la référence de source documentaire.
Fournissez-le à `Deployer-AppControl.ps1` pour appliquer le socle et ces
réglages dans une invocation. Conservez le dossier d’état privé indiqué
par le script. Les nouveaux comptes locaux utilisent une saisie de mot
de passe masquée.

| Terme dans AppControl | Sens dans le déploiement | Exemple |
| --- | --- | --- |
| **Hosting** | Regroupement facultatif de sites d’exécution. | Zone ou campus Paris. |
| **Site** | Lieu d’exécution où l’on rattache les gateways et les agents. | `PAR-DC1` ou `PAR-DC2` pour les datacenters du site client Paris. |
| **Gateway** | Relais entre AppControl et les agents du site. | Une gateway interne pour commencer. |
| **Agent** | Exécute les contrôles et actions de la map sur sa cible. | Un agent Linux persistant par site avec le kit. |

Avec deux sites sur un même cluster OpenShift, la démo représente deux lieux
d’exécution logiques. Les datacenters réels sont des cibles que le client
raccorde avec leurs gateways et agents.

### Raccorder la source documentaire

Le backend doit pouvoir joindre le connecteur. Avec Helm,
`networkPolicy.backendHttpsCIDRs` permet de déclarer les CIDR approuvés sur le
port 443. Le kit OpenShift natif prépare la règle de sortie pour les Services
HTTP internes. Pour une source HTTPS externe, appliquez la politique de
sortie approuvée pour le backend de cette installation.

#### Renseigner l’URL et le jeton dans X4B

Un administrateur peut renseigner l’URL et le jeton directement dans
**Génération de maps → Paramètres**. Saisissez l’URL complète terminée par
`/api/v1`, le jeton et, si nécessaire, le nom de source utilisé pour rapprocher
les fiches. L’activation et la désactivation du connecteur prennent effet
sans redémarrage du backend.

Par défaut, l’interface accepte les URLs HTTPS vers les hôtes accessibles
sur Internet et les URLs HTTP `service.projet.svc` dans le projet du backend
sur OpenShift. Dans ce dernier cas, si la politique réseau ne permet pas
déjà cette connexion, utilisez le préparateur pour créer la règle de sortie :

```powershell
.\Preparer-SourceDocumentaire.ps1 -Projet appcontrol-poc `
  -NomInstallation appcontrol-evaluation `
  -ReseauSeulement -OriginesAutorisees 'http://documentation.appcontrol-poc.svc'
```

Dans l’interface, saisissez ensuite `http://documentation.appcontrol-poc.svc/api/v1`.
En HTTP, les données et le jeton circulent en clair. `-ReseauSeulement` crée une
NetworkPolicy de sortie limitée aux pods sélectionnés par le Service et à son
port cible. Le compte `oc` doit pouvoir lire le Service et gérer la règle. Le
script détecte l’installation si elle est unique dans le projet. Sinon, ou
avant son déploiement, utilisez `-NomInstallation`. Les Services sans
sélecteur nécessitent une règle gérée par la plateforme. Une éventuelle
politique d’entrée du service documentaire doit aussi autoriser le backend.

Dans le formulaire, **Tester la connexion** vérifie l’accès avec le
jeton saisi et contrôle le format de la première page de
`GET /knowledge-documents`. **Tester le prompt sur un document** appelle
`POST /prompt-executions` sur le premier document accessible et vérifie
la référence de la révision et la topologie AppControl renvoyée. Ce second
test utilise l’IA du connecteur. Les tests ne sauvegardent aucun réglage,
ne lancent aucun lot et ne publient aucune map. **Enregistrer** applique les
paramètres.

La plateforme peut désactiver les réglages de l’interface avec
`X4B_KNOWLEDGE_SETTINGS_ENABLED=false`. Quand
`X4B_KNOWLEDGE_SETTINGS_ALLOWED_ORIGINS` est renseigné, seules les origines
exactes de la liste, séparées par des virgules, sont acceptées.
Pour appliquer cette liste via un Secret OpenShift, utilisez
`Preparer-SourceDocumentaire.ps1 -AutoriserReglagesUI -OriginesAutorisees …`,
puis référencez le nom du Secret dans `document_source.secret_name` et
appliquez le JSON avec `Deployer-AppControl.ps1 -Configuration` ou
`Configurer-AppControl.ps1` sur une instance existante.

Les jetons enregistrés dans l’interface sont chiffrés. Par défaut, la clé
dérive du secret JWT du déploiement. Vous pouvez fournir une clé dédiée avec
`X4B_KNOWLEDGE_SETTINGS_KEY` (32 octets aléatoires encodés en base64). Toutes
les répliques doivent utiliser la même clé. Gardez la clé dédiée déjà
configurée, ou gardez le secret JWT si vous utilisez la clé par défaut. En
cas de changement de clé effective, saisissez de nouveau le jeton dans
l’interface.

#### Fournir le connecteur au déploiement

Pour une configuration automatisée, fournissez le connecteur au backend au
démarrage. Cette configuration est prioritaire pour l’organisation concernée.
Sur OpenShift, utilisez un Secret de type `Opaque` dans le projet de
l’installation, avec les clés suivantes.

| Clé | Valeur |
| --- | --- |
| `X4B_KNOWLEDGE_URL` | URL de base de la source terminant par `/api/v1`, en HTTPS par défaut. |
| `X4B_KNOWLEDGE_TOKEN` | Jeton de service autorisé à lister les documents et à exécuter les prompts pour le périmètre choisi. |
| `X4B_KNOWLEDGE_ORGANIZATION_ID` | Pour une base vide initialisée par le kit, `00000000-0000-0000-0000-000000000001`. Pour une organisation existante, champ `user.organization_id` de `/api/v1/users/me` dans une session administrateur. |
| `X4B_KNOWLEDGE_SOURCE` | Nom stable de la source, `documentation` par défaut. Pour un portail documentaire externe, utiliser la valeur configurée pour le rapprochement des fiches, par exemple `documentation`. |
| `X4B_KNOWLEDGE_REFRESH_SECONDS` | Intervalle de synchronisation. `0` par défaut pour un déclenchement à la demande. |
| `X4B_KNOWLEDGE_CONCURRENCY` | De 1 à 4 appels IA simultanés par backend, 2 par défaut. |
| `X4B_KNOWLEDGE_HTTP_SERVICE` | Nom DNS exact du Service interne autorisé en HTTP, par exemple `documentation.appcontrol-poc.svc`. |
| `X4B_KNOWLEDGE_TLS_SKIP_VERIFY` | `true` pour ignorer la vérification du certificat du connecteur HTTPS configuré au déploiement, en développement uniquement. |
| `X4B_KNOWLEDGE_CA_FILE` | Chemin d’un fichier PEM déjà monté, si la source utilise une autorité interne. |

Pour créer ce Secret depuis un script PowerShell, lancez
`Preparer-SourceDocumentaire.ps1` depuis le dossier du kit avant le déploiement.
La commande utilise la connexion OpenShift active et demande le jeton en saisie
masquée. En automatisation, injectez `X4B_KNOWLEDGE_TOKEN` depuis votre coffre et
ajoutez `-NonInteractif`. Vous pouvez aussi fournir une valeur `SecureString`
avec `-Jeton`.

```powershell
.\Preparer-SourceDocumentaire.ps1 -Projet appcontrol-poc `
  -Url 'https://knowledge.example/api/v1' `
  -Organisation '00000000-0000-0000-0000-000000000001' -Source documentation
```

Pour un Service interne au cluster, utilisez son nom DNS et le **port du
Service**, généralement 80 en HTTP. Ajoutez `-AutoriserHttpInterne`.

```powershell
.\Preparer-SourceDocumentaire.ps1 -Projet appcontrol-poc `
  -NomInstallation appcontrol-evaluation `
  -Url 'http://documentation.appcontrol-poc.svc/api/v1' `
  -AutoriserHttpInterne -Organisation '00000000-0000-0000-0000-000000000001'
```

Si le connecteur utilise HTTPS avec un certificat interne non reconnu, montez
de préférence le PEM de son autorité de certification et indiquez-le via
`X4B_KNOWLEDGE_CA_FILE`. Pour un test temporaire, ajoutez
`-IgnorerCertificatTls` à la commande HTTPS. Cette option désactive la
vérification du certificat pour le seul connecteur fourni au déploiement.
Relancez le préparateur sans l’option puis redémarrez le backend pour rétablir
la vérification. En HTTP, le jeton et les documents circulent en clair.

En cas d’échec, consultez les journaux du **backend**, par exemple
`oc -n appcontrol-poc logs deployment/appcontrol-demo-backend --since=10m`.
Cherchez `Knowledge source`. Le journal indique l’opération, l’hôte,
le statut HTTP ou le type d’échec de transport. Si une NetworkPolicy limite
les sorties, vérifiez la NetworkPolicy créée et les éventuelles restrictions
d’entrée sur les pods de la source.

Le script crée `appcontrol-source-documentaire` par défaut. Il peut mettre à
jour un Secret qu’il a créé et laisse un Secret préexistant intact. Ajoutez
`-Intervalle 900` pour synchroniser la source toutes les quinze minutes.

Ajoutez ce champ à la racine de `configuration.json` avec le nom du Secret
existant.

```json
{
  "document_source": {
    "secret_name": "appcontrol-source-documentaire"
  }
}
```

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-poc -Nom appcontrol-demo -ModePostgreSQL Integre `
  -Configuration .\configuration.json -SansDemo
```

Ici, `-SansDemo` laisse le portefeuille libre pour votre scénario.
La commande accepte `-Verifier` pour contrôler la configuration et les
prérequis accessibles avant installation. Avec une instance déjà installée,
`Configurer-AppControl.ps1` peut appliquer le même JSON avec le dossier
d’état existant. Une rotation du jeton dans le même Secret demande un
redémarrage du backend pour recharger la valeur.
[Procédure du kit Windows](qualification/INSTALLATION-WINDOWS.fr.md#configuration-apres-installation-equipes-et-topologie)

### Vérifier le parcours dans X4B

1. Ouvrez **Génération de maps** en tant qu’administrateur et cliquez sur
   **Tester la connexion**. X4B lit une page du catalogue. Ce test sert à
   vérifier l’accès réseau et l’authentification de lecture avant la
   génération.
2. Cliquez sur **Synchroniser les sources**. X4B met en file les documents
   nouveaux ou modifiés du périmètre autorisé et affiche l’état de chaque
   clé. Le premier lot peut être borné par le périmètre du compte de service.
3. Examinez les candidates et les sites proposés par composant. Si le document
   situe une même API à `Sirius` et `Legac`, les deux sites apparaissent sur ce
   composant et restent visibles sur la map publiée. La revue signale les sites
   introuvables ou ambigus. Si chaque composant correspond au même site actif,
   le formulaire individuel le propose comme rattachement administratif de
   l’application. Les autres cas demandent un choix explicite. Les placements
   d’exécution et les agents se configurent dans AppControl.
   Une publication groupée peut traiter jusqu’à
   100 candidates par appel API. Une fois les maps présentes, ajoutez les
   droits d’équipe dans AppControl ou renseignez `permissions` dans le
   JSON de configuration et relancez le script.
4. Pour démontrer une évolution, modifiez un document source puis
   resynchronisez. X4B génère une proposition pour la nouvelle empreinte.
   Ouvrez le détail dans **À comparer**, relisez les écarts et utilisez
   **Modifier la carte** pour ajuster la proposition. Cliquez sur
   **Publier la mise à jour**, confirmez, puis ouvrez la map publiée.
5. Ouvrez la map dans le widget pour tester sa reconstruction. Avec un seul
   site dédié dans `embedded.simulation_sites`, AppControl utilise l’agent et
   la gateway enrôlés par le kit pour ce site. Toutes les maps publiées et
   accessibles au portail peuvent être simulées ainsi, sans affectation par
   composant. Avec plusieurs cibles, la session indique le site de simulation
   choisi. Les sites documentés sur la map restent visibles dans le widget.
   Le chart Helm sait configurer le backend
   et l’encadrement HTTP. Sur le kit natif, le bloc `embedded` de
   `configuration.json` sélectionne les origines autorisées et les codes des
   sites dédiés. L’exception d’encadrement est limitée aux routes de session
   Embedded. [Configuration Windows/OpenShift](qualification/INSTALLATION-WINDOWS.fr.md#activer-embedded-pour-un-portail-documentaire)

Le catalogue du connecteur couvre les documents visibles par le compte de
service. La mesure de couverture du portefeuille suppose un inventaire
applicatif de référence. Le module accepte jusqu’à 10 000 références par
synchronisation.

### Décider à quel moment une map change

| Situation | Automatisation | Décision humaine |
| --- | --- | --- |
| Première génération | Le résultat validé attend dans **À publier**. | Un administrateur choisit le site et publie une map ou un lot. |
| Même empreinte et même configuration | X4B réutilise la génération précédente. | Aucune action. |
| Catalogue de composants ou sites actifs modifiés | La synchronisation recalcule les propositions concernées. | Relire les correspondances avant publication. |
| Empreinte différente et map déjà publiée | X4B prépare une proposition et affiche les écarts dans **À comparer**. | Un administrateur relit et ajuste la proposition, puis confirme la mise à jour. |
| Source absente ou génération en erreur | L’état est visible dans la file et la map publiée reste disponible. | L’utilisateur corrige la source ou relance l’échec. |

X4B vérifie la version source et la version de la map relue. L’application
de la topologie, l’enregistrement de la révision publiée et l’écriture
de l’audit se font dans la même transaction. Une modification concurrente
demande une nouvelle revue.

### Évolution vers Git

Pour le POC, la décision humaine se prend dans AppControl. La proposition
doit identifier la map, la version source, la version active relue et
l’empreinte des changements approuvés. L’audit enregistre l’auteur de la
décision et la révision appliquée.

Dans une étape suivante, X4B peut ouvrir une pull request contenant ces
mêmes références et le diff. X4B calcule les écarts sur des clés de
composant stables et sur les dépendances entre ces clés. La revue
porte sur les ajouts, modifications et retraits identifiés. Une
sérialisation déterministe trie les collections sans ordre métier
pour éviter les changements de formatage. Une fois la PR approuvée
et fusionnée, un
compte de service dédié demande l’application dans AppControl. AppControl
vérifie le périmètre, l’empreinte approuvée et les versions courantes avant
la publication. Une modification intervenue pendant la revue produit une
nouvelle proposition. La PR sert à la revue et à la traçabilité. AppControl
reste responsable de la publication de la map.
