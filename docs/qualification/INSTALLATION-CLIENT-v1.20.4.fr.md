# AppControl 1.20.4 — installation d’évaluation sur OpenShift

> **Depuis Windows :** suivre le [parcours Windows guidé](INSTALLATION-WINDOWS.fr.md). Son ZIP léger contient seulement les scripts et les YAML ; il utilise PowerShell et le `oc` existant, sans Python, Docker, Helm ni WSL. La procédure ci-dessous concerne le kit Linux/macOS original.

Procédure complémentaire du 31 octobre 2026, pour le kit binaire **1.20.4**
issu du commit `15c5be2ca7cd43647748c7e4227123051342291d`.
Elle précise le parcours client et trois corrections de lecture du kit, sans
modifier son archive, ses empreintes ou son tag.

**Objectif : installer AppControl dans un projet isolé, constater son
fonctionnement, puis cadrer un POC sur une application réelle.** Les preuves
de la livraison sont celles présentes dans `VALIDATION.fr.md`, `provenance.json`
et `evidence/`. Cette procédure n’atteste pas de tests supplémentaires ni de la
qualification de l’environnement du client.

## 1. Préparer l’installation avec l’équipe plateforme

L’installation autonome utilise **quatre pods : interface, backend, gateway et
PostgreSQL**. La recette ajoute un cinquième pod, un agent synthétique jetable.
Les agents des applications s’installent ensuite sur leurs machines ; il ne
faut pas un pod AppControl par application. Le connecteur MCP est optionnel.

Prévoir :

- Un projet OpenShift dédié déjà créé, des nœuds Linux AMD64 et les droits de
  création/modification des ressources du projet : Deployments, StatefulSets,
  Services, Secrets, ConfigMaps, PVC, NetworkPolicies, Routes et port-forward
  pour la recette. Les pods n’exigent ni cluster-admin ni SCC `anyuid`.
- Une classe de stockage utilisable et **2 Gio persistants**. Les réservations
  des quatre services sont de **1,1 vCPU et 960 Mio** ; l’agent de recette ajoute
  0,05 vCPU et 32 Mio. Vérifier aussi les limites et les quotas du projet.
- Un registre interne approuvé, accessible aux nœuds. Un poste d’import avec
  **Skopeo**, authentifié à ce registre ; un secret de pull dans le projet si
  le registre le demande. Installer sa CA dans les magasins de confiance.
- Deux noms DNS vers le routeur : interface **HTTPS 443** et gateway
  **WSS 443**. La Route web est réencryptée ; la Route gateway exige le
  passthrough TLS et des connexions WebSocket longues. Ces noms peuvent rester
  internes au réseau de la banque.
- Un poste d’installation avec **Python 3.9+, kubectl, Helm 3 et OpenSSL**,
  un kubeconfig valide et la confiance TLS des Routes. `oc` peut obtenir le
  kubeconfig ; **`kubectl` reste requis par les scripts**.
- Un dossier privé persistant, hors du kit et hors Git, pour les identifiants
  et certificats. Le conserver lors des mises à jour.

Le cluster n’a pas besoin d’accéder à GitHub une fois les images importées.
Aucune compilation du produit n’est nécessaire chez le client. Les flux
complémentaires des commandes métier seront à examiner pour le POC.

## 2. Vérifier le kit et importer ses images

Prendre les fichiers `appcontrol-openshift-1.20.4.tar.gz` et
`appcontrol-openshift-1.20.4.tar.gz.sha256` de la livraison officielle.
Depuis leur dossier :

```sh
sha256sum -c appcontrol-openshift-1.20.4.tar.gz.sha256
tar -xzf appcontrol-openshift-1.20.4.tar.gz
cd appcontrol-openshift-1.20.4
sha256sum -c SHA256SUMS
```

Sur macOS, remplacer `sha256sum` par `shasum -a 256`. Examiner les scans datés,
les SBOM et la provenance avec l’équipe sécurité ; appliquer ses propres
contrôles d’admission. Toutes les commandes suivantes partent de la **racine
du kit extrait**.

Remplacer `registre.banque/appcontrol` par le préfixe approuvé. Le tag d’import
doit être réservé à cette livraison :

```sh
python3 scripts/qualification/transfer-images.py import \
  --lock images.source.lock.json --archive-dir images-oci \
  --target-prefix registre.banque/appcontrol --version 1.20.4 \
  --output-lock images.lock.json --execute
```

Sans `--execute`, le script affiche le plan. Il importe les cinq archives OCI
locales, conserve leurs digests et crée `images.lock.json` pour les quatre
services, plus `images.lock.json.agent.txt` pour l’agent de recette. Ne pas
désactiver la vérification TLS. Les authentifications suivent la procédure du
registre ; aucun mot de passe n’est à ajouter à ces arguments.

## 3. Configurer et installer

```sh
cp scripts/qualification/client.example.json client.json
```

Exemple à adapter aux valeurs du client :

```json
{
  "kubeconfig": "/chemin/prive/kubeconfig",
  "context": "contexte-openshift-client",
  "namespace": "appcontrol-evaluation",
  "release": "appcontrol",
  "state_dir": "/chemin/prive/appcontrol",
  "image_lock": "images.lock.json",
  "openshift_host": "appcontrol.apps.cluster.banque",
  "gateway_host": "gateway-appcontrol.apps.cluster.banque"
}
```

Ce JSON ne contient aucun secret. Les chemins relatifs sont résolus depuis
son emplacement ; ici, `client.json` et `images.lock.json` sont à la racine
du kit. Les deux noms DNS doivent correspondre aux Routes convenues.

```sh
python3 scripts/qualification/install.py --config client.json --preflight-only
python3 scripts/qualification/install.py --config client.json
```

Pour un registre privé, ajouter **`--image-pull-secret appcontrol-registry`**
aux deux commandes, en remplaçant ce nom par celui du secret déjà créé dans
le projet. Ajouter `--storage-class NOM` aux deux commandes si nécessaire.
Le précontrôle vérifie les outils et droits sans modifier le cluster ; l’accès
aux images, le stockage, les SCC et les Routes sont vérifiés au déploiement.

L’installateur crée les secrets de cette installation, installe les quatre
services et vérifie la connexion de la gateway. Il indique les URL ainsi que
le chemin du certificat public des agents. Les identifiants administrateur
sont dans `/chemin/prive/appcontrol/credentials.json`. Ne pas inclure ce dossier
privé dans les rapports ou le paquet remis à un tiers.

## 4. Recette et démonstration

**Réserver cette recette à l’installation d’évaluation isolée : elle exécute
des commandes synthétiques et redémarre gateway, backend et PostgreSQL.**
Reprendre exactement le kubeconfig, contexte, namespace, release et dossier
privé renseignés dans `client.json` :

```sh
python3 scripts/qualification/e2e.py \
  --kubeconfig /chemin/prive/kubeconfig \
  --context contexte-openshift-client \
  --namespace appcontrol-evaluation --release appcontrol \
  --state-dir /chemin/prive/appcontrol \
  --agent-image "$(cat images.lock.json.agent.txt)" \
  --openshift --evidence qualification-client.json
```

Attendre **PASS**. Le rapport vérifie la connexion HTTPS, les refus de
permissions, l’enrôlement de l’agent, l’admission SCC, l’ordre réel de démarrage
et d’arrêt, les reconnexions et la persistance après redémarrage.

Puis se connecter dans le navigateur, ouvrir l’application `Qualification
dependencies …` identifiée par le rapport, et montrer :

1. `api-probe` dépend de `database-probe` ; leurs commandes sont visibles.
2. **Start All** : les deux composants passent à RUNNING dans l’ordre attendu.
3. **Stop All** : retour à STOPPED dans l’ordre inverse ; consulter l’historique.

Cette application ne manipule que des marqueurs de test, sans IA ni service
bancaire. Conserver le rapport et les observations de cette installation.
Le pod agent est jetable ; il ne constitue pas le modèle de persistance d’un
agent d’exploitation.

## 5. Ajouter un agent extérieur au cluster

La gateway incluse suffit pour le premier agent. Celui-ci initie une connexion
sortante **WSS 443** ; aucun port entrant AppControl n’est requis sur sa machine.
Le passage réseau doit préserver TLS/mTLS, sans terminaison TLS intermédiaire
supprimant le certificat client.

Sur une machine Linux AMD64, avec un compte de service dédié :

1. Installer le binaire `artifacts/appcontrol-agent` du kit, après vérification
   des empreintes. Vérifier son lancement et les outils requis par les commandes.
2. Copier uniquement le certificat **public** `agent-ca.crt` fourni par
   l’installation. Ne jamais distribuer la clé privée de la CA.
3. Dans **Enrollment**, créer un jeton de portée **agent**, à usage unique et
   durée courte. Le remettre par le canal sécurisé convenu et le conserver dans
   un fichier privé, mode 0600. Préparer un dossier d’état persistant, mode 0700,
   appartenant au compte de service.
4. Depuis ce compte et la racine du kit extrait sur cette machine :

```sh
python3 scripts/qualification/enroll-agent.py \
  --binary /opt/appcontrol/appcontrol-agent \
  --gateway wss://gateway-appcontrol.apps.cluster.banque \
  --ca /etc/appcontrol/agent-ca.crt \
  --token-file /chemin/prive/token \
  --state-dir /chemin/prive/agent --preflight-only
```

Relancer sans `--preflight-only` pour enrôler puis exécuter l’agent. Le
précontrôle vérifie DNS, TCP et certificat serveur ; il ne consomme pas le
jeton. Vérifier ensuite l’agent connecté dans **Agents**, puis l’exécution
de commandes de test dans les droits de ce compte.

Après succès, retirer le fichier de jeton et conserver l’identité dans le
dossier d’état. Pour le service permanent, utiliser
`appcontrol-agent --config /chemin/prive/agent/agent.yaml`, avec
`APP_ENV=production`. Adapter le modèle
`scripts/qualification/appcontrol-agent.service.example`. Qualifier les droits
OS, la survie des processus métier et la reconnexion sur la machine réelle.

## 6. Limites et adaptation aux images bancaires

Ce parcours vise une **évaluation mono-instance**. Les mises à jour du backend
comportent une interruption. La persistance d’un PVC ne prouve pas une
sauvegarde restaurable. SSO, PKI, base gérée, haute disponibilité, charge et
reprise d’une reconstruction interrompue demandent des validations distinctes.
Les certificats de service générés durent 90 jours et le jeton gateway 30 jours ;
leur renouvellement est explicite.

Si la banque impose ses bases d’images, les recettes `docker/corporate/`
permettent de reconditionner les artefacts déjà compilés. Les images obtenues
ont de nouveaux digests et doivent être scannées et testées à nouveau. La
qualification des images du kit ne s’applique pas automatiquement à ces
nouvelles images. Une base `scratch` ne fournit pas les outils nécessaires
à l’agent, à nginx ou à PostgreSQL.

Des scans datés sans vulnérabilité ne signifient pas absence de faille.
Rescanner avant une livraison ultérieure et après toute modification d’image.

## Errata de la documentation embarquée dans le kit 1.20.4

Le kit et le tag restent immuables. Lire les trois passages suivants avec ces
précisions ; cette procédure fournit déjà les commandes corrigées :

| Passage embarqué | Précision applicable à la livraison 1.20.4 |
|---|---|
| `RESEAU-IMAGES-AGENTS.fr.md`, « D’où viennent les images ? » : mention de « kit final ed757ba », du registre Sandbox et d’observations du 8 octobre | Ces informations concernent un ancien candidat. La livraison actuelle contient cinq archives OCI ; `images.source.lock.json` et `provenance.json` identifient les images 1.20.4. Leur import local ne contacte pas le Sandbox. |
| Exemple `python3 enroll-agent.py` dans ce même guide | Depuis la racine du kit, employer `python3 scripts/qualification/enroll-agent.py`, comme à l’étape 5 ci-dessus. |
| `DEMARRER-ICI.fr.md` : « zéro alerte signalée » | Lire **zéro vulnérabilité signalée par les contrôles de publication**. RustSec conserve aussi des avertissements de maintenance, distincts des vulnérabilités ; le rapport brut reste la référence. Ne pas présenter la livraison comme dépourvue de tout avertissement ou de toute faille. |

Les preuves de la release décrivent les artefacts et les tests réalisés pour
la livraison. Le résultat de la recette exécutée chez le client doit être
conservé séparément avec les digests réellement installés.
