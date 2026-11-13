# Raccorder une source documentaire à X4B

Le [contrat OpenAPI](knowledge-engine.openapi.yaml) décrit les opérations
du connecteur. **Côté client, deux opérations suffisent au parcours de
génération**. Lister les documents courants et exécuter un prompt sur la
révision demandée. La lecture directe du JSON sert au diagnostic.

X4B fournit le prompt et le schéma AppControl. Le Knowledge Engine présente
le document dans son format d’origine à l’IA interne. Le connecteur X4B
traite uniquement les métadonnées de source et le JSON de map retourné.

**Une URL de base** dessert le catalogue et l’exécution du prompt. Par
exemple, avec `https://knowledge.example/api/v1`, X4B appelle
`https://knowledge.example/api/v1/knowledge-documents` et
`https://knowledge.example/api/v1/prompt-executions`. L’interface X4B
s’appelle **Génération de maps** et désigne ce raccordement comme la
**source documentaire**.

| Opération | Ce que le Knowledge Engine fournit |
| --- | --- |
| `GET /knowledge-documents` | Une liste paginée des clés applicatives autorisées et de l’empreinte SHA-256 de leur document courant. Le filtre `application_key` vérifie la révision courante d’une application. |
| `GET /knowledge-documents/{application_key}/versions/{sha256}` | Le JSON d’une révision précise, pour la prévisualisation ou le diagnostic. |
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
initiaux compris. Pour le portail documentaire, utiliser le CIA comme `application_key`.
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
   génération par la source, la clé applicative, l’empreinte du document et celle du
   prompt envoyé. Un retour `429` déclenche une reprise différée. Un délai
   dépassé ou une coupure après envoi est signalé pour relance. Après un
   arrêt du backend pendant un appel, sa reprise peut consommer un deuxième
   appel à l’IA. La déduplication des générations et des maps est
   gérée dans X4B. Une ancienne révision devenue indisponible déclenche une
   nouvelle lecture du catalogue.
3. **Valider et publier.** X4B vérifie la référence retournée, valide le JSON
   avec AppControl et conserve le résultat candidat. Il vérifie la révision
   courante avant publication. Pour une première map, il enregistre la
   référence externe `{"system":"documentation","id":"00142"}`, avec un nom de
   source stable configuré côté X4B. Pour une map existante, il propose les
   écarts de topologie entre la candidate et la map actuelle. La revue peut
   servir à reporter les changements choisis dans AppControl. X4B garde
   séparément l’empreinte source de la map publiée et celle de la dernière
   génération. Une disparition du catalogue est signalée et la map est conservée.

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

Le backend lit la configuration au démarrage. L’interface permet de tester
et de synchroniser la source configurée. Sur OpenShift, créez un Secret de
type `Opaque` dans le projet de l’installation, avec les clés suivantes.

| Clé | Valeur |
| --- | --- |
| `X4B_KNOWLEDGE_URL` | URL de base HTTPS de la source, avec le préfixe `/api/v1`. |
| `X4B_KNOWLEDGE_TOKEN` | Jeton de service autorisé à lister les documents et à exécuter les prompts pour le périmètre choisi. |
| `X4B_KNOWLEDGE_ORGANIZATION_ID` | Pour une base vide initialisée par le kit, `00000000-0000-0000-0000-000000000001`. Pour une organisation existante, champ `user.organization_id` de `/api/v1/users/me` dans une session administrateur. |
| `X4B_KNOWLEDGE_SOURCE` | Nom stable de la source, `documentation` par défaut. Pour le portail documentaire, utiliser la valeur configurée pour le rapprochement des fiches, par exemple `documentation`. |
| `X4B_KNOWLEDGE_REFRESH_SECONDS` | Intervalle de synchronisation. `0` par défaut pour un déclenchement à la demande. |
| `X4B_KNOWLEDGE_CONCURRENCY` | De 1 à 4 appels IA simultanés par backend, 2 par défaut. |
| `X4B_KNOWLEDGE_CA_FILE` | Chemin d’un fichier PEM déjà monté, si la source utilise une autorité interne. |

Faites autoriser la sortie HTTPS du pod backend vers le service de la source.
Avec Helm, `networkPolicy.backendHttpsCIDRs` permet de déclarer les CIDR
approuvés sur le port 443. Avec le kit OpenShift natif, appliquez la politique
de sortie approuvée pour le backend de cette installation.

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
3. Examinez les candidates et les sites proposés par composant. Par exemple,
   une source qui situe la base sur `Vega` et l’API sur `Sirius` affiche les
   deux correspondances si ces sites sont configurés. La revue signale les
   sites introuvables ou ambigus. Si tous les composants correspondent au
   même site actif, le formulaire individuel le propose comme rattachement
   de l’application. Les autres cas demandent un choix explicite. La
   publication X4B crée la topologie, et l’import opérationnel utilise son
   propre parcours pour résoudre les agents.
   Une publication groupée peut traiter jusqu’à
   100 candidates par appel API. Une fois les maps présentes, ajoutez les
   droits d’équipe dans AppControl ou renseignez `permissions` dans le
   JSON de configuration et relancez le script.
4. Pour démontrer une évolution, modifiez un document source puis
   resynchronisez. X4B génère une proposition pour la nouvelle empreinte
   et affiche les écarts avec la map en service. Pour reporter un changement
   manuellement, ouvrez **Ouvrir la map publiée**, puis **Edit**. La
   proposition reste à comparer tant que l’intégration de la révision
   source n’a pas été enregistrée par une action dédiée.
5. Ouvrez la map pour la qualifier dans AppControl. Le widget peut utiliser
   sa copie de simulation quand les cibles dédiées et les origines
   autorisées sont configurées. Le chart Helm sait configurer le backend
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
| Empreinte différente et map déjà publiée | X4B prépare une nouvelle candidate et affiche le diff dans **À comparer**. | L’utilisateur décide quels changements reporter dans la map existante. |
| Source absente ou génération en erreur | L’état est visible dans la file et la map publiée reste disponible. | L’utilisateur corrige la source ou relance l’échec. |

Pour appliquer une révision depuis cette page, l’évolution à développer
est une action de revue sur les changements proposés. Un premier périmètre
peut appliquer les ajouts de composants et de dépendances sur le même UUID.
La publication doit vérifier la version source et la version de la map
relue, conserver les commandes et placements existants et écrire l’audit
dans la même transaction. Une révision concurrente demande une nouvelle
revue. Les suppressions et les modifications opérationnelles demandent
une politique de fusion explicite.

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
