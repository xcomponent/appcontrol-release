# Dossier de reprise X4B hors ligne

Un dossier hors ligne conserve les éléments utiles à la reprise d’une application
pour **une révision approuvée et un site précis**. Préparer et conserver le fichier
chiffré avant un incident, dans l’espace de sauvegarde prévu par l’organisation.

## Préparer le dossier

Depuis la révision approuvée, demander l’export hors ligne. Il exige une session
humaine, les droits **Owner** et l’accès au site de la révision. Le propriétaire
confirme l’empreinte de la révision et le site. Utiliser l’interface en HTTPS.
Conserver la clé aléatoire du dossier dans le coffre de sauvegarde, séparément du
fichier `.x4brecovery`. L’instance ne conserve aucune copie de la clé d’export.

Pour un appel API, transmettre les paramètres dans le corps JSON d’un
`POST /api/v1/apps/{app}/procedures/{procedure}/revisions/{revision}/offline-dossier`
sur HTTPS. Fournir `site_id`, `digest`, `confirm_export: true` et `key_hex`, soit
64 caractères hexadécimaux générés à partir de 32 octets cryptographiquement
aléatoires. Passer la clé via le mécanisme d’injection de secrets de l’organisation,
hors URL, historique du shell, traces HTTP et journaux du proxy. La réponse est
une pièce jointe chiffrée et n’autorise pas sa mise en cache.

## Vérifier et consulter hors de l’instance

1. Conserver `recovery-dossier-reader.html` avec les moyens de reprise, à partir du
   kit authentifié de la version. Le fichier est à la racine du kit Windows léger
   et sous `docs/` dans le kit OpenShift avec OCI. On peut aussi le télécharger
   depuis le dossier X4B avant l’incident.
2. Ouvrir cette page locale dans un navigateur approuvé disposant de Web Crypto
   sur `file:`. Chrome ou Edge peuvent être utilisés à cette fin selon la politique
   du poste. Aucune connexion à X4B, à Internet, au référentiel ou à une IA n’est
   utilisée par le lecteur.
3. Sélectionner l’archive et saisir la clé. Si disponible, saisir l’empreinte
   SHA-256 enregistrée par l’événement d’audit `procedure_offline_dossier_export`,
   récupérée par un canal de confiance et conservée hors de l’instance. Le lecteur
   vérifie le chiffrement authentifié et les empreintes de tous les fichiers avant
   de présenter leur texte. Les contenus affichés ne sont jamais rendus en HTML.
4. Examiner en premier `LISEZ-MOI.md` et `manifest.json`. Une extraction en clair
   est une action explicite. La stocker avec les protections des configurations
   opérationnelles. Fermer le lecteur après consultation.

| Fichier | Contenu |
| --- | --- |
| `manifest.json` | Application, site, procédure, révision, identité de l’export, date, version produit, empreintes et tailles UTF-8 des fichiers. |
| `SKILL.md`, `revision.json` | Texte et étapes approuvés, décision de revue et empreinte de la révision originale. Les empreintes originales désignent l’instantané conservé par X4B. |
| `architecture.json` | Graphe approuvé pour repérer les composants et liens. Les commandes et liaisons nominales du graphe ne sont pas incluses. |
| `plan.json` | Compilation des commandes effectives de l’instantané approuvé et liaisons du site. Si la compilation est bloquée, liste des blocages et aucune commande partielle. |
| `sources.json` | Références exactes et contenus encore conservés et autorisés. Les entrées `reference_only` indiquent les contenus manquants, retirés, non autorisés ou hors de la fenêtre de recherche des 20 dernières révisions Knowledge. `architecture_projection` renvoie au graphe joint. |
| `evidence.json` | Exécutions, preuves et adoptions rattachées à la révision. Les imports manuels restent non vérifiés. Les résultats natifs sont corrélés, et un ancien champ `identity_verified` ne représente pas une attestation indépendante. |

L’export limite le contenu en clair à 16 Mio. Une révision dont l’historique
dépasse la capacité de l’export est refusée avec un message explicite. Les
documents d’un référentiel externe dont X4B ne conserve que la référence doivent
être sauvegardés séparément par l’opérateur. Le dossier n’est pas une sauvegarde
de la base X4B. Il faut préparer séparément la restauration des données métier,
les images et scripts appelés, les secrets, l’identification de la cible et de ses
préconditions, la neutralisation de la source et la validation du trafic.

## Format et garanties

L’enveloppe JSON `x4b-recovery-dossier-encrypted-v1` indique `AES-256-GCM`, un nonce
aléatoire de 12 octets encodé en Base64 et le texte chiffré suivi du tag de 16 octets,
aussi encodé en Base64. Le libellé de format, encodé en UTF-8, sert de donnée
associée. Après déchiffrement le JSON contient le manifeste `x4b-recovery-dossier-v1`
et les fichiers textuels. L’origine n’est pas signée indépendamment de la clé de
chiffrement. Conserver l’empreinte de l’archive fournie par l’audit via un canal
distinct lorsque l’origine doit être vérifiée hors de l’instance.

Les commandes ne sont jamais lancées par le lecteur et ne sont pas certifiées
exécutables sur un nouvel hôte. Consulter les résultats retenus et vérifier le
site, les identités, la disponibilité des scripts et les conditions réelles
avant toute opération approuvée de reprise.
