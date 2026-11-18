# Raccorder une source documentaire à X4B

Le [contrat OpenAPI](knowledge-engine.openapi.yaml) décrit les opérations
du connecteur dans le profil d’intégration X4B pour l’exécution de prompts.
**Côté client, deux opérations suffisent au parcours de
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
`https://knowledge.example/api/v1/prompt-executions`. Le raccordement est
accessible dans **Connaissance → Source documentaire**. Les propositions
générées se trouvent dans l’**Atelier de cartographie**.

| Opération | Ce que le Knowledge Engine fournit |
| --- | --- |
| `GET /knowledge-documents` | Une liste paginée des clés applicatives autorisées et de l’empreinte SHA-256 de leur document courant. Le filtre `application_key` vérifie la révision courante d’une application. |
| `GET /knowledge-documents/{application_key}/versions/{sha256}` | Le JSON d’une révision précise, pour la prévisualisation, le diagnostic ou la vérification d’un rapprochement. |
| `POST /prompt-executions` | L’exécution synchrone d’un prompt générique, avec une révision documentaire ou sans document, et avec une pièce jointe facultative. Le service renvoie le résultat textuel et les références des entrées utilisées. |

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

## Mettre à jour le service client pour l’affinage

Le profil OpenAPI 1.1 conserve l’URL, le jeton de service et le format
utilisé jusqu’ici pour les générations et les affinages avec document.
Le service continue de vérifier le droit d’exécuter un prompt et, si une
révision est fournie, le droit de consulter cette révision précise.

Le champ `document` reste requis. Une référence `{application_key, sha256}`
demande le document exact. La valeur explicite `null` demande d’exécuter
le prompt avec le contexte fourni dans la requête. Dans les deux cas,
le service renvoie le champ `document` avec la valeur utilisée.

Le champ facultatif `attachment` accepte un seul fichier. Il contient
`filename`, le nom sans chemin limité à 255 octets UTF-8, `media_type` et `content_base64`,
les octets d’origine en base64 standard. Le plafond est de 512 Kio
(524 288 octets) après décodage. Les types admis sont `image/png`,
`image/jpeg`, `application/pdf` et `text/plain` en UTF-8. Le service
valide le fichier, puis le joint au contexte de l’IA. Pour une image, il
doit l’envoyer comme entrée visuelle à un modèle capable de l’analyser.
Un retour de succès avec pièce jointe inclut `attachment_sha256` calculé
sur les octets décodés, après inclusion du fichier dans le contexte. X4B
vérifie cette empreinte. Si le type ou l’entrée visuelle n’est pas pris en
charge, le service peut répondre `415`. Utilisez `400` pour une requête
mal formée et `413` si le fichier dépasse le plafond.

Le service traite le document de référence, les extraits Git présents
dans le prompt et le fichier joint comme des données de contexte. Il
préserve les limites du compte de service et évite de journaliser le
contenu des sources, le prompt ou le jeton.

Exemple minimal avec un fichier texte et sans document de référence.

```json
{
  "document": null,
  "prompt": "Relève le prérequis mentionné dans la pièce jointe.",
  "attachment": {
    "filename": "demarrage.txt",
    "media_type": "text/plain",
    "content_base64": "QVBJIGF2YW50IGJhc2UuCg=="
  }
}
```

Le service retourne par exemple ce corps en `200`.

```json
{
  "document": null,
  "result": "La pièce jointe indique de démarrer l’API avant la base.",
  "attachment_sha256": "663ea86279bfc5cd7f471964514cf17a2c36ac182c6fd350f778c68d27d84a4c"
}
```

Vérifiez le service avant de l’utiliser depuis l’Atelier de cartographie.

1. Rejouez la demande historique sur une révision accessible et sans fichier.
   Vérifiez le `200`, la référence retournée et le résultat textuel.
2. Envoyez `document: null` sans fichier. Vérifiez que le service conserve
   l’autorisation d’exécution et renvoie `document: null` sans lire le document.
3. Rejouez l’exemple avec pièce jointe et comparez l’empreinte du fichier décodé.
   Pour vérifier le chemin visuel, envoyez aussi un petit PNG ou JPEG et
   demandez à l’IA de décrire un élément visible dans l’image.
4. Essayez du base64 mal formé, un type non admis, un fichier trop volumineux
   et un jeton hors périmètre. Vérifiez les refus avant l’appel à l’IA.
   Côté X4B, vérifiez qu’une réponse avec référence ou empreinte manquante
   ou incorrecte produit une erreur d’affinage.

## Cycle de mise à jour côté X4B

1. **Synchroniser le catalogue.** À la demande ou selon une planification, X4B
   parcourt les pages et compare, par source et clé applicative, les empreintes observées
   à celles des générations précédentes. La première observation crée un **dossier de
   cartographie** durable, avant qu’une map AppControl existe. Une nouvelle empreinte
   actualise ce même dossier : son affectation et son historique ne sont pas recréés
   à chaque génération. Un document sans changement réutilise son
   résultat pour la même configuration.
2. **Répartir le dossier.** Une nouvelle clé apparaît dans **À répartir**. Un
   gestionnaire de portefeuille lui attribue une équipe responsable et peut nommer un
   référent, ajouter des équipes contributrices ou relectrices, fixer une priorité et
   une date cible. L’affectation porte sur le dossier identifié par la source et la clé
   applicative, jamais sur une exécution technique temporaire.
3. **Générer.** Le traitement de fond limite le nombre d’appels simultanés et
   conserve l’état de chaque application dans PostgreSQL. Il identifie une
   génération par la source, la clé applicative, l’empreinte du document et le
   contexte de génération, dont le prompt, les références du catalogue de
   composants et les codes et noms des sites actifs. Un retour `429` déclenche une reprise différée. Un délai
   dépassé ou une coupure après envoi est signalé pour relance. Après un
   arrêt du backend pendant un appel, sa reprise peut consommer un deuxième
   appel à l’IA. La déduplication des générations et des maps est
   gérée dans X4B. Une ancienne révision devenue indisponible déclenche une
   nouvelle lecture du catalogue. Pendant une nouvelle tentative et après un
   échec, le dossier affiche la carte publiée et, s’il existe, le dernier
   brouillon enregistré. Ces aperçus sont en lecture seule. Une relance sur
   la même révision conserve le brouillon jusqu’à ce qu’une nouvelle
   proposition soit prête.
4. **Valider et publier.** X4B vérifie la référence retournée, valide le JSON
   avec AppControl et conserve le résultat candidat. Il vérifie la révision
   courante avant d’ouvrir l’assistant de publication, puis à la confirmation.
   En cas de rejet de la carte générée, le dossier distingue une réponse
   illisible comme JSON d’un écart au format AppControl. Pour un écart de
   format, il indique le premier motif et, si possible, son emplacement
   dans la structure du document.
   Après synchronisation, ouvrez **Comparer avec le brouillon précédent** si
   la base IA de ce brouillon est connue. X4B prépare la reprise des retouches
   compatibles et indique les écarts à arbitrer manuellement. Enregistrez
   explicitement les retouches à reprendre, puis relisez le résultat avant
   de le valider. Les versions antérieures restent disponibles dans
   **Historique des versions**.
   Pour une première map, X4B enregistre la
   référence externe `{"system":"documentation","id":"00142"}`, avec un nom de
   source stable configuré côté X4B. Pour une map existante, il affiche les
   écarts entre la proposition et la version publiée et permet d’appliquer la
   mise à jour après confirmation. X4B garde
   séparément l’empreinte source de la map publiée et celle de la dernière
   génération. Une disparition du catalogue est signalée et la map est conservée.

### Répartir et suivre les dossiers de cartographie

Le connecteur documentaire reste partagé au niveau de l’organisation. Sa configuration,
le test de connexion et la synchronisation globale relèvent de l’administration de la
source. La distribution quotidienne est distincte : l’administrateur peut déléguer la
fonction de **gestionnaire de portefeuille** à une personne ou à une équipe. Cette
fonction permet de voir le portefeuille et la file **À répartir**, d’affecter un dossier
ou un lot, et de transférer un dossier. Elle n’accorde aucun droit de démarrage, d’arrêt
ou d’exploitation dans AppControl.

L’affectation distingue les responsabilités suivantes :

| Responsabilité | Rôle dans le dossier |
| --- | --- |
| **Équipe responsable** | Porte la création ou la mise à jour, accepte la prise en charge et conduit le dossier jusqu’à la publication. Une seule équipe est responsable à la fois. |
| **Référent** | Membre facultatif de l’équipe responsable, identifié comme point de contact. L’équipe reste responsable si aucun référent n’est nommé ou si celui-ci change. |
| **Équipe contributrice** | Modifie la proposition dans le périmètre du dossier. |
| **Équipe relectrice** | Consulte la proposition pour relecture sans devenir responsable du dossier. |
| **Gestionnaire de portefeuille** | Affecte, réaffecte ou transfère les dossiers et traite les exceptions de distribution. |

Les vues **À répartir**, **Mon équipe** et **Portefeuille** donnent respectivement accès
aux dossiers sans responsable, aux dossiers des équipes de l’utilisateur et à la vue
transverse réservée aux gestionnaires et administrateurs. La génération fournit
une **Base IA**. Après l’affectation et la prise en charge, le dossier passe par
**Brouillon en cours → En relecture → Validé → Publié**. **Bloqué** signale un
obstacle à traiter dans le dossier. Le bouton de publication est visible en
haut du dossier validé. Le statut technique indique séparément l’avancement
ou l’erreur de la dernière génération.

**Historique des versions** liste les bases IA, les brouillons enregistrés,
les changements de statut et les publications. Un brouillon enregistré peut
être consulté dans le graphe et téléchargé. L’Atelier indique la date et
l’auteur de la dernière retouche connue. Les anciennes propositions déjà
enregistrées sont reprises lors de la mise à jour, avec les métadonnées
disponibles à cette date.

Après l’affectation, un lead de l’équipe responsable ou le référent nommé **accepte**
le dossier pour matérialiser sa prise en charge. Si l’équipe ne peut pas en être
responsable, elle le **renvoie à la répartition** avec un motif. Le gestionnaire peut
aussi le transférer directement à une autre équipe. L’acceptation, le retour, le
transfert et les changements de priorité ou d’échéance sont audités avec leur auteur et,
le cas échéant, leur motif. Une modification concurrente de l’affectation demande de
recharger le dossier avant de confirmer, afin de ne pas écraser une décision plus récente.

Les documents et les réponses de l’IA peuvent alimenter la revue, mais ne peuvent jamais
désigner une équipe ni accorder un droit.

Les droits du dossier sont des droits de **collaboration** : consulter, modifier la
proposition, ou gérer et publier le dossier. Ils sont séparés des permissions
de la map AppControl. À la première publication, l’auteur de la publication et les
équipes du dossier reçoivent un accès de consultation à la map afin de pouvoir la
retrouver. Si une map publiée est réaffectée, les nouvelles équipes reçoivent aussi cet
accès. Cette synchronisation est additive : elle ne retire ni ne réduit les droits
applicatifs existants, qui peuvent avoir été accordés ou élevés explicitement dans
AppControl. Toute permission AppControl plus élevée, notamment `operate`, reste une
décision explicite dans le partage de la map. Une personne autorisée à construire ou
publier un dossier ne reçoit donc pas
implicitement les commandes Start, Stop ou Reconstruction. Les sites, workspaces,
passerelles et agents sont également revérifiés au moment de la publication.

> **Prolongement de conception — commentaires de révision.** Le modèle cible prévoit
> des fils de commentaires attachés au dossier pour signaler une brique technique, une
> information ou une preuve manquante, avec conservation lors d’une update ou d’un
> transfert. Le workflow décrit ici ne fournit pas encore cette capacité de commentaire
> « comme dans Word » ; les motifs de retour et l’historique d’affectation sont les traces
> collaboratives disponibles dans ce contrat.

Lorsqu’une source déjà publiée change, X4B rattache la nouvelle proposition au même
dossier et la renvoie à l’équipe qui en est responsable avec le statut **Affecté**. Cette
équipe reprend explicitement le dossier avant de relire l’update. L’historique et les
participants sont conservés ; une nouvelle répartition n’est pas demandée. Si l’équipe
responsable n’existe plus ou si le dossier n’a plus de responsable valide,
l’update rejoint **À répartir** comme exception. La map publiée reste disponible tant
que sa mise à jour n’a pas été relue et confirmée.

Avec un catalogue de composants AppControl, X4B demande d’abord à l’IA de relever
les briques et les indices techniques dans le document. Il compare ces éléments
aux clés, libellés et alias du catalogue de l’organisation. Le prompt final est
exécuté sur le même document avec l’ensemble des clés, libellés, descriptions et
alias du catalogue, les suggestions par composant et les codes et noms des sites
actifs. Lorsque plusieurs variantes partagent une famille de produits, une
version majeure compatible peut faire ressortir une candidate. Le graphe
affiche la brique proposée avec **À vérifier** quand le rapprochement reste
incertain, et marque **À qualifier** les composants sans choix proposé.
En **Mode édition**, utilisez **Rapprochements catalogue** pour choisir ou
confirmer une brique, puis enregistrez le brouillon. Le mode édition permet aussi
de modifier la disposition du graphe, les composants et les dépendances. Dans
la vue intégrée, la molette fait défiler la page et la combinaison Ctrl/Cmd avec
la molette zoome sur le graphe. Si vous confirmez la publication d’une brique sans type, elle utilise le type générique
`custom`. Les commandes et agents des composants déjà configurés sont conservés.
Les commandes, icônes et couleurs du catalogue restent dans AppControl.
Sans catalogue de composants, X4B exécute directement le prompt final avec les
sites disponibles.

L’aperçu de la proposition permet d’ouvrir l’éditeur. Le zoom et le bouton
**Plein écran** sont disponibles dans les deux vues. Sélectionnez un composant
pour rechercher une brique par libellé, description ou mot-clé. Vous pouvez
aussi modifier son libellé, sa description et ses sites documentés, déplacer
les composants ou ajuster leurs dépendances. Enregistrez la proposition, examinez les écarts
et confirmez la publication. X4B refuse la publication si la proposition ou
la map a changé depuis la revue et vous invite à recharger.

La publication individuelle ouvre un assistant. Choisissez le site de
rattachement, puis vérifiez le site d’exécution, la passerelle et l’agent de
chaque composant à affecter. L’assistant peut proposer un agent lorsque la
correspondance est unique. Le récapitulatif affiche les affectations avant
confirmation. Pour une mise à jour, l’étape d’affectation présente les
nouveaux composants et ceux qui attendent un agent. La publication groupée
produit des cartes descriptives. Les commandes d’exploitation se configurent
dans AppControl.

La génération initiale s’appuie sur l’inventaire technique, l’architecture et
les procédures de l’application demandée. Les applications citées uniquement
dans les échanges inter-applications restent hors de sa carte d’exploitation.
La génération examine les flux entre ses propres composants et leurs
prérequis de démarrage. Elle recherche aussi des liens dans les
paramètres de connexion et les procédures lorsque le document ne fournit pas
de tableau des dépendances. Les nouvelles générations et les relances
manuelles utilisent cette consigne sans déclencher de relance en masse.

Quand la source documente plusieurs instances équivalentes d’un même
service, la génération propose un seul composant cluster. La proposition
et la map publiée conservent les hôtes, le site documenté pour chaque hôte
et les dépendances du service. Des instances du même produit peuvent rester
des composants distincts si leurs rôles ou leurs prérequis diffèrent.
Ce cluster est descriptif. Le mode fan-out et les affectations des agents
relèvent de la configuration d’exploitation.

Dans l’écran d’examen de l’**Atelier de cartographie**, l’affinage utilise
la carte ouverte, le catalogue et les sites actifs. En haut de la
proposition, cliquez sur **Choisir les sources** pour régler les entrées de
cette analyse. **Inclure le document source** est présélectionné avec la
révision associée à la proposition. Vous pouvez décocher cette option ou
sélectionner des **Fichiers du dépôt**. La connexion documentaire se règle
dans **Connaissance → Source documentaire → Paramètres**.

Les fichiers Git sont proposés pour une application déjà associée à une
map AppControl disposant de fichiers texte indexés dans **Connaissance**.
La liste affiche des révisions précises. La sélection est liée au dépôt,
au commit, au chemin et à l’empreinte du fichier. X4B joint au prompt les
extraits sélectionnés et leur provenance. Vous pouvez sélectionner jusqu’à
huit fichiers, dans la limite de 32 Kio de texte UTF-8 au total. La revue
utilise les fichiers déjà indexés dans le périmètre de la map.

Ouvrez **Préciser l’analyse** pour ajouter une consigne, renseigner
**Composants à exclure** ou ajouter une **Pièce jointe**. Les composants
exclus restent sur la carte. Les suggestions de l’analyse ciblée portent
sur les composants retenus.

La revue peut suggérer une brique du catalogue, un rattachement à un groupe, une modification de
dépendance ou le retrait d’un nœud qui représente uniquement une application
externe. En acceptant ce retrait, vous retirez aussi les liens de ce nœud du
brouillon. La revue examine le rôle des composants et les flux documentés. Une
dépendance est forte si le composant doit attendre un prérequis avant de
démarrer, y compris lors d’une reprise. Un lien de routage peut être représenté
par une dépendance faible.
La revue peut proposer un lien faible déduit d’un indice précis de la source.
La suggestion indique l’indice et ce qu’il faut vérifier avant de l’appliquer.
La revue présente le motif, la source indiquée par l’IA et les points à
confirmer. Les types de composants déjà confirmés par l’opérateur sont
protégés. Les suggestions cochées apparaissent immédiatement sur le graphe.
Cliquez sur **Appliquer à la proposition** pour enregistrer la sélection ou
sur **Appliquer et ouvrir l’éditeur** pour poursuivre l’édition de la carte.

**Tester la connexion** vérifie l’accès au catalogue documentaire.
**Affiner la carte** exécute un prompt avec le contexte sélectionné.
**Entrées utilisées** indique le document, les fichiers Git, les composants exclus
et la pièce jointe qui ont servi à la demande, selon la sélection. Il
présente le nom, le type et l’empreinte de la pièce jointe. En cas d’échec,
l’écran indique le motif de l’analyse et le bouton **Relancer l’analyse**
permet de réessayer.

Une consigne facultative permet de cibler la revue, par exemple sur les
dépendances d’un service ou sa procédure de démarrage. La consigne accompagne
le contexte choisi pour cette analyse. Les recommandations sur les commandes et les
procédures restent consultables dans le résultat de l’analyse. Seules les
modifications de topologie sélectionnées sont appliquées au brouillon.

L’interface native utilise `GET /api/v1/x4b/map-generation/jobs/{id}/review-sources`
pour lire la référence documentaire et les fichiers indexés sélectionnables, puis `POST /api/v1/x4b/map-generation/jobs/{id}/review`
pour demander l’analyse. Le corps accepte `instruction`, `include_document`
(vrai par défaut), `repository_sources` (paires `revision` et `path`),
`excluded_components` (noms des composants de la proposition) et `attachment`.
Le résultat de la revue expose `inputs`, avec le document, les métadonnées des
fichiers Git, les noms des composants exclus et les métadonnées de
la pièce jointe. Le connecteur du client reçoit quant à lui les champs du
profil `POST /prompt-executions` décrit ci-dessus.

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
**Connaissance → Source documentaire → Paramètres**. Saisissez l’URL complète terminée par
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

1. Ouvrez **Connaissance** en tant qu’administrateur et cliquez sur
   **Tester la connexion**. X4B lit une page du catalogue. Ce test sert à
   vérifier l’accès réseau et l’authentification de lecture avant la
   génération.
2. Cliquez sur **Synchroniser les sources**. X4B met en file les documents
   nouveaux ou modifiés du périmètre autorisé et affiche l’état de chaque
   clé. Le premier lot peut être borné par le périmètre du compte de service.
3. Ouvrez l’**Atelier de cartographie** en tant qu’administrateur ou gestionnaire
   de portefeuille. Dans **À répartir**, affectez les nouveaux dossiers à leur équipe
   responsable. Ajoutez si nécessaire un référent, des équipes contributrices ou
   relectrices, une priorité et une date cible. L’équipe responsable accepte ensuite
   le dossier dans **Mon équipe**, ou le renvoie avec un motif si elle ne peut pas le
   prendre en charge.
4. Examinez la proposition et les sites
   proposés par composant. Si le document
   situe une même API à `Sirius` et `Legac`, les deux sites apparaissent sur ce
   composant et restent visibles sur la map publiée. La revue signale les sites
   introuvables ou ambigus. Si chaque composant correspond au même site actif,
   le formulaire individuel le propose comme rattachement administratif de
   l’application. Les autres cas demandent un choix explicite. Les placements
   d’exécution et les agents se configurent dans AppControl.
   Une publication groupée peut traiter jusqu’à
   100 candidates par appel API et reste une action d’administration transverse. Une
   personne disposant du droit de gestion du dossier peut publier sa proposition
   individuellement. Une fois les maps présentes, ajoutez les
   éventuels droits d’exploitation dans AppControl ou renseignez `permissions` dans le
   JSON de configuration et relancez le script. Les droits de collaboration du dossier
   ne donnent jamais implicitement `operate`.
5. Pour démontrer une évolution, modifiez un document source puis
   resynchronisez. X4B génère une proposition pour la nouvelle empreinte.
   Le dossier reste attribué à la même équipe, qui le reprend en charge. Ouvrez le détail
   dans **À comparer**, relisez les écarts et utilisez
   **Modifier la carte** pour ajuster la proposition. Cliquez sur
   **Publier la mise à jour**, confirmez, puis ouvrez la map publiée.
6. Ouvrez la map dans le widget pour tester sa reconstruction. Avec un seul
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
| Nouvelle clé applicative | X4B crée un dossier durable dans **À répartir** ; la génération technique peut progresser séparément. | Un gestionnaire de portefeuille choisit l’équipe responsable et les participants. |
| Première génération affectée | Le résultat validé attend dans **À publier**. | L’équipe responsable accepte, relit et prépare le dossier ; une personne disposant du droit de gestion choisit le site et publie la map. Un administrateur peut publier un lot éligible. |
| Même empreinte et même configuration | X4B réutilise la génération précédente. | Aucune action. |
| Catalogue de composants ou sites actifs modifiés | La synchronisation recalcule les propositions concernées. | Relire les correspondances avant publication. |
| Empreinte différente et map déjà publiée | X4B prépare une proposition dans le même dossier, la restitue à son équipe responsable et affiche les écarts dans **À comparer**. | L’équipe relit et ajuste la proposition, puis une personne autorisée confirme la mise à jour. |
| Responsable devenu invalide | X4B conserve le dossier et le place dans **À répartir** comme exception. | Un gestionnaire de portefeuille choisit une nouvelle équipe. |
| Source absente ou génération en erreur | L’état technique est visible dans la file et la map publiée reste disponible. | L’utilisateur autorisé corrige la source ou relance l’échec. |

X4B vérifie la version source et la version de la map relue. L’application
de la topologie, l’enregistrement de la révision publiée et l’écriture
de l’audit se font dans la même transaction. Une modification concurrente
demande une nouvelle revue.

### Revue avec Git

Dans le workflow direct, la décision humaine se prend dans AppControl. La proposition
doit identifier la map, la version source, la version active relue et
l’empreinte des changements approuvés. L’audit enregistre l’auteur de la
décision et la révision appliquée.

Si l’organisation choisit une gouvernance par Git, X4B peut ouvrir une pull request contenant ces
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
