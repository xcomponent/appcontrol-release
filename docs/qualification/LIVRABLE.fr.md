# AppControl — kit d’évaluation OpenShift

> **Depuis Windows, commencer par le [parcours léger PowerShell + oc](INSTALLATION-WINDOWS.fr.md).** Cette page concerne le kit Linux/macOS avec archives OCI. Le parcours Windows léger utilise les images publiques d’évaluation téléchargées par le cluster, via le registre autorisé ; il n’exige aucun import d’images depuis le poste.

Version produit **1.21.1**. Consulter `VALIDATION.fr.md` et
`provenance.json` pour le commit, les digests, la date et les contrôles réellement
exécutés par la CI de cette release. Les rapports bruts sont dans `evidence/`.

Ce kit Linux AMD64 contient les cinq images OCI, les exécutables déjà compilés,
le frontend, les migrations, le chart Helm, les scripts, les rapports et les
SBOM. Sa version et ses sources exactes figurent dans `provenance.json`.
Il permet une évaluation isolée, sans compilation chez le client ni accès du
cluster à GitHub. Il ne contient aucun identifiant ou certificat privé du
Sandbox. Ce n’est pas une qualification de production bancaire.

**Toutes les commandes ci-dessous se lancent depuis la racine du kit extrait**,
où se trouvent `images-oci/`, `images.source.lock.json`, `SHA256SUMS` et `scripts/`.

## 1. Préparer le créneau avec l’équipe plateforme

- Projet OpenShift dédié, avec droits d’installation sur les ressources de ce
  projet. Les pods ne demandent ni cluster-admin ni SCC `anyuid`.
- Registre interne accessible aux nœuds, images approuvées, classe de stockage
  et 2 Gio persistants. Prévoir les quotas pour **quatre services** : interface,
  backend, gateway et PostgreSQL ; la recette ajoute un cinquième pod agent.
- Deux noms DNS vers le routeur : interface HTTPS et gateway WSS, port 443.
  La Route gateway doit accepter le passthrough TLS et les connexions WebSocket
  longues. Ces noms peuvent rester internes à la banque.
- Poste d’installation : **Python 3.9+, kubectl, Helm 3 et OpenSSL**.
  `kubectl` est obligatoire : les scripts l’appellent directement ; disposer
  uniquement de `oc` ne suffit pas. `oc` peut servir à obtenir le kubeconfig.
- Poste d’import : Skopeo, authentifié au registre selon la procédure bancaire.
  Installer les CA du registre et des Routes dans les magasins de confiance
  utilisés par ces outils et Python ; conserver la vérification TLS.
- Répertoire privé persistant, **hors du kit et hors Git**, pour les nouveaux
  identifiants et certificats de cette installation.

## 2. Vérifier et importer les images

Vérifier d’abord l’empreinte de l’archive reçue, puis les fichiers extraits :

```sh
sha256sum -c SHA256SUMS
# Sur macOS : shasum -a 256 -c SHA256SUMS
```

Examiner les scans datés et appliquer les contrôles/signatures du client.
Remplacer le préfixe de registre ci-dessous ; le tag d’import doit être réservé
à cette livraison et ne pas être réutilisé pour d’autres images.

```sh
python3 scripts/qualification/transfer-images.py import \
  --lock images.source.lock.json --archive-dir images-oci \
  --target-prefix registre.banque/appcontrol --version 1.21.1 \
  --output-lock images.lock.json --execute
```

Sans `--execute`, le script affiche le plan. Le mode import lit les archives
locales sans contacter le registre source de la release. Il vérifie la conservation
des digests et crée `images.lock.json` pour les quatre services, ainsi que
`images.lock.json.agent.txt` pour l’agent de recette. Aucun `docker load` ni
recompilation n’est nécessaire. Après reconditionnement sur une base bancaire,
il faut de nouveaux scans, digests et tests : les preuves des anciennes images
ne décrivent plus les nouvelles.

## 3. Configurer et installer

```sh
cp scripts/qualification/client.example.json client.json
```

Adapter `client.json` avec le kubeconfig, le contexte, le projet, le nom de release,
le dossier privé et les deux noms DNS. `image_lock` doit pointer vers le fichier
créé à l’étape précédente. Les chemins relatifs sont résolus depuis ce JSON ;
aucun mot de passe ne doit y figurer.

```sh
python3 scripts/qualification/install.py --config client.json --preflight-only
python3 scripts/qualification/install.py --config client.json
```

Ajouter `--image-pull-secret NOM` aux deux commandes pour un registre privé et
`--storage-class NOM` si nécessaire. Le secret de pull doit déjà exister dans le
projet. Le précontrôle ne modifie pas le cluster ; l’accès aux images, le stockage,
les SCC et les Routes restent à vérifier au déploiement et à la recette.

L’installateur fournit les quatre services, génère les secrets de cette
installation et vérifie la connexion réelle de la gateway. Il affiche les URL
et le chemin du certificat public des agents. Les identifiants administrateur
sont dans `credentials.json` du dossier privé : conserver ce dossier pour les
mises à jour, sans l’ajouter au paquet partageable.

## 4. Tester la première installation

**Cette recette est perturbatrice : elle exécute des commandes et redémarre
gateway, backend et PostgreSQL. La réserver à l’installation d’évaluation
isolée, sans application cliente en exploitation.**

Reprendre exactement les valeurs adaptées dans `client.json` pour les cinq
premiers paramètres ci-dessous. Les valeurs montrées correspondent au modèle
fourni. Le fichier agent contient la référence immuable créée par l’import.

```sh
python3 scripts/qualification/e2e.py \
  --kubeconfig /chemin/prive/kubeconfig \
  --context contexte-openshift-client \
  --namespace appcontrol-evaluation --release appcontrol \
  --state-dir /chemin/prive/appcontrol \
  --agent-image "$(cat images.lock.json.agent.txt)" \
  --openshift --evidence qualification-client.json
```

Le paramètre `--openshift` utilise les Routes réelles et vérifie l’admission SCC.
La recette crée une map de deux composants et un agent synthétique ; elle teste
l’authentification, les refus de permissions, l’ordre start/stop, la reconnexion
et la persistance. Attendre un résultat `PASS` et conserver le rapport.
Compléter par la connexion dans un navigateur et, si prévu dans le périmètre,
l’enrôlement d’un agent extérieur au cluster.

## 5. Démontrer le fonctionnement

1. Se connecter avec l’administrateur généré et ouvrir l’application indiquée
   dans le résultat JSON, nommée `Qualification dependencies …`.
2. Présenter la map : `api-probe` dépend de `database-probe`. Afficher les
   commandes des composants pour montrer les procédures définies par l’exploitation.
3. Démarrer : la dépendance doit démarrer avant son consommateur. Observer RUNNING.
4. Arrêter : le consommateur doit s’arrêter avant sa dépendance. Observer STOPPED
   et consulter l’historique des opérations.
5. Préciser que les commandes synthétiques s’exécutent réellement, sans IA et
   sans service bancaire. Une application cliente nécessite ses propres
   procédures validées.

L’agent de recette est jetable ; rejouer le test après suppression de son pod.
Il ne sert pas de modèle d’agent persistant pour l’exploitation.

## Agents extérieurs et limites

La gateway incluse suffit pour le premier agent extérieur. Celui-ci initie une
connexion WSS sortante sur 443, avec TLS/mTLS ; aucun port entrant AppControl
n’est nécessaire sur sa machine. Ses commandes métier peuvent exiger d’autres
flux. Le guide `docs/qualification/RESEAU-IMAGES-AGENTS.fr.md` décrit le jeton
agent à usage unique, le certificat public `agent-ca.crt`, le compte OS dédié,
le précontrôle et le service systemd.

La release fournit un binaire Linux AMD64 construit avec MUSL. Les besoins en
outils des commandes restent à vérifier sur la machine agent (shell, clients de
base, outils métier). Le test de l'agent conteneurisé n'est pas une qualification
de toutes les distributions de VM. Les recettes `docker/corporate/` permettent
de copier les artefacts dans une base approuvée ; rescanner et requalifier
l'image résultante.

Le backend reste unique, sans promesse de haute disponibilité ni de reprise
sûre d’une reconstruction destructive interrompue. SSO, PKI et base cliente,
sauvegarde/restauration et procédures d’exploitation demandent une recette
complémentaire. Les nouveaux certificats de service durent 90 jours et le jeton
gateway 30 jours ; leur renouvellement est explicite, leur réutilisation ne
repousse pas l’échéance.

Les scans datés du kit couvrent les images exactes et les dépendances de
production et de développement. La publication est bloquée s'ils signalent
une vulnérabilité. Cela ne garantit pas l'absence de faille : rescanner avant
une livraison ultérieure et après toute modification d'image.
