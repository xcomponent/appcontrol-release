# Installer sans ambiguïté : registre, réseau, gateway et agents

> **Parcours Windows recommandé :** [PowerShell + oc](INSTALLATION-WINDOWS.fr.md), avec téléchargement des images publiques d’évaluation par le cluster. Les commandes Python/Skopeo plus bas concernent les variantes Linux/macOS et hors ligne.

## Le schéma de base

```text
Navigateur ── HTTPS 443 ── Route web (réencryptée) ── interface:8080 ── backend:3000
                                                                            │
Agent externe ── WSS 443 sortant ── Route gateway (passthrough) ── gateway:4443 │
                                                                 └─ WSS/mTLS┘
                                                                  backend ── PostgreSQL:5432
```

**La gateway est incluse.** Il n'est pas nécessaire d'en installer une deuxième
pour le premier agent externe. Deux noms DNS pointent vers le routeur OpenShift :
`appcontrol.apps.cluster.banque` et `gateway-appcontrol.apps.cluster.banque`.
« Externe au cluster » ne signifie pas « exposé à Internet » : ces noms peuvent
rester accessibles uniquement sur le réseau interne de la banque.

Les agents initient la connexion persistante vers la gateway. Les commandes
reviennent sur cette connexion ; AppControl n'ouvre pas une connexion entrante
vers chaque serveur agent. Une gateway de zone supplémentaire n'est utile que
si la segmentation réseau du client l'impose.

## Flux à faire approuver

| Source | Destination | Port | Usage |
|---|---|---|---|
| Poste d'administration | API OpenShift | Port de leur API, généralement 6443 | Windows : PowerShell + oc ; variante Linux/macOS : kubectl/Helm |
| Nœuds OpenShift | Registre interne | Généralement TCP 443 | Téléchargement des images ; aucun accès GitHub requis si elles sont déjà recopiées |
| Navigateur | Route web | TCP 443 | Interface/API/WebSocket utilisateur |
| Serveur agent | Route gateway | TCP 443 | Enrôlement puis connexion WSS avec mTLS |
| Routeur | Interface / gateway | TCP 8080 / 4443 | Routage interne ; ne pas ouvrir ces ports sur les serveurs clients |
| Interface et gateway | Backend | TCP 3000 | Transport interne TLS, gateway authentifiée par mTLS |
| Backend | PostgreSQL | TCP 5432 | Base avec vérification TLS |
| Pods | DNS du cluster | TCP/UDP 53 et 5353 selon OpenShift | Résolution ; 5353 correspond au DNS après traduction réseau |
| Backend | Fournisseur SSO/IA | TCP 443, optionnel | Désactivé par défaut ; destinations explicitement configurées si utilisées |

Cette matrice décrit les flux de contrôle AppControl. Les commandes métier
exécutées par un agent peuvent demander leurs propres accès (base, stockage,
API interne, etc.) : les qualifier avec les procédures de l’application. Le
flux sortant 443 vers la gateway ne remplace pas ces éventuels flux métier.

Aucune sortie Internet du backend n'est nécessaire pour cette évaluation sans IA/SSO.
Les NetworkPolicies limitent la communication aux services attendus. L'accès aux
ports frontend/gateway reste ouvert dans leurs règles d'entrée afin d'accepter
le routeur : le filtrage des sources clientes relève aussi des règles d'accès
au routeur et du réseau bancaire. Ne pas présenter cela comme une restriction
par adresse utilisateur déjà configurée.

**Mise à jour d’une installation existante :** renseigner les destinations de son
SSO/IA avant d’appliquer ce chart. Le nouveau défaut coupe leurs sorties HTTPS
s’il n’est pas configuré ; la connexion locale de l’évaluation reste indépendante.

Pour activer des destinations HTTPS : `networkPolicy.backendHttpsCIDRs` dans les
valeurs Helm. Un changement d'adresse du fournisseur impose leur mise à jour.
L'option `allowAnyBackendHttps=true` reste explicite ; elle n'est pas requise ici.
Les politiques standard Kubernetes n'offrent pas à elles seules un filtrage FQDN.

La Route gateway doit rester en **passthrough TLS** : pas de terminaison TLS ni
inspection intermédiaire qui supprime le certificat client. Vérifier que le
réseau autorise WebSocket et une connexion longue. Un proxy authentifié imposé
aux agents nécessite une qualification spécifique ; il n'est pas couvert par ce test.

## D'où viennent les images ?

Le canal public d’évaluation fournit cinq images `ghcr.io/xcomponent/appcontrol-eval-*`
(backend, frontend, gateway, PostgreSQL et agent), accessibles sans identifiants
GHCR. Le fichier `images.lock.json` du kit Windows fixe les empreintes à utiliser.
Les anciens packages `appcontrol-*` restent privés ; la qualification d’un ancien
miroir privé ne prouve pas l’accès au nouveau canal. Consulter le rapport du kit
livré pour les références et parcours effectivement testés.

### Parcours Windows léger : téléchargement par le cluster

1. **Artifactory de la banque :** la plateforme configure le dépôt Docker distant vers GHCR et autorise les noms `appcontrol-eval-*`. Le téléchargement amont est anonyme ; la lecture d’Artifactory par OpenShift peut conserver l’authentification interne de la banque.
2. **Accès direct à GHCR, si autorisé :** conserver les références par défaut, sans compte GitHub ni Secret d’images GHCR.
3. **Poste Windows :** fournir le préfixe de registre et le nom du secret interne éventuel au script. Aucun `docker login`, Skopeo ou téléchargement d’images sur le poste n’est demandé.

Pour les versions suivantes, la chaîne de livraison réutilise ces mêmes noms
avec de nouvelles versions et empreintes ; le kit choisit des digests précis.
La banque peut continuer d’approuver et scanner chaque version. Une mise à jour
de l’installation demande une sauvegarde PostgreSQL puis l’option
`-MettreAJour` du [script Windows](INSTALLATION-WINDOWS.fr.md#mettre-a-jour-le-poc).

### Variante hors ligne et reconditionnement

Le kit Linux/macOS original 1.20.4 contient les cinq archives OCI et
`images.source.lock.json`. Son import dans le registre interne ne nécessite
aucun accès au registre source ou au Sandbox. Ces archives, les commandes
Python/Skopeo ci-dessous et le [guide de livraison](LIVRABLE.fr.md) concernent
ce chemin distinct ; ils ne sont pas nécessaires au parcours Windows léger.

Si la banque impose ses propres bases, les artefacts compilés peuvent être
reconditionnés avec `docker/corporate/`. Scanner les nouvelles images et produire
leurs nouveaux digests : les anciens scans ne s’y appliquent plus.

Les cinq images incluent l’agent de recette. PostgreSQL intégré est facultatif
dans le parcours Windows ; les agents sur VM peuvent utiliser le binaire.

```sh
# Prérequis : Skopeo et accès aux registres via skopeo login (mot de passe hors argv).
# source.lock.json : quatre services + éventuellement agent, tous par digest.
# Sans --execute, ces commandes affichent seulement le plan.
python3 scripts/qualification/transfer-images.py mirror \
  --lock source.lock.json --target-prefix registre.banque/appcontrol \
  --version VERSION --output-lock images.lock.json --execute

# Sur le poste disposant de l'accès au registre source :
python3 scripts/qualification/transfer-images.py export \
  --lock source.lock.json --archive-dir images-oci --execute
# Après transfert du lock et des archives, sur le réseau bancaire :
python3 scripts/qualification/transfer-images.py import \
  --lock source.lock.json --archive-dir images-oci \
  --target-prefix registre.banque/appcontrol --version VERSION \
  --output-lock images.lock.json --execute
```

Ne pas désactiver la vérification TLS du registre. Installer sa CA dans la
configuration de confiance de Skopeo et des nœuds, selon la procédure plateforme.
Les commandes d'import doivent être validées sur le registre cible ; aucun
registre client n'était accessible lors de cette qualification.

## La commande à dérouler chez le client

**Sur Windows :** suivre le [guide PowerShell + oc](INSTALLATION-WINDOWS.fr.md).
Lancer `Deployer-AppControl.ps1` et choisir le projet et la base ; utiliser
`-Registre` et éventuellement `-SecretImages` pour le registre bancaire.

**Variante Linux/macOS originale uniquement :** copier `scripts/qualification/client.example.json` en `client.json` et renseigner
les noms de projet, de contexte, les deux Routes et les chemins. Ce fichier ne
contient aucun mot de passe. Les chemins relatifs sont résolus depuis son dossier.

```sh
python3 scripts/qualification/install.py --config client.json --preflight-only
python3 scripts/qualification/install.py --config client.json
```

Si le registre exige un secret, ajouter `--image-pull-secret NOM_DU_SECRET` aux deux
commandes. Les paramètres CLI priment sur le fichier. Le chart conserve deux anciennes révisions de chaque Deployment (`global.revisionHistoryLimit=2`) afin de limiter les ReplicaSets dans les projets soumis à quota. Prévoir une marge pour les nouvelles révisions et les autres applications du projet ; cet historique est distinct de celui de Helm.

Conserver le dossier privé
pour les mises à jour : les certificats et identifiants y sont réutilisés.

## Enrôlement d'un agent Linux extérieur

1. L'installateur affiche les deux URL et produit `agent-ca.crt`. Copier uniquement
   ce certificat **public**, jamais `ca.key`, les mots de passe ou le dossier privé entier.
2. Dans **Enrollment**, créer un jeton de portée **agent**, à usage unique et durée
   courte. Le remettre via le canal sécurisé convenu ; enregistrer sa valeur dans
   un fichier privé `token` (mode 0600), sans le mettre dans l'historique du shell.
3. Installer le binaire Linux correspondant à la version et vérifier son SHA-256.
   Vérifier aussi son chargement avec `appcontrol-agent --version` avant de créer
   le jeton. Le kit officiel utilise MUSL pour Linux AMD64 ; vérifier également
   les outils requis par les commandes sur la distribution cible. Les essais
   d'anciens candidats GNU/glibc ne qualifient pas ce nouvel artefact.
   Créer un compte de service dédié et un dossier persistant possédé par ce compte
   (mode 0700). Ses droits OS définissent les commandes possibles ; ne pas donner
   root pour la simple recette.
4. Depuis ce compte et la racine du kit extrait, tester DNS/TCP/certificat puis lancer :

```sh
python3 scripts/qualification/enroll-agent.py --binary /opt/appcontrol/appcontrol-agent \
  --gateway wss://gateway-appcontrol.apps.cluster.banque \
  --ca /etc/appcontrol/agent-ca.crt --token-file /chemin/prive/token \
  --state-dir /chemin/prive/agent --preflight-only
# Relancer sans --preflight-only pour enrôler puis exécuter l'agent.
```

Le script n'expose pas le jeton dans les arguments du processus et vérifie le
certificat. Le précontrôle ne consomme pas le jeton ; il ne prouve pas encore
son autorisation. Après enrôlement, l'agent enregistre ses certificats et `agent.yaml`.

5. Vérifier dans **Agents** qu'il est connecté via la gateway, puis l'affecter à
   une map avec des commandes de test. Le démarrage de cette map doit produire
   un état RUNNING et une trace d'action.
6. Après succès, retirer le fichier de jeton et exécuter le service permanent
   directement : `/opt/appcontrol/appcontrol-agent --config /chemin/prive/agent/agent.yaml`.
   Configurer systemd avec le même compte, `APP_ENV=production` et un redémarrage
   sur échec. Le modèle `scripts/qualification/appcontrol-agent.service.example`
   fournit ces réglages, dont `KillMode=process` ; adapter ses chemins et son compte.
   `NoNewPrivileges=true` interdit une élévation via sudo/setuid : conserver les
   commandes dans les droits du compte de service. Ne pas supprimer le dossier de certificats à chaque redémarrage.

Ne pas tuer tous les processus enfants à l'arrêt de l'agent : les applications
lancées doivent survivre à son redémarrage. Qualifier les règles systemd et les
droits des commandes avec l'équipe d'exploitation avant le POC.

## Pourquoi pas FROM scratch ?

La release Linux est construite avec MUSL, mais le binaire seul n'est pas tout
le service : confiance TLS et migrations restent nécessaires. L'agent exécute
un shell et les outils des procédures. L'interface utilise nginx et PostgreSQL
reste un service distinct. Le kit utilise les images minimales qualifiées par
la release ; une base vide ne remplace pas automatiquement ce contrat.

## Preuves du parcours

Les preuves applicables à une livraison sont celles de son kit :
`VALIDATION.fr.md`, `provenance.json`, `evidence/openshift/functional.json` et les
scans/SBOM. Elles identifient les sources et images réellement testées.
Les rapports datés dans le dépôt conservent les essais historiques, notamment
le parcours navigateur, l'agent extérieur et le transfert OCI des candidats.
Ils ne remplacent pas les tests des nouveaux artefacts ni ceux du réseau client.
