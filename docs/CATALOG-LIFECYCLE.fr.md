# Alimenter les informations d’obsolescence du catalogue

X4B conserve des faits de support par **type de composant, version et source**.
Ils permettent de retrouver les composants des applications publiées qui
utilisent cette version. Ces faits sont distincts du statut documentaire
`obsolescence` d’une map et des commandes d’exploitation.

Le protocole X4B d’alimentation est un document JSON versionné `1.0`. Il peut
être produit par un référentiel client, une transformation de fichier ou un
connecteur à une base de cycles de support. Le fournisseur traduit ses données
dans ce format et les soumet à X4B. Cette fonction ne télécharge pas
automatiquement des informations sur Internet.

Le [schéma JSON](catalog-lifecycle.schema.json) et un
[exemple de requête](catalog-lifecycle.example.json) accompagnent ce guide.
L’exemple utilise un produit fictif : remplacez la clé par une `type_key`
réellement présente dans le catalogue de l’organisation et fournissez une
preuve de support adaptée au produit et à la version.

## Contrat d’un fait

| Champ | Sens et contraintes |
| --- | --- |
| `type_key` | Clé exacte d’une brique du catalogue, sensible à la casse ; 1 à 50 caractères ASCII parmi lettres, chiffres, tiret et souligné. Le protocole n’ajoute pas automatiquement une brique inconnue. |
| `version` | Version explicitement identifiée, de 1 à 100 caractères. Ce champ décrit la version concernée par le fait. |
| `version_match` | `exact` par défaut. `release_prefix` indique explicitement une famille de versions. |
| `status` | `supported`, `deprecated`, `end_of_support` ou `unknown`, selon l’autorité déclarée. |
| `support_end` | Date facultative de fin du support normal, au format `YYYY-MM-DD`. |
| `extended_support_end` | Date facultative de fin du support étendu ; elle doit être postérieure ou égale à `support_end` lorsque les deux dates existent. |
| `source.system` | Identifiant stable du référentiel ou de la source documentaire : slug minuscule de 1 à 64 octets, commençant par une lettre ou un chiffre. |
| `source.id` | Identifiant stable du fait chez cette source, de 1 à 128 octets UTF-8, sans espaces périphériques ni caractères de contrôle. |
| `source.sha256` | Empreinte facultative de la révision documentaire : 64 caractères hexadécimaux minuscules. |
| `source.reference` | Référence facultative de consultation, de 1 à 2 048 caractères, sans caractères de contrôle. C’est une indication documentaire ; l’import ne la télécharge pas. |
| `observed_at` | Date et heure de l’observation au format RFC3339, avec fuseau. X4B normalise la valeur en UTC et refuse une observation située à plus de 24 heures dans le futur. |
| `evidence` | Preuve ou référence de section de 1 à 4 000 caractères. Les retours à la ligne et tabulations sont admis ; gardez les secrets hors de ce texte. |

Avec `exact`, un fait sur `3.2` ne s’applique pas implicitement à `3.2.1`.
Avec `release_prefix`, `3` couvre `3`, `3.2` et `3-lts`, mais pas `30` ou
`3c`. Cette règle doit correspondre au périmètre de la preuve. Les préfixes
ne servent pas à rapprocher approximativement deux produits.

La date de fin de support est le **dernier jour supporté** ; le statut calculé
passe à `end_of_support` le jour suivant, selon la date UTC du serveur.
La présence d’une date de support étendu ne prouve pas que l’organisation
dispose du contrat correspondant. Conservez cette information et faites
qualifier les droits de support applicables.

## Importer avec aperçu puis validation

L’API est identique en local et sur OpenShift. Identifiez l’URL et
l’organisation de l’instance cible. Une session d’administration convient.
Une clé de service doit appartenir à un administrateur et disposer du périmètre
`catalog:write`. Les lectures du catalogue utilisent `catalog:read`.

1. Consultez `GET /api/v1/catalog/component-types` et vérifiez les clés visées.
   Pour une brique, `GET /api/v1/catalog/component-types/{id}/lifecycle` donne
   ses faits enregistrés et leur état calculé. `{id}` est l’UUID du catalogue,
   distinct de `type_key`.
2. Préparez de 1 à 1 000 faits. Un lot ne peut contenir deux fois la même
   identité : organisation, clé, version, règle de rapprochement et paire
   `source.system` / `source.id`.
3. Envoyez `POST /api/v1/catalog/lifecycle/import` avec
   `{"schema_version":"1.0","dry_run":true,"records":[…]}`.
   L’aperçu renvoie `created`, `updated`, `unchanged`, les différences
   `before` / `after` par fait et un `digest`.
4. Relisez les différences, notamment une disparition de date ou de preuve.
   Chaque enregistrement remplace le fait complet de même identité : les
   champs facultatifs omis sont absents de la nouvelle observation. Les faits
   non cités dans le lot restent présents.
5. Pour appliquer le lot revu, renvoyez les mêmes faits avec `dry_run:false`
   et `expected_digest` égal au `digest` de l’aperçu. Le digest lie le contenu
   proposé à l’état du catalogue et des faits au moment de l’aperçu.
6. Après application, relisez les faits et les applications concernées. Une
   réponse perdue exige une relecture avant de recommencer. Un lot identique
   revient dans `unchanged`.

Un `400` signale notamment un format invalide, une clé inconnue, un doublon
ou une application demandée sans digest d’aperçu. Un `409` signale un aperçu
devenu caduc ou une observation plus ancienne que celle déjà enregistrée
pour la même identité. Dans ces cas, relisez l’état et préparez un nouvel
aperçu. L’import applique le lot dans une transaction et conserve les
modifications dans les traces de configuration et d’action.

Deux sources peuvent rapporter des faits différents sur le même produit et la
même version. X4B conserve leur provenance séparément. Le rapprochement signale
un conflit lorsque les états applicables divergent ; il ne remplace pas une
autorité par une autre sur la seule base d’un ordre d’import.

## Analyser un document synchronisé avec l’IA

Dans **Connaissance**, ouvrez une révision de document puis utilisez l’action
**Analyser le cycle de support avec l’IA**. Cette action est distincte de la consultation et
peut consommer un appel au service IA. Elle est réservée à une session
d’administration et indisponible en lecture seule.

L’API X4B correspondante est :

```text
POST /api/v1/x4b/knowledge-documents/{application_key}/versions/{sha256}/lifecycle-analysis?source={source}
```

Le document doit avoir été observé pour cette organisation, cette source et
cette empreinte. X4B utilise le connecteur associé à la source, transmet une
instruction interne et la référence exacte du document au service du client,
puis vérifie la référence renvoyée. Le profil client `1.1` d’exécution de
prompts suffit ; aucune nouvelle opération du service client n’est requise.

L’IA recherche un produit du catalogue, une version explicitement documentée,
un état ou des dates de support et une preuve. Une information manquante ou
ambiguë devient une question. Le serveur ajoute la source, la clé applicative,
le SHA-256 et la date d’observation ; ces champs d’autorité ne proviennent pas
du modèle. Les propositions sont soumises aux validations du protocole
d’import. Les éléments invalides sont exclus avec une question et les
contradictions portant sur la même version sont laissées à résoudre.

La réponse est un objet contenant `schema_version`, `records`, `questions` et
`provenance` avec `source`, `application_key` et `sha256`. Elle peut ne contenir
aucun fait. La lecture directe du document restant facultative dans le profil
client, les extraits retournés par l’IA ne sont pas vérifiés automatiquement
contre les octets du document. **Ce sont des propositions à relire.**
Sélectionnez les faits pertinents, obtenez l’aperçu d’import puis validez les
différences avant application. L’analyse seule n’écrit aucun fait de référence,
ne publie aucune map et ne change aucune commande.

La synchronisation des sources recense les révisions et peut générer les maps.
Elle ne lance pas automatiquement une analyse d’obsolescence indépendante de
chaque document. La génération de map conserve son champ documentaire
`obsolescence` ; celui-ci n’alimente pas seul les faits de support acceptés.

## Retrouver les applications concernées

`GET /api/v1/catalog/component-types/{id}/usages` retourne les composants des
applications publiées accessibles au compte, leur version connue et les
identifiants des faits applicables. La consultation filtre les applications
selon les droits existants.

Une version absente reste `version_unknown`. Une version connue sans fait
applicable reste `no_matching_record`. Des faits d’états divergents donnent
`conflicting`. Les autres états reprennent le support calculé : `supported`,
`deprecated`, `end_of_support` ou `unknown`.

Les rapprochements utilisent la `type_key` du composant et la version
explicitement renseignée dans `obsolescence.version`. Ils n’infèrent pas une
version à partir du nom de machine, d’un libellé ou d’une commande. Cette vue
décrit les maps publiées ; elle ne prétend pas inventorier tous les logiciels
installés sur les machines. Une fin de support n’est pas une preuve de
vulnérabilité, ni une analyse CVE.
