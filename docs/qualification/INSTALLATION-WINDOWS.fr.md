# Installer, mettre à jour et retirer AppControl sur OpenShift avec PowerShell et oc

**Le parcours Windows recommandé : la commande `oc` déjà installée, un petit
paquet de fichiers PowerShell et YAML, puis une seule commande de déploiement.**

OpenShift télécharge lui-même les images depuis le registre autorisé. Le paquet
léger ne contient **aucune image ni aucun exécutable**. Il n’installe pas `oc` et
ne modifie pas le PATH du poste. Aucun Helm, Docker, Python, WSL, OpenSSL ou outil
de transfert d’images n’est nécessaire sur le poste client.

Produit : **AppControl 1.21.1**. Paquet : **Windows léger 1.21.1-1**.

La version 1.21.1 ajoute le contrat de génération pour l'IA du client, la
publication de maps réparties sur plusieurs sites et l'attribution
d'applications aux équipes. Le choix mock dans le prompt produit une map
ordinaire, importée sur les agents choisis sans préparation de simulation
obligatoire. Le kit conserve l'installation, la mise à jour et le retrait
ciblés, la protection des fichiers locaux et les dépôts Artifactory séparés.

> La publication du kit est conditionnée au téléchargement anonyme des images et à la qualification du ZIP exact depuis Windows sur OpenShift. Télécharger avec le kit ses preuves de même révision, `PUBLICATION-EVALUATION-1.21.1-1.json` et `QUALIFICATION-EVALUATION-1.21.1-1.zip`, lorsqu'elles sont jointes à la release. Ce guide ne constitue pas un résultat de qualification ; les rapports 1.20.4 restent des historiques et ne valident pas la livraison 1.21.1.

## 1. Ce qui sera déployé

**Le script vous demande quel projet/namespace utiliser, puis quel mode PostgreSQL installer.** Les deux options utilisent les mêmes images AppControl et les mêmes scripts PowerShell.

| Choix au lancement | PostgreSQL intégré | PostgreSQL externe |
|---|---|---|
| Usage | Essai rapide dans un projet dédié | Base dédiée fournie et gérée par la banque |
| Base à préparer | Aucune : identifiants et connexion générés | Base dédiée et compte applicatif préparés par l'administrateur PostgreSQL ; seule la connexion applicative est fournie au script |
| Dans OpenShift | Un pod PostgreSQL et un volume persistant de 2 Gio | Aucun pod, Service, volume ni image PostgreSQL déployé par l’installateur |
| Services AppControl | Interface web, backend, gateway | Interface web, backend, gateway |
| Démonstration | Agent et map synthétique inclus | Agent et map synthétique inclus |
| Nombre de pods AppControl avec démonstration | **5** | **4**, la base externe est gérée séparément |
| Recette | Redémarre aussi le PostgreSQL de cette installation | Ne redémarre jamais la base externe |

L’interface présente les applications et les maps, le backend gère les droits et les opérations, la gateway relie les agents, et l’agent exécute les commandes fictives de la démonstration. PostgreSQL conserve les données AppControl.

```mermaid
flowchart LR
  W["Windows : PowerShell + oc existant"] -->|"appliquer les YAML"| O["API OpenShift — projet choisi"]
  R["Registre autorisé : Artifactory ou GHCR"] -->|"images tirées par les nœuds"| O
  subgraph P["Projet AppControl"]
    UI["Interface web"] --> B["Backend"]
    G["Gateway"] --> B
    A["Agent de démonstration"] --> G
    PG["PostgreSQL intégré — option 1"]
  end
  B -->|"option 1 : TLS"| PG
  B -->|"option 2 : TLS obligatoire"| EXT["PostgreSQL dédié de la banque"]
  N["Navigateur"] -->|"HTTPS"| UI
```

Une seule des deux bases est utilisée. Le script ne bascule pas une installation existante d’un mode à l’autre : une migration des données se prépare séparément. Aucun Redis, fournisseur IA ou serveur MCP n’est requis pour cette installation.

## 2. Les prérequis à obtenir une fois

| À préparer | Ce qu’il faut concrètement |
|---|---|
| Poste Windows | Windows PowerShell 5.1, .NET Framework 4.8 et le `oc` déjà installé et approuvé par la banque. Scripts autorisés en mode PowerShell `FullLanguage`. |
| Connexion | Une connexion `oc` fonctionnelle au cluster du client, selon sa procédure habituelle. |
| Projet / namespace | Un projet existant fourni par la banque, de préférence dédié, avec les droits de déploiement. Il sera sélectionné dans le script ou fourni avec `-Projet` / `-Namespace`. Il n’est pas nécessaire d’avoir le droit de créer ou supprimer un projet. |
| Stockage | Uniquement pour PostgreSQL intégré : StorageClass utilisable et volume `ReadWriteOnce` de 2 Gio. En mode externe, aucun volume PostgreSQL n’est demandé. |
| Quotas | Nœuds Linux AMD64. Avec la démonstration : 1,15 vCPU et 992 Mio réservés en mode intégré ; 0,90 vCPU et 736 Mio côté AppControl en mode externe, hors base bancaire. Accepter aussi les limites des YAML et une marge pour les redémarrages. |
| Registre | Images accessibles par les nœuds, via Artifactory ou GHCR ; secret de lecture dans le projet si nécessaire. Cinq images avec PostgreSQL intégré ; quatre avec la base externe et la démonstration. |
| Réseau et certificats | Poste → API OpenShift et Route web HTTPS ; nœuds → registre ; échanges internes des services ; agent → Route gateway WSS 443. Les certificats des endpoints doivent être approuvés. |
| Tunnel d’installation | `oc port-forward` autorisé vers le projet : droit `create` sur `pods/portforward` et passage du tunnel par les éventuels proxies réseau. Pas de port entrant supplémentaire sur Windows. |

Le script ne crée pas le projet ni les accès au registre. Il ne requiert pas de
compte administrateur Windows, de droit `cluster-admin` ni de SCC `anyuid`.
Un projet dédié sépare les objets et les données ; il ne réserve pas à lui seul
des nœuds physiques.

Si la banque fournit un projet partagé, choisir un nom d’installation distinct
avec `-Nom`, par exemple `-Nom appcontrol-poc`. Le désinstallateur décrit plus
bas retire les ressources de cette installation sans supprimer le projet ni
les autres applications. Il faut disposer des droits de suppression sur ces
ressources dans le projet ; aucun droit de suppression du projet n’est demandé.

## 3. Où sont les images et comment passe-t-on par Artifactory ?

Le [dépôt public de livraison XComponent](https://github.com/xcomponent/appcontrol-release/releases)
fournit les scripts, les YAML et les rapports. Le **canal public d’évaluation**
utilise cinq packages dédiés dans GitHub Container Registry, **GHCR** :

```text
ghcr.io/xcomponent/appcontrol-eval-backend
ghcr.io/xcomponent/appcontrol-eval-frontend
ghcr.io/xcomponent/appcontrol-eval-gateway
ghcr.io/xcomponent/appcontrol-eval-postgresql
ghcr.io/xcomponent/appcontrol-eval-agent
```

**PostgreSQL est également publié sur GHCR** :
[package public `appcontrol-eval-postgresql`](https://github.com/orgs/xcomponent/packages/container/package/appcontrol-eval-postgresql).
Les images se trouvent dans la rubrique **Packages**, tandis que les scripts
et les rapports se trouvent dans **Releases**. Le kit utilise cette image
PostgreSQL XComponent préparée pour OpenShift ; une image `postgres` standard
ou une image bancaire différente ne la remplace pas automatiquement.

Ces images d’évaluation sont destinées au **téléchargement anonyme** : aucun
compte GitHub, mot de passe ou jeton GHCR à fournir sur le poste client, dans
OpenShift ou dans la connexion amont d’Artifactory. Les packages historiques
`appcontrol-backend`, `appcontrol-frontend`, etc. restent privés : le nouveau
parcours emploie bien les noms **`appcontrol-eval-*`**. Le dépôt de code source
n’est pas rendu public par cette distribution.

Le fichier `images.lock.json` du kit fixe les références et leurs empreintes
SHA-256. Le script utilise ces empreintes, pas un tag `latest` susceptible de
changer. Les versions suivantes du POC empruntent **le même canal** : la chaîne
XComponent publie les images validées avec un nouveau numéro de version et
produit le kit correspondant. Les copies conservent les digests ; elles ne
nécessitent pas une deuxième compilation ni une manipulation chez le client.

### Cas A — le cluster peut télécharger directement depuis GHCR

Lancer le script avec ses références par défaut. **Omettre `-Registre` et
`-SecretImages`.** Les nœuds OpenShift doivent pouvoir joindre GHCR et faire
confiance à ses certificats. C’est le cluster qui télécharge les images, pas
le poste Windows.

### Cas B — la banque impose Artifactory

```mermaid
flowchart LR
  O["OpenShift"] -->|"lecture selon les droits de la banque"| A["Artifactory de la banque"]
  A -->|"téléchargement anonyme des images d’évaluation"| G["GHCR XComponent : appcontrol-eval-*"]
```

L’équipe plateforme prépare un **dépôt Docker distant vers GHCR**, éventuellement
exposé par un dépôt virtuel. Elle autorise les cinq noms `appcontrol-eval-*` et
fournit l’adresse Docker de lecture indiquée par « Set Me Up ». Ce n’est pas
l’adresse de l’interface web Artifactory. Si les anciens noms privés étaient
seuls autorisés, demander l’ajout des nouveaux noms avant le créneau.

| Qui prépare | À faire une fois | Ce que vous récupérez pour installer |
|---|---|---|
| Équipe Artifactory | Autoriser les packages publics `appcontrol-eval-*` et leur téléchargement par digest ; aucun compte GitHub amont nécessaire | Le préfixe Docker des images d’évaluation |
| Équipe OpenShift/Artifactory | Autoriser les nœuds à lire dans le registre interne | Si nécessaire, le nom d’un secret de lecture déjà créé dans votre projet |
| Vous, avec les droits de déploiement du projet | Lancer le script avec ces valeurs | L’URL AppControl et la démonstration |

**Les deux paramètres à ne pas confondre :**

- `-Registre` = **adresse du registre Docker + chemin avant le nom de l’image**, sans `https://`. Si l’image est `artifactory.intra.example/docker-ghcr/xcomponent/appcontrol-eval-backend@sha256:…`, le paramètre est `artifactory.intra.example/docker-ghcr/xcomponent`. Le script conserve le nom `appcontrol-eval-backend`, et de même pour les autres composants.
- `-SecretImages` = **nom d’un Secret OpenShift existant dans le projet cible**, contenant les identifiants de lecture **Artifactory**. Si la plateforme l’a nommé `artifactory-pull`, utiliser `-SecretImages 'artifactory-pull'`. Ce n’est ni le mot de passe, ni le jeton, ni un fichier à fournir sur Windows.

Les valeurs `registry.banque.example/ghcr/xcomponent` et `lecture-artifactory`
utilisées dans les exemples sont fictives. Le script ne crée pas ce secret.
Si l’accès Artifactory est déjà assuré par la plateforme ou si la lecture est
anonyme, **omettre `-SecretImages`** après confirmation de l’équipe plateforme.
L’accès amont public à GHCR ne rend pas automatiquement Artifactory public.

Une seule demande de préparation suffit : **projet cible, préfixe exact des
images `appcontrol-eval-*` dans Artifactory (et celui de PostgreSQL s’il est
différent), nom éventuel du secret de lecture, et confirmation que les nœuds peuvent tirer ces images par digest.** Les mêmes
paramètres sont réutilisés pour les versions suivantes. La banque peut garder
une étape d’approbation et de scan pour chaque nouvelle version.

Le cache Artifactory se remplit à la demande. La plateforme peut aussi précharger
les images ou utiliser un miroir interne, en conservant leurs digests. Il n’y
a aucun Docker, transfert d’images ou accès d’administration Artifactory à
installer sur le poste Windows.

Références : [accès anonyme aux images publiques GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry),
[dépôts Docker JFrog](https://docs.jfrog.com/artifactory/docs/docker-repositories),
[cache distant JFrog](https://docs.jfrog.com/artifactory/docs/remote-repositories).

### Cas C — deux dépôts Artifactory distincts

Si les quatre images AppControl et l’image PostgreSQL XComponent sont exposées
par deux dépôts différents, fournir les deux préfixes Docker :

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-evaluation -ModePostgreSQL Integre `
  -Registre 'artifactory.banque.example/appcontrol/xcomponent' `
  -RegistrePostgreSQL 'artifactory.banque.example/bases/xcomponent' `
  -SecretImages 'lecture-artifactory'
```

Ces adresses sont **des exemples à remplacer par les chemins fournis par la
plateforme**, sans `https://` ni nom d’image. Le script construira notamment :

```text
artifactory.banque.example/appcontrol/xcomponent/appcontrol-eval-backend@sha256:…
artifactory.banque.example/bases/xcomponent/appcontrol-eval-postgresql@sha256:…
```

`-RegistrePostgreSQL` ne change que le chemin d’accès de PostgreSQL. Il conserve
le nom `appcontrol-eval-postgresql` et l’empreinte de l’image qualifiée. Les
autres images utilisent `-Registre`. **Ne pas modifier `images.lock.json`.**
Sans ce paramètre, PostgreSQL utilise le même préfixe que les autres images.

Le secret éventuel doit permettre la lecture des **deux dépôts**. Si la
plateforme assure déjà cet accès, omettre `-SecretImages`. Les deux préfixes
sont enregistrés pour les relances. Pour les modifier après installation,
utiliser le parcours `-MettreAJour`, après sauvegarde, en précisant le préfixe
à changer.

Cette option concerne uniquement **PostgreSQL intégré**. Elle est refusée en
mode externe, qui ne déploie aucune image de base. Si le second dépôt contient
une image PostgreSQL standard ou propre à la banque, faire qualifier sa
compatibilité séparément, ou utiliser une base déjà exploitée par la banque
avec `-ModePostgreSQL Externe` et sa chaîne de connexion.


## 4. Télécharger les petits fichiers de déploiement

- [Paquet Windows léger 1.21.1-1 — scripts et YAML](https://github.com/xcomponent/appcontrol-release/releases/download/v1.21.1/appcontrol-openshift-windows-light-1.21.1-1.zip)
- [Empreinte SHA-256](https://github.com/xcomponent/appcontrol-release/releases/download/v1.21.1/appcontrol-openshift-windows-light-1.21.1-1.zip.sha256)

Le ZIP est uniquement un moyen pratique de transporter les fichiers texte.
Après téléchargement ou transfert approuvé, vérifier l’archive dans PowerShell :

```powershell
$archive = 'appcontrol-openshift-windows-light-1.21.1-1.zip'
$attendu = ((Get-Content "$archive.sha256" -Raw).Trim() -split '\s+')[0]
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne $attendu) {
    throw 'Empreinte incorrecte : ne pas utiliser cette archive.'
}
```

Utiliser **Extraire tout** dans l’Explorateur. Ouvrir le dossier contenant
`Deployer-AppControl.ps1`, taper `powershell` dans la barre d’adresse, puis Entrée.
Le dossier `manifests` contient le YAML OpenShift consultable avant installation.
Les autres fichiers PowerShell sont les fonctions utilisées par le script ;
ce ne sont pas des logiciels supplémentaires à installer.

## 5. Lancer et choisir le projet et PostgreSQL

Vérifier la connexion habituelle :

```powershell
oc whoami
```

Le projet doit déjà exister. Si sa création vous est autorisée, vous pouvez d’abord utiliser `oc new-project appcontrol-evaluation` selon la procédure de la plateforme.

**Avec un accès direct à GHCR autorisé**, lancer simplement :

```powershell
.\Deployer-AppControl.ps1
```

**Avec Artifactory**, renseigner seulement l’adresse Docker et le secret de lecture fournis par la plateforme, puis laisser le script guider les choix :

```powershell
.\Deployer-AppControl.ps1 `
  -Registre 'registry.banque.example/ghcr/xcomponent' `
  -SecretImages 'lecture-artifactory'
```

Ces deux valeurs sont des exemples à remplacer. Si la plateforme confirme que l’accès au registre interne est déjà assuré, omettre `-SecretImages`. Le canal public GHCR par défaut ne demande aucun secret GitHub.

Le script présente successivement :

1. Le **serveur OpenShift** de votre connexion et les projets accessibles. Saisir un numéro ou le nom du projet cible. Si la liste n’est pas autorisée, saisir le nom fourni par la plateforme.
2. Le choix **1 — PostgreSQL intégré** ou **2 — PostgreSQL externe**.
3. Pour une base externe, le choix TLS : **1 — vérifier le certificat** (défaut) ou **2 — ignorer sa validation**, puis les informations de connexion. Le chiffrement reste obligatoire dans les deux cas.
4. Un récapitulatif du serveur, du contexte, du **projet/namespace cible**, du registre et du mode de base. Taper **OUI** pour autoriser le déploiement dans ce projet.

Le namespace n’est jamais déduit silencieusement du projet courant. Le script utilise `-n` pour cibler les objets et une copie privée de la connexion ; il ne change pas le projet par défaut de votre configuration `oc`. Il ne crée pas implicitement de projet et refuse les conflits avec une installation existante.

### Choix 1 : PostgreSQL intégré

Aucune chaîne de connexion à fournir. Le script prépare la base, les identifiants, les certificats et le stockage. Pour prédéfinir ces deux choix :

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-evaluation -ModePostgreSQL Integre `
  -Registre 'registry.banque.example/ghcr/xcomponent' `
  -SecretImages 'lecture-artifactory'
```

Ajouter `-ClasseStockage 'nom-fourni-par-la-plateforme'` uniquement si la classe par défaut ne convient pas. Cette option concerne uniquement la base intégrée.

### Choix 2 : PostgreSQL externe fourni par la banque

Avant le créneau, demander à l’équipe base de données et à la plateforme :

- **Une base dédiée et un compte applicatif préparés à l'avance par l'administrateur PostgreSQL.** Le compte doit pouvoir créer et modifier les objets du schéma AppControl. Le script ne crée ni instance, ni base, ni comptes PostgreSQL sur le serveur bancaire. Ne pas utiliser une base métier existante.
- **La chaîne de connexion du seul compte applicatif au format URI**, par exemple `postgresql://utilisateur:mot-de-passe@postgres.banque.example:5432/appcontrol?sslmode=verify-full`. Ce n’est pas une chaîne ADO.NET `Host=...;Username=...`. Les caractères réservés du nom d’utilisateur et du mot de passe doivent être encodés dans l’URI. Ne pas fournir les identifiants de l'administrateur PostgreSQL au script.
- **Pour le mode TLS par défaut, le certificat public de l’autorité de certification de PostgreSQL, au format PEM**. Une autorité interne autosignée convient. Le nom DNS de l’URI doit correspondre au certificat du serveur. Le mode par défaut utilise `verify-full`. Le mode de compatibilité ci-dessous ne demande pas de fichier CA.
- **Les adresses ou plages CIDR approuvées de la base**, par exemple `10.20.30.40/32`, ainsi que son port. Elles limitent la sortie réseau du backend. Les ouvertures générales `0.0.0.0/0` et `::/0` sont refusées. Une règle réseau ou un pare-feu bancaire peut aussi nécessiter une autorisation par la plateforme.

PostgreSQL 16 est la version de référence de cette livraison. Il y a deux
rôles distincts dans la préparation : l'administrateur de la base crée les
objets d'accueil, puis AppControl se connecte avec le compte applicatif.
L'installateur ne gère pas deux comptes automatiquement et ne reçoit qu'une
chaîne de connexion.

Le même compte applicatif sert au fonctionnement et aux migrations exécutées
par le backend au démarrage, y compris lors des mises à jour. Il lui faut des
droits DDL pour créer et modifier les objets du schéma ; de simples droits
lecture/écriture ne suffisent pas. Le profil de référence utilise le compte
applicatif propriétaire de sa base dédiée, sans `SUPERUSER`, `CREATEDB` ni
`CREATEROLE`. L'administrateur PostgreSQL doit valider les droits équivalents
si la banque impose une autre organisation des rôles ou des schémas.

Lancer le script avec le mode externe ; il demandera les informations manquantes :

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-evaluation -ModePostgreSQL Externe `
  -Registre 'registry.banque.example/ghcr/xcomponent' `
  -SecretImages 'lecture-artifactory'
```

La saisie de la chaîne de connexion est **masquée**. Elle n’apparaît ni dans l’historique PowerShell, ni dans les YAML livrés, ni dans le récapitulatif. Elle est conservée dans le dossier privé de reprise, puis transmise à un Secret OpenShift. Ce dossier contient des secrets lisibles par votre compte Windows et le système : ne pas le partager. Les administrateurs autorisés du cluster peuvent accéder aux Secrets selon les droits de la banque.

On peut préparer les valeurs non secrètes avec `-CertificatPostgreSQL 'C:\Certificats\ca-postgres.pem'` et `-CidrPostgreSQL @('10.20.30.40/32','10.20.30.41/32')`. Pour une automatisation, `-ChaineConnexion` attend un objet `SecureString`, obtenu par exemple avec `Read-Host -AsSecureString` ; ne pas écrire un mot de passe en clair dans la commande. `-NonInteractif` exige le projet et le mode explicites à la première installation.

### Option : ignorer la validation du certificat PostgreSQL

**Disponible depuis le paquet léger 1.20.4-3.** C’est l’équivalent d’une option HTTPS qui accepte un certificat non reconnu. Elle est désactivée par défaut et concerne uniquement la connexion du backend à **PostgreSQL externe**.

Ajouter `-IgnorerCertificatPostgreSQL` dès la première installation :

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-evaluation -ModePostgreSQL Externe `
  -Registre 'registry.banque.example/ghcr/xcomponent' `
  -SecretImages 'lecture-artifactory' `
  -IgnorerCertificatPostgreSQL
```

Remplacer les deux valeurs de registre et de secret par celles de la plateforme. Sans option en ligne de commande, l’assistant interactif propose aussi ce choix lors d’une nouvelle installation externe si aucun fichier CA n’a été fourni. Entrée conserve le mode avec vérification.

Dans ce mode :

- **La connexion reste chiffrée en TLS** (`sslmode=require`). Un serveur PostgreSQL sans TLS est refusé ; il n’existe aucun repli en clair.
- **Le certificat et le nom du serveur ne sont plus vérifiés** : un certificat serveur autosigné ou non reconnu ne bloque plus la connexion. L’identité du serveur n’est donc plus garantie par TLS.
- **Aucun fichier CA n’est demandé ni monté.** Ne pas fournir `-CertificatPostgreSQL` en même temps ; le script refuse ce mélange.
- Les identifiants PostgreSQL, les droits sur la base et les restrictions réseau restent nécessaires. L’option ne contourne pas une erreur de mot de passe, de pare-feu ou d’accès aux images.
- Les certificats de l’API OpenShift, d’Artifactory/GHCR, de l’interface et des échanges gateway/agents restent vérifiés selon leur configuration habituelle.

Le script affiche ce choix avant déploiement et dans les rapports. La chaîne saisie peut omettre `sslmode` : l’assistant impose le mode choisi. Saisir simplement `sslmode=require` dans une URI **sans choisir l’option** ne désactive pas la vérification. `disable`, `allow`, `prefer` et `verify-ca` ne sont pas acceptés dans ce parcours.

Le choix est enregistré pour la reprise ; la commande de reprise affichée rappelle l’option lorsqu’elle est active. Comme pour la base et la CA, une installation existante ne change pas implicitement de politique TLS : un choix différent est refusé et demande une procédure de modification préparée. Les dossiers issus du paquet 1.20.4-2 restent interprétés comme `verify-full`.

Une fois connecté, AppControl gère son schéma et ses données. **Il ne déploie pas d’image PostgreSQL, ne crée aucun volume de base et ne redémarre pas le serveur externe.** La sauvegarde, l’exploitation et la disponibilité de cette base restent gérées selon la procédure de la banque.

### Ce que fait le déploiement

Le script vérifie les droits OpenShift et les fichiers, prépare les secrets et les certificats, traite le Template YAML avec `oc process`, puis applique les objets avec `oc apply`. Le profil externe retire les objets PostgreSQL et adapte la sortie réseau du backend avant application. Les nœuds OpenShift téléchargent les seules images nécessaires depuis le registre autorisé. La validation préalable de l'URI ne teste pas la connexion PostgreSQL ni les droits DDL : ceux-ci sont exercés au démarrage du backend et lors de ses migrations.

Le script attend ensuite les services, enregistre la gateway, puis crée l’agent et la map synthétique. La recette redémarre les services AppControl pour vérifier la reconnexion et la conservation des données. PostgreSQL est redémarré uniquement en mode intégré, dans le projet d’évaluation. Ajouter `-SansDemo` pour installer les services seuls : quatre pods en mode intégré, trois en mode externe.

## 6. Ouvrir et tester AppControl

Le script affiche l’URL de l’interface et le chemin privé des identifiants
administrateur. Le dossier d’état se trouve par défaut sous
`%LOCALAPPDATA%\AppControl\Installations`, avec des droits limités à l’utilisateur
Windows et au système. Ne pas envoyer ce dossier avec un rapport.

Dans le navigateur, ouvrir l’application **Qualification dependencies…**
indiquée par la recette. Elle comporte deux composants synthétiques :

| Action | Ce que l’on constate |
|---|---|
| **Start All** | `database-probe` démarre, puis `api-probe` ; les deux passent au vert. |
| **Stop All** | L’API s’arrête d’abord, puis sa dépendance. |
| Historique | Les commandes exécutées et leurs résultats sont visibles. |

Les commandes sont des `touch`, `test -f` et `rm` sur des marqueurs dans `/tmp`
du pod agent. Le démarrage de `api-probe` vérifie le marqueur de `database-probe`.
**Ce ne sont ni la vraie base PostgreSQL d’AppControl ni des services de la banque.**
Aucune commande métier n’est exécutée sur le poste Windows.

Les pods AppControl et la map restent disponibles après fermeture de PowerShell.
L’agent de qualification est temporaire : son identité est conservée tant que
son pod existe. Après remplacement de ce pod, relancer la recette crée un
nouvel agent et une nouvelle map ; utiliser la nouvelle map indiquée. Un agent
durable doit conserver son dossier d’identité sur un stockage persistant.

## Mettre à jour le POC

La première installation et les versions suivantes utilisent **le même script
PowerShell**. Chaque livraison apporte un nouveau kit et son `images.lock.json` ;
il n’y a ni image à transporter sur le poste, ni compte GitHub à créer.

1. Télécharger le **nouveau kit** depuis les releases XComponent, vérifier son empreinte et l’extraire dans un nouveau dossier. Conserver le dossier privé de l’installation existante.
2. Faire approuver les nouvelles images dans le registre bancaire si sa politique l’exige.
3. **Sauvegarder PostgreSQL avant la mise à jour** et disposer d’une procédure de restauration. Pour une base externe, obtenir la confirmation de l’équipe base de données. Pour la base intégrée, appliquer la procédure de sauvegarde retenue pour le POC. Le script ne crée pas cette sauvegarde et un PVC n’en tient pas lieu.
4. Réserver une interruption des services AppControl, puis lancer depuis le nouveau kit :

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-evaluation -MettreAJour
```

Reprendre le même `-Nom` si l’installation initiale utilisait un nom personnalisé,
et le même `-DossierEtat` si vous aviez choisi un autre emplacement. Le script
retrouve les paramètres enregistrés : registre AppControl, éventuel registre
PostgreSQL distinct, éventuel secret d’images,
mode PostgreSQL, connexion et politique TLS. L’assistant demande confirmation
que la sauvegarde a été réalisée avant d’appliquer la mise à jour.

Pour passer d’une ancienne installation utilisant directement le miroir privé
à la distribution publique XComponent, préciser le nouveau registre :

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-evaluation `
  -MettreAJour -Registre 'ghcr.io/xcomponent'
```

Avec Artifactory, conserver le préfixe interne approuvé et faire autoriser les
nouveaux noms `appcontrol-eval-*`. Un ancien secret de lecture est conservé :
l’agent déjà installé peut encore utiliser son image privée. Le passage au
canal public ne révoque pas automatiquement ces accès existants.

Pour un lancement non interactif, après avoir réellement effectué la sauvegarde :

```powershell
.\Deployer-AppControl.ps1 -Projet appcontrol-evaluation `
  -MettreAJour -SauvegardeConfirmee -NonInteractif
```

`-SauvegardeConfirmee` est une **attestation de l’opérateur**, pas une commande de
sauvegarde. L’installation garde son projet, son stockage, ses identifiants et
ses certificats. Le backend applique les migrations de sa version au démarrage.
Changer de base, de mode PostgreSQL ou de politique TLS reste une opération
séparée, refusée implicitement par ce parcours.

La mise à jour concerne les services de contrôle **backend, interface web et
gateway**, ainsi que l’image PostgreSQL lorsque la base est intégrée. Elle
**ne rejoue pas la démonstration** : les maps et l’agent existants sont conservés.
Elle vérifie les identifiants des applications et agents, une empreinte de la
configuration des maps (commandes, dépendances et paramètres), ainsi que la
reconnexion des agents qui étaient connectés avant l’opération.

Les agents existants, dans le cluster ou sur des machines externes, ne sont
**ni réenrôlés, ni redémarrés, ni mis à jour automatiquement** par ce parcours.
Leur version reste inchangée. Une mise à jour d’agent se prépare séparément,
avec conservation de son identité et vérification de sa compatibilité avec
la nouvelle version des services. L’image agent du nouveau kit sert aux
nouvelles démonstrations ; elle ne remplace pas silencieusement un agent en cours.

Le changement des images exige `-MettreAJour` ; une simple reprise ne le déclenche
jamais. Le script ne met pas automatiquement le POC sur la dernière version
publiée : vous choisissez et validez le kit à déployer. Il ne réalise pas de
retour arrière automatique de PostgreSQL après une migration.

Le journal privé `update.json` distingue une mise à jour complète d’une opération
incomplète. En cas d’échec, les anciennes références restent conservées pour le
diagnostic ; cela **ne signifie pas que les anciens pods ou l’ancienne base ont
été restaurés**. Le script bloque la reprise normale et demande de relancer
**le même kit cible avec `-MettreAJour`** pour terminer. Garder le dossier privé
et la sauvegarde PostgreSQL ; ne pas modifier les verrous à la main.

## Retirer AppControl sans supprimer le projet

**Ce parcours convient au projet fourni par la banque : il ne nécessite ni
création ni suppression de projet.** Ne pas utiliser `oc delete project` pour
retirer AppControl d’un projet partagé.

Depuis le kit, commencer par afficher les ressources concernées, sans rien
modifier :

```powershell
.\Desinstaller-AppControl.ps1 -Projet 'projet-fourni' -Verifier
```

Puis lancer la désinstallation avec confirmation du récapitulatif :

```powershell
.\Desinstaller-AppControl.ps1 -Projet 'projet-fourni'
```

L’assistant affiche le plan puis demande de saisir le **nom exact de
l’installation** pour confirmer. `-Verifier` ne modifie ni le cluster ni les
fichiers locaux.

Remplacer `projet-fourni` par le namespace utilisé à l’installation. Reprendre
le même `-Nom` si vous aviez choisi un nom personnalisé, ainsi que le même
`-DossierEtat` si vous aviez changé son emplacement. Le dossier privé d’origine
permet de vérifier que la commande vise la bonne installation et le bon cluster.

| Avec la commande par défaut | Résultat |
|---|---|
| Services AppControl et agent de démonstration du cluster | Arrêtés et retirés, avec leurs Routes, Services et règles réseau propres à cette installation |
| PostgreSQL intégré | Pod retiré ; volume de données conservé |
| Secrets et ConfigMaps de cette installation | Conservés pour garder identifiants, certificats et configuration |
| PostgreSQL externe | Base et données inchangées |
| Projet, autres applications, secret de lecture Artifactory fourni par la plateforme | Inchangés |
| Dossier privé sur Windows | Conservé |

La commande cible les objets identifiés comme appartenant à l’installation
native AppControl. Elle ne supprime pas les autres objets du projet, les agents
installés sur des machines externes, ni une installation Helm. En cas de conflit
de propriétaire ou de droit manquant, elle s’arrête avec un diagnostic.

Pour remettre les services après ce retrait avec conservation des données,
relancer `Deployer-AppControl.ps1` avec le même kit, le même projet, le même nom
et le dossier privé conservé. Les données et maps restent dans PostgreSQL.
L’agent de démonstration, en revanche, perd son identité temporaire avec son
pod : une nouvelle recette crée un nouvel agent et une nouvelle map. Ajouter
`-SansDemo` si vous souhaitez seulement remettre les services, sans créer une
nouvelle démonstration.

### Supprimer aussi les données de l’évaluation

**Cette option peut détruire les données PostgreSQL intégrées.** Faire une
sauvegarde avant de l’utiliser si les maps ou les configurations doivent être
conservées. Un volume persistant n’est pas une sauvegarde.

```powershell
.\Desinstaller-AppControl.ps1 -Projet 'projet-fourni' -SupprimerDonnees
```

L’assistant demande de saisir `SAUVEGARDE` pour attester la sauvegarde ou
l’acceptation de la perte des données, puis le nom exact de l’installation.
Pour une exécution non interactive, ces confirmations doivent être explicites :

```powershell
.\Desinstaller-AppControl.ps1 -Projet 'projet-fourni' `
  -SupprimerDonnees -SauvegardeConfirmee -NonInteractif
```

`-SauvegardeConfirmee` ne réalise aucune sauvegarde.

L’option ajoute à la suppression les volumes, Secrets et ConfigMaps appartenant
à cette installation AppControl. Le projet et le secret d’images de la
plateforme restent conservés. **Elle ne supprime jamais une base PostgreSQL
externe** : son nettoyage relève de l’équipe base de données. Le dossier privé
sur Windows n’est pas effacé automatiquement.

Après cette suppression complète, le dossier privé est marqué comme
désinstallé pour éviter de réutiliser par erreur ses anciens identifiants.
L’archiver dans un emplacement protégé. Pour une nouvelle installation,
choisir un **nouveau** `-DossierEtat` ; le même nom d’installation peut être
repris une fois les anciennes ressources effectivement retirées. Avec une
base externe, prévoir aussi une nouvelle base dédiée ou un nettoyage validé
par son administrateur : le désinstallateur ne l’a pas vidée.

## Reprendre et diagnostiquer

**Reprendre la même version, hors mise à jour incomplète**, ne nécessite pas
`-MettreAJour`. Conserver le dossier privé, le même kit, les mêmes projet et nom
et reprendre avec la commande indiquée par le script. Pour reprendre les
services en conservant la démonstration existante, ajouter `-SansDemo`. Sans
cette option, la recette peut créer une nouvelle démonstration.

Le script refuse d’écraser une installation Helm ou des objets qui ne lui
appartiennent pas. Ne pas supprimer le dossier privé pour contourner un refus.

Si une première installation a été bloquée par `SeSecurityPrivilege`, extraire
le nouveau kit dans un autre dossier et y relancer la même commande, avec le
même projet, le même nom et, si vous en aviez fourni un, le même `-DossierEtat`.
Le correctif protège les fichiers locaux et reprend la préparation avec les
paramètres conservés. **Ne pas ajouter `-MettreAJour` pour débloquer cette
première installation** ; cette option sert à changer une installation déjà
déployée. Ne pas supprimer son dossier d’état.

| Symptôme | Vérification |
|---|---|
| `oc` absent ou connexion expirée | Utiliser le CLI approuvé du poste et renouveler la connexion habituelle. Le script n’installe pas un autre CLI. |
| Script bloqué par Windows | Faire approuver les fichiers par l’équipe poste de travail ; ne pas désactiver la politique d’exécution. |
| `SeSecurityPrivilege` dans `Windows-Common.ps1` / `Set-Acl` | Utiliser le kit léger 1.20.4-5 ou ultérieur. Ce correctif protège les fichiers locaux sans demander le privilège d’audit Windows. Conserver le dossier d’état et les paramètres de l’installation ; ne pas relancer en administrateur ni retirer la protection des fichiers pour contourner cette erreur. |
| Secret d’images absent | Pour Artifactory privé, faire créer le secret dans le bon projet. Le canal public GHCR `appcontrol-eval-*` n’en demande pas. |
| `ImagePullBackOff` | Chemin `appcontrol-eval-*`, droits OpenShift → registre interne, accès amont Artifactory → GHCR et confiance TLS des nœuds. Si PostgreSQL utilise un dépôt distinct, vérifier aussi `-RegistrePostgreSQL` et les droits sur ce dépôt. |
| Changement d’images refusé en reprise | Utiliser le nouveau kit avec `-MettreAJour`, après sauvegarde PostgreSQL ; ne pas modifier manuellement les verrous. |
| Mise à jour interrompue ou incomplète | Garder le dossier privé et relancer le même kit cible avec `-MettreAJour`. Le journal `update.json` signale l’opération incomplète ; aucun retour arrière de la base n’est réalisé. |
| Volume `Pending` en mode intégré | StorageClass, capacité et quota du projet. |
| Backend indisponible en mode externe | URI et droits applicatifs, correspondance DNS/certificat, CA PEM, destinations CIDR et autorisations réseau de la banque. Ne pas désactiver TLS pour contourner une erreur. |
| Tunnel d’installation refusé | Droit `pods/portforward` et passage du tunnel par le proxy vers l’API. |
| Ressource existante refusée | Vérifier le projet et le nom choisis ; reprendre avec le dossier privé d’origine, sans forcer l’écrasement. |

## Qualification et suite du POC

Pour 1.21.1, consulter les preuves portant exactement la version du kit
`1.21.1-1`, ses empreintes d'images et son commit de livraison. Leur publication
intervient après les contrôles de la chaîne de release. Les rapports ci-dessous
décrivent les versions précédentes ; ils ne qualifient pas les nouveautés de
1.21.1.

**Historique :** le [rapport des trois parcours du paquet 1.20.4-3](https://github.com/xcomponent/appcontrol-release/releases/download/v1.20.4/QUALIFICATION-WINDOWS-OC-v1.20.4-3.fr.md) décrit les tests avec PostgreSQL intégré, PostgreSQL externe avec vérification du certificat, et PostgreSQL externe chiffré avec validation du certificat désactivée. Il précise aussi le refus d’un serveur sans TLS et les limites de la qualification.

Le [rapport du paquet 1.20.4-4](https://github.com/xcomponent/appcontrol-release/releases/download/v1.20.4/QUALIFICATION-EVALUATION-1.20.4-4.fr.md)
décrit la publication anonyme, les trois profils d’installation et la mise à
jour avec PostgreSQL intégré depuis le kit 1.20.4-3. Il ne couvre pas le
correctif de droits Windows ni l’option de dépôt PostgreSQL séparé introduits
dans la révision 1.20.4-5.

Le [rapport du paquet 1.20.4-5](https://github.com/xcomponent/appcontrol-release/releases/download/v1.20.4/QUALIFICATION-EVALUATION-1.20.4-5.fr.md)
documente ces améliorations et les installations depuis Windows sur OpenShift.

Le [rapport du paquet 1.20.4-6](https://github.com/xcomponent/appcontrol-release/releases/download/v1.20.4/QUALIFICATION-EVALUATION-1.20.4-6.fr.md)
et ses [preuves Windows/OpenShift](https://github.com/xcomponent/appcontrol-release/releases/download/v1.20.4/QUALIFICATION-EVALUATION-1.20.4-6.zip)
valident le désinstallateur sur les trois profils PostgreSQL et après une mise
à jour depuis le kit 1.20.4-3. Le compte de test ne pouvait ni créer ni supprimer
de projet. Le projet existant, les ressources d'une autre application et le
secret d'images référencé sont conservés. Le parcours intégré vérifie aussi
la réinstallation avec les mêmes données et le même volume ; les parcours
externes vérifient que PostgreSQL reste intact. Les limites et la première
tentative interrompue avant ces vérifications sont consignées dans le rapport.

Les preuves applicables au canal public doivent identifier le kit exact,
Windows/PowerShell, les cinq références `appcontrol-eval-*`, le téléchargement
sans identifiants GHCR et la conservation des données lors d’une mise à jour.
Le rapport 1.20.4-3 utilisait le miroir privé et un jeton temporaire de CI. Pour
chaque nouvelle version, les images du canal public doivent conserver les
digests qualifiés de cette même release ; une publication par copie n'est pas
une nouvelle compilation. Ne pas associer les scripts 1.21.1 au verrou d'images
1.20.4 : le serveur ancien n'expose pas les nouvelles routes.

Le test du parcours léger reste distinct de celui du kit hors ligne : les
images sont téléchargées par le cluster et aucun Helm n’est appelé sur le poste
client.

Le registre Artifactory, les certificats et les règles réseau de la banque
restent à valider dans son environnement. La préparation de ces accès conditionne
le délai ; on ne peut pas promettre quelques minutes avant leur validation.

Ce profil est mono-instance. Le SSO, la PKI bancaire, la sauvegarde/restauration,
la rotation des accès à la base et la haute disponibilité se cadrent ensuite. Les certificats
de service générés durent 90 jours et le jeton de gateway 30 jours ; le
renouvellement reste explicite.

La gateway incluse permet aussi de raccorder un agent extérieur via sa connexion
sortante WSS 443. La [procédure historique d'enrôlement](https://xcomponent.github.io/appcontrol-release/qualification/INSTALLATION-CLIENT-v1.20.4.fr/#5-ajouter-un-agent-exterieur-au-cluster)
explique le principe ; utiliser les binaires ou images et la CA de l'instance
1.21.1 effectivement installée.

Pour un environnement qui impose de transporter les images sans accès à un
registre amont, le [kit hors ligne](https://xcomponent.github.io/appcontrol-release/qualification/INSTALLATION-WINDOWS-HORS-LIGNE.fr/) reste une
option distincte. Ce n’est pas le parcours recommandé ci-dessus.

## Après l'installation : publier les applications du client

À partir d'AppControl **1.21.1**, récupérer le contrat de génération, transmettre
ses instructions et les documents au moteur d'IA du client, puis vérifier la
map retournée. Les documents restent côté client et AppControl n'appelle aucun
modèle dans ce parcours. Le [guide général](../MAP_GENERATION.fr.md) et le
[parcours Swagger](../SWAGGER.fr.md) décrivent la validation, les placements
par composant, les droits d'équipe et l'import. Le kit contient aussi le helper
`map-publication-client.ps1` pour préparer et publier des lots depuis PowerShell.

Le prompt `standard` conserve les procédures réelles fournies. Un prompt
`mock-linux` ou `mock-windows` produit des commandes de fichiers témoins ; la
map suit ensuite **le même import normal**, sans champ `profile` dans
l'enveloppe de publication, sur les agents ordinaires explicitement choisis.
Aucun agent spécial, registre mock ou script de préparation dédié n'est requis.
Applications réelles et simulées peuvent coexister, et une application peut
fonctionner sur plusieurs sites en même temps. Dans **Teams → Applications**,
attribuer les applications aux équipes avec les droits voulus.

Le [guide de simulation](../SIMULATION_MAPS.fr.md) détaille ce choix de prompt.
Dans le ZIP, ces documents sont `MAP_GENERATION.fr.md`, `SWAGGER.fr.md` et
`SIMULATION-MAPS.fr.md`.

### Option distincte : préparer des sites de démonstration

Le complément facultatif `Configurer-Simulation.ps1` prépare des sites,
gateways et un agent Linux persistant par site pour l'outil historique de
transformation serveur. Il enregistre des défauts mock utilisés uniquement par
ce parcours explicite. Il n'est pas une étape préalable à l'import normal.
Pour choisir cette option, adapter `simulation.example.json`, puis lancer :

```powershell
.\Configurer-Simulation.ps1 `
  -DossierEtat 'C:\AppControl\etat-installation' `
  -Configuration '.\simulation.example.json'
```

Le dossier d'état est celui conservé par l'installation principale. Le script
vérifie les capacités du serveur avant de créer ses ressources. Le guide de
simulation décrit séparément la transformation serveur et ses métriques
simulées. Le poste conserve les mêmes prérequis : PowerShell et `oc` uniquement.
