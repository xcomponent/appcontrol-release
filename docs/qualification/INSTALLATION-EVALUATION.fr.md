# Installation d'évaluation AppControl

> **Poste Windows ?** Utiliser le [parcours PowerShell + oc](INSTALLATION-WINDOWS.fr.md) : scripts et YAML seulement, téléchargement des images publiques d’évaluation par le cluster, via Artifactory ou GHCR. Aucun Python, Helm ni import d’images depuis le poste. Le même script dispose d’un mode de mise à jour explicite.
>
> **Cette page décrit le kit Linux/macOS original avec archives OCI et Helm.** Ses outils et commandes ne sont pas les prérequis du parcours Windows léger.

Pour le parcours court et le choix d’architecture, commencer par [Démarrer ici](DEMARRER-ICI.fr.md).

La version **1.21.1** prévoit un kit d'installation versionné.
Ses preuves exactes sont dans `VALIDATION.fr.md`, `provenance.json` et `evidence/`
du kit. La publication exige une recette OpenShift réelle et les scans des
images livrées ; les rapports datés d'anciens candidats sont des historiques.

L'installation comprend l'interface web, le backend, une gateway et PostgreSQL. Un agent supplémentaire exécute les commandes de la démonstration. Le backend est mono-instance ; prévoir une interruption pour les mises à jour.

Pour une banque imposant ses propres images, consulter les [principes d'installation](DEMARRER-ICI.fr.md). Les binaires peuvent être reconditionnés sur les bases approuvées ; les recettes sont dans `docker/corporate/`. Une image reconstruite doit être scannée et testée à nouveau.

## Prérequis

- Namespace dédié, droits de création Deployment/StatefulSet/Service/Secret/ConfigMap/NetworkPolicy/PVC et, sur OpenShift, Route. Aucun rôle cluster-admin ni SCC `anyuid` demandé par les composants.
  Le namespace/projet doit déjà exister ; `--create-namespace` permet sa création si l'installateur dispose de ce droit. Le mode local le crée automatiquement.
- Kubernetes/OpenShift accessible ; Python 3.9+, OpenSSL, Helm 3 et **kubectl**.
  `kubectl` est obligatoire : les scripts l'appellent directement. `oc` seul
  ne suffit pas, même s'il peut servir à obtenir le kubeconfig.
- Classe de stockage par défaut ; 2 Gio pour l'évaluation.
- Images correspondant à la même version, importées dans un registre accessible
  aux nœuds. Le kit fournit cinq archives OCI et `images.source.lock.json` ;
  Skopeo conserve leurs digests et produit le lock client. Suivre le
  [guide de livraison](LIVRABLE.fr.md) pour vérifier et importer le kit.
  Le cluster n'a besoin d'aucun accès à GitHub ; aucune compilation n'est requise.
- Confiance TLS configurée pour le registre et les Routes sur les postes
  d'import et de recette, y compris dans l'environnement Python employé.
- Un répertoire **privé hors du kit et hors Git** pour les identifiants et les certificats d'évaluation. Le conserver pour les mises à jour. Ne pas transmettre ce répertoire avec les sources ou les rapports.

## Installation guidée

Depuis la **racine du kit extrait**, après l'import des images :

```sh
cp scripts/qualification/client.example.json client.json
```

Renseigner les chemins, le contexte, le projet, le nom de release et les deux
Routes dans `client.json`. Conserver `image_lock` pointant vers `images.lock.json`
issu de l'import. Les chemins relatifs sont résolus depuis ce JSON ; il ne
contient aucun mot de passe. Voir le [guide réseau et agents](RESEAU-IMAGES-AGENTS.fr.md).

```sh
python3 scripts/qualification/install.py --config client.json --preflight-only
python3 scripts/qualification/install.py --config client.json
```

Le lock JSON associe les quatre clés
`backend`, `frontend`, `gateway`, `postgresql` aux références immuables
`registre/depot@sha256:...` validées par le client. Les noms de dépôt sont libres.
Ajouter aux deux commandes `--storage-class NOM` pour imposer la classe de stockage et
`--image-pull-secret NOM` pour utiliser un secret de registre existant.

La première commande vérifie les outils et droits sans installer.
Ce contrôle ne prouve pas encore l'accès aux images, l'admission SCC ou le bon
fonctionnement des Routes : ceux-ci sont vérifiés pendant la recette.

L'installateur crée les secrets, les certificats internes, les trois premiers services, l'administrateur initial, puis les certificats et le jeton de la gateway. La connexion navigateur→Route utilise le certificat du routeur ; Route→interface est réencryptée et les liens internes sont vérifiés. La gateway exige ensuite les certificats agents émis par la PKI AppControl. Les secrets ne sont pas passés dans les arguments des commandes.

Les identifiants sont dans `credentials.json` du répertoire privé. Pour un accès local, transférer le port de l'interface avec `kubectl port-forward` et faire confiance à `ca.crt` ; ne pas contourner la validation TLS avec `--insecure` dans la procédure cliente.

## Recette OpenShift de cette installation

**Recette perturbatrice, réservée au projet d'évaluation isolé :** elle crée
une application et un agent synthétiques, exécute des commandes et redémarre
gateway, backend et PostgreSQL. Ne pas l'exécuter sur une installation déjà
utilisée pour exploiter des applications clientes.

Reprendre exactement les valeurs adaptées dans `client.json` pour le kubeconfig,
le contexte, le projet, la release et le dossier privé. Exemple cohérent avec
le modèle fourni :

```sh
python3 scripts/qualification/e2e.py \
  --kubeconfig /chemin/prive/kubeconfig \
  --context contexte-openshift-client \
  --namespace appcontrol-evaluation --release appcontrol \
  --state-dir /chemin/prive/appcontrol \
  --agent-image "$(cat images.lock.json.agent.txt)" \
  --openshift --evidence qualification-client.json
```

Le fichier agent provient de l'import et contient son digest. `--openshift`
vérifie les Routes réelles et l'admission SCC, en plus de la connexion, des droits,
du start/stop et de la persistance. Conserver le rapport `PASS`, puis ouvrir la
map indiquée dans le résultat pour la démonstration manuelle du
[guide de livraison](LIVRABLE.fr.md).

## Exploitation de l'évaluation

- Jeton de gateway : 30 jours. Prévoir son renouvellement avant échéance ; il authentifie aussi les reconnexions. Aucun jeton à usage unique pour une gateway durable.
- Certificats de service : 90 jours. L'installateur réutilise les certificats existants ; leur renouvellement est une opération explicite avec redémarrage des composants concernés.
- CA de transport : un an ; sa clé privée reste dans le répertoire d'installation, pas dans les pods.
- Sauvegarder PostgreSQL et tester une restauration avant de dépendre des données. La persistance d'un PVC ne constitue pas une sauvegarde.
- Pour une base fournie par le client, utiliser le chart directement avec `postgresql.enabled=false`, `backend.database.existingSecret` et des CIDR `networkPolicy.externalDatabaseCIDRs` explicites. La chaîne de connexion doit vérifier le certificat de la base ; monter sa CA via le mécanisme TLS retenu.
- Registre privé : renseigner `global.imagePullSecrets` dans les valeurs Helm. PostgreSQL utilise aussi ces références.

## Critères avant livraison

Installation neuve, connexion utilisateur, enrôlement agent, commandes réelles start/stop dans le bon ordre, refus sans permissions, redémarrage gateway et persistance de la map ; scans datés des images exactes et SBOM ; admission sous SCC restricted et Route réencryptée sur OpenShift réel.

## Rejouer localement sans jeton Red Hat

Cette variante est destinée au développeur disposant du dépôt source complet.
Elle ne fait pas partie du parcours du kit binaire client, qui utilise les
archives OCI et les scripts d’installation/recette OpenShift fournis.

```sh
bash scripts/qualification/local.sh /chemin/prive/qualification-appcontrol
```

Le script télécharge une version vérifiée de k3d si nécessaire, construit les images Linux AMD64, crée uniquement son cluster `appcontrol-qualification`, importe les images, installe le produit, exécute le scénario fonctionnel puis produit les scans et SBOM. Il ne change pas le contexte Kubernetes habituel. Docker doit être démarré ; prévoir une première compilation longue, puis des reprises accélérées par les caches.

Ce mode utilise `--local-restricted` pour éprouver les permissions avec un UID
élevé. Ne pas employer cette option sur OpenShift : sa SCC attribue ces valeurs.

Seul le sous-répertoire `evidence` est destiné au partage. Le sous-répertoire `private` contient des clés et mots de passe. Le cluster et ses volumes sont conservés pour inspection ; leur suppression efface la base locale.

## Enrôler un agent extérieur au cluster

La Route de gateway est en passthrough : le certificat agent est vérifié par la gateway et ne doit pas être remplacé par un en-tête HTTP. Avec une CA interne, remettre uniquement son **certificat public** à l'installateur de l'agent et définir `ENROLLMENT_CA_FILE` avant l'enrôlement. Ne jamais distribuer la clé privée de la CA. L'interface d'enrôlement rappelle cette étape. Le mode de développement `ENROLLMENT_INSECURE=true` n'est pas une procédure d'installation cliente et est interdit lorsque `APP_ENV=production`.
