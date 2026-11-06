# AppControl sur OpenShift — démarrer le POC

**Parcours recommandé depuis Windows : le [guide PowerShell + oc](INSTALLATION-WINDOWS.fr.md),
pour AppControl 1.21.1 et le kit léger 1.21.1-2.**
Le ZIP contient les scripts, les YAML et leurs guides. Il utilise la commande
`oc` déjà approuvée sur le poste ; aucun Docker, Python, Helm ou outil de transfert
d’images n’est à installer. Les nœuds OpenShift téléchargent les images.

Le [dépôt public de livraison XComponent](https://github.com/xcomponent/appcontrol-release/releases)
centralise les kits versionnés, les procédures et les rapports. Le canal public
d’évaluation emploie les images **`ghcr.io/xcomponent/appcontrol-eval-*`**, sans
compte GitHub ni mot de passe de téléchargement. Il peut être relayé par
Artifactory selon les règles de la banque. Les anciens packages `appcontrol-*`
restent privés ; le dépôt source n’est pas rendu public.

> La livraison du kit Windows léger est conditionnée au téléchargement anonyme
> des images et à la qualification du ZIP exact depuis Windows sur OpenShift.
> Les preuves attendues pour le kit 1.21.1-2 sont
> `PUBLICATION-EVALUATION-1.21.1-2.json` et `QUALIFICATION-EVALUATION-1.21.1-2.zip`,
> jointes à la même release lorsque les contrôles ont abouti. Ce guide ne vaut
> pas résultat de qualification. Les rapports de la release 1.20.4 et de ses
> kits restent des preuves historiques ; ils ne valident pas la livraison 1.21.1.

Après publication :
[kit léger 1.21.1-2](https://github.com/xcomponent/appcontrol-release/releases/download/v1.21.1/appcontrol-openshift-windows-light-1.21.1-2.zip)
et [empreinte SHA-256](https://github.com/xcomponent/appcontrol-release/releases/download/v1.21.1/appcontrol-openshift-windows-light-1.21.1-2.zip.sha256).
Les images de cette version utilisent les tags `appcontrol-eval-*:1.21.1` ;
l’installation fixe leurs empreintes dans le verrou d’images du kit.
La révision **1.21.1-2** modifie les scripts de déploiement, nettoyage et reprise,
sans changer le produit 1.21.1 ni ses images. Les messages et confirmations sont
en anglais ; les paramètres français des commandes existantes restent acceptés.

## Avant le premier créneau

| À obtenir | Pourquoi |
|---|---|
| Un projet OpenShift dédié et les droits de déploiement | Isoler les objets du POC, sans demander `cluster-admin` |
| Une connexion `oc` depuis le poste Windows | Appliquer les YAML et ouvrir le tunnel d’installation |
| Les images approuvées et accessibles aux nœuds | Via Artifactory, ou directement depuis GHCR si la banque l’autorise |
| Le choix de PostgreSQL | Base intégrée pour découvrir, ou base dédiée fournie par la banque |
| Les accès réseau et certificats | Routes web/gateway, registre et éventuelle base externe |

Avec Artifactory, demander **le préfixe Docker exact des images
`appcontrol-eval-*`** et le **nom éventuel du Secret OpenShift de lecture**. Les
packages publics ne demandent aucun identifiant GitHub amont ; les droits
OpenShift → Artifactory restent ceux de la banque.

Le token Artifactory se renseigne dans ce **Secret OpenShift de type Image pull
secret**, avec son identifiant, dans le projet cible. `-SecretImages` reçoit
uniquement le nom du secret. Pour un miroir GHCR exposé à
`artifactory.intra.example/docker-ghcr`, utiliser cette valeur dans `-Registre` :
le script conserve **`xcomponent`** et construit
`artifactory.intra.example/docker-ghcr/xcomponent/appcontrol-eval-…`.
Si le chemin fourni comporte déjà `xcomponent`, il n’est pas ajouté une seconde
fois. Pour un miroir volontairement aplati, le guide décrit
`-CheminRegistreExact`.

## Installer, démontrer, faire évoluer

1. Télécharger le kit Windows léger et vérifier son empreinte SHA-256.
2. Lancer `Deployer-AppControl.ps1`. Le script demande le projet et le mode PostgreSQL ; pour Artifactory, fournir les valeurs de la plateforme avec `-Registre` et éventuellement `-SecretImages`.
3. Ouvrir l’URL affichée. La recette crée un agent et une map synthétique pour vérifier les dépendances, le démarrage, l’arrêt, les droits et la persistance.
4. Choisir une application pour le POC, préparer sa map avec l’IA du client et les guides ci-dessous, puis vérifier les commandes, les agents choisis et les droits avec son équipe d’exploitation. Commencer par des commandes simulées ou une application non critique selon le périmètre convenu.
5. Pour une nouvelle version, récupérer son kit, sauvegarder PostgreSQL puis relancer **le même script avec `-MettreAJour`**. Le dossier privé de l’installation, ses paramètres et ses données sont conservés ; prévoir une interruption des services. Voir la [procédure de mise à jour](INSTALLATION-WINDOWS.fr.md#mettre-a-jour-le-poc).

La mise à jour conserve les maps et ne rejoue pas la démonstration. Elle met à
jour les services AppControl et, en mode intégré, l’image PostgreSQL. Les agents
existants gardent leur version et leur identité ; leur mise à jour est une
opération distincte.

Si l’interface ou le backend a été supprimé à la main, remettre d’abord les
services avec **le kit de la version déjà installée**, le dossier privé d’origine
et `-SansDemo`. Ensuite, revenir au nouveau kit pour lancer `-MettreAJour`.
La procédure détaillée fournit la commande de réparation ; une ancienne version
ne doit pas être redéployée si une vraie mise à jour était déjà en cours.

L’agent de démonstration conservé garde également ses anciennes références de
secret Artifactory. Le script signale une différence sans redémarrer son pod,
car son identité est temporaire. Une nouvelle recette applique le nouveau secret
mais crée une nouvelle identité d’agent et une nouvelle map ; `-SansDemo`
préserve l’agent et la démonstration existants.

La publication des versions suivantes réutilise la chaîne existante. Les images
validées sont copiées vers le même canal public avec un numéro de version,
sans nouvelle compilation ni copie manuelle chez le client. L’installation
reste fixée aux digests du kit choisi ; elle ne suit pas automatiquement
`latest`.

## Nettoyer ou recommencer sans supprimer le projet

Depuis le kit 1.21.1-2, afficher d’abord la cible :

```powershell
.\Desinstaller-AppControl.ps1 -Namespace 'projet-fourni' -Name 'appcontrol-evaluation' -Preview
```

Retirer `-Preview` pour enlever les services tout en conservant la base et la
configuration. Pour une **suppression complète des données de l’évaluation**,
ajouter `-RemoveAll` ; sauvegarder auparavant si les données doivent être
conservées. Le script traite les objets restants même si certains ont déjà été
supprimés ; un bilan identifie ce qui a été retiré ou reste à corriger. Le projet
et la base PostgreSQL externe ne sont jamais supprimés. Un secret Artifactory
référencé peut être supprimé avec `-RemoveAll` uniquement s’il n’est pas partagé.

Si le dossier privé est perdu ou illisible, le parcours `-WithoutState` exige
le projet et le nom explicites et contrôle les marqueurs de propriété des
ressources. Après nettoyage complet, utiliser :

```powershell
.\Deployer-AppControl.ps1 -Projet 'projet-fourni' -Nom 'appcontrol-evaluation' -Reinstaller
```

Le script vérifie que les anciennes ressources ont été retirées, archive
l’ancien état local et prépare une installation neuve. Fournir à nouveau les
paramètres Artifactory, puis recréer le secret de lecture s’il a été supprimé.
Avec PostgreSQL externe, une nouvelle base dédiée vide ou un nettoyage validé
par son administrateur est requis ; `-BaseExterneVideConfirmee` atteste cette
préparation sans effacer la base. Pour conserver les maps, reprendre l’état
d’origine au lieu de réinstaller à vide.

Voir les [commandes de nettoyage et de reprise](INSTALLATION-WINDOWS.fr.md#retirer-appcontrol-sans-supprimer-le-projet),
notamment le choix du dossier privé personnalisé et les confirmations.

## Publier les applications du client

La version 1.21.1 fournit un contrat de génération à transmettre, avec les
documents de l’application, au **moteur d’IA du client**. AppControl n’appelle
aucun modèle dans ce parcours. Relire la map produite, la valider, choisir
les agents et préparer l’import avant de la publier. Le
[guide de génération et publication](../MAP_GENERATION.fr.md) et le
[parcours Swagger](../SWAGGER.fr.md) détaillent ces étapes ; le kit fournit
aussi `map-publication-client.ps1` pour les lots PowerShell.

Une application peut répartir ses composants sur **plusieurs sites en même
temps**, avec des placements explicites. Dans **Teams → Applications**,
attribuer les applications aux équipes et choisir leurs niveaux de droits.

La simulation est un **choix de prompt** : `mock-linux` ou `mock-windows`
demande à l’IA de générer des commandes qui manipulent des fichiers témoins.
La map suit ensuite **le même import normal**, sur les agents ordinaires
choisis, sans préparation de simulation ni agent spécial obligatoires.
Applications réelles et simulées peuvent coexister. Voir le
[guide de simulation](../SIMULATION_MAPS.fr.md).

Dans le ZIP, les guides portent les noms `MAP_GENERATION.fr.md`,
`SWAGGER.fr.md` et `SIMULATION-MAPS.fr.md`. Le complément facultatif
`Configurer-Simulation.ps1` prépare des sites de démonstration pour l’outil
historique de transformation serveur ; il n’est pas requis pour ce parcours.

## Ce qui tourne dans le projet

| Choix | Services AppControl | Démonstration | Base à préparer |
|---|---|---|---|
| PostgreSQL intégré | Interface web, backend, gateway, PostgreSQL : **4 pods** | Agent supplémentaire : **5 pods au total** | Aucune ; volume persistant de 2 Gio |
| PostgreSQL externe | Interface web, backend, gateway : **3 pods** | Agent supplémentaire : **4 pods au total** | Base dédiée, connexion, réseau et politique TLS fournis par la banque |

La gateway est incluse. L’agent réel s’installe sur les machines à piloter ; il
ne faut pas un pod par application. Le connecteur MCP est optionnel et cette
recette ne dépend ni d’un fournisseur IA ni de Redis.

Fusionner tous les processus dans un conteneur ne supprimerait ni le stockage,
ni les certificats, ni les flux à faire approuver. Les services distincts gardent
leurs responsabilités et leurs redémarrages propres. Le backend de ce profil
reste mono-instance : la livraison d’évaluation ne promet pas de haute disponibilité.

## Images et politique bancaire

Le parcours recommandé utilise les images éditeur validées, identifiées par
digest. Si la banque impose ses bases, les exécutables déjà compilés peuvent être
reconditionnés avec les [recettes et contrats de compatibilité](../../docker/corporate/README.fr.md).
L’image obtenue doit être scannée et testée à nouveau. La release Linux utilise
MUSL ; l’interface nécessite nginx et l’agent les outils de ses procédures. Une
base `scratch` n’est pas un remplacement automatique de ce contrat.

Si leur politique impose la compilation depuis les sources, ce point doit être
convenu explicitement : reconditionner les binaires ne signifie pas recompiler
le produit.

Pour un réseau fermé où les images doivent être transférées par un canal dédié,
le [kit hors ligne](INSTALLATION-WINDOWS-HORS-LIGNE.fr.md) et le
[kit Linux/macOS original](LIVRABLE.fr.md) restent disponibles. Ces variantes
n’ajoutent aucun outil au parcours Windows léger ci-dessus.

## Ressources de départ

En mode intégré avec démonstration : **1,15 vCPU et 992 Mio réservés**, plus un
volume PostgreSQL de 2 Gio. Avec PostgreSQL externe : **0,90 vCPU et 736 Mio côté
AppControl**, hors base bancaire. Les limites des YAML sont supérieures aux
réservations ; conserver une marge de quota pour les redémarrages.

Le temps technique d’installation ne comprend pas les délais d’approbation du
registre, du réseau et du projet. Ces prérequis conditionnent le premier créneau.

## Sécurité et périmètre de l’évaluation

Le caractère public concerne **le téléchargement des images**, pas l’accès à
AppControl ni l’exposition de ses Routes sur Internet. Les droits utilisateurs,
les clés d’API, le TLS et le mTLS des agents restent nécessaires.

Les rapports de chaque livraison identifient les images exactes, la date et le
périmètre des scans/SBOM et des tests OpenShift. Un rapport sans vulnérabilité
signalée ne remplace pas un pentest et ne signifie pas absence de faille. Le
registre Artifactory, les certificats et les règles réseau du client restent à
qualifier sur place. Consulter les [points avant livraison](AVANT-LIVRAISON.fr.md).

La PKI générée est destinée à l’évaluation : certificats de service de 90 jours
et jeton gateway de 30 jours, avec renouvellement explicite. La map synthétique
utilise des marqueurs dans le pod agent ; elle ne restaure pas une application
bancaire et n’exécute aucune commande métier du client.

Avant de dépendre des données du POC, qualifier leur sauvegarde et leur
restauration. Une mise à jour peut appliquer des migrations de base ; le script
ne promet pas de retour arrière automatique. Les droits OS des agents, les
procédures, la rotation des accès, le SSO et la haute disponibilité se cadrent
avec l’exploitation.

Pour les flux et l’enrôlement d’agents extérieurs, lire
[Réseau, images et agents](RESEAU-IMAGES-AGENTS.fr.md).
