# Première installation client et limites à qualifier

Cette procédure vise **X4B / AppControl 1.27.0** et le kit Windows léger
**1.27.0-1**, avec PowerShell et le client `oc` existant. Le kit OpenShift
vise une installation isolée ou la mise à jour d’un POC cadré. Le numéro de
release stable ne constitue pas une certification de production bancaire.
Les résultats applicables sont ceux des preuves du kit exact, après leur
production par la chaîne de qualification. Les rapports 1.20.4 et 1.21.1
restent historiques et ne doivent pas être réétiquetés pour cette livraison.

Le périmètre comprend les sources Knowledge nommées et la bibliothèque de
documents, le catalogue avec faits de support sourcés, la Discovery par skills
et plans approuvés, le durcissement IAM et les correctifs Rust de suivi des
commandes, de persistance des résultats et de reprise des connexions. La
collecte native reste limitée aux agents Linux explicitement autorisés et aux
plans approuvés. Elle ne qualifie pas les commandes métier d’une application.

## Contrôles exigés pour publier le kit

La CI vérifie les sources, construit les artefacts, scanne les images et les
dépendances de production/développement, puis exécute une recette OpenShift
avec les digests livrés. Le kit contient les rapports, SBOM et provenance.
L'assembleur refuse les preuves manquantes, les alertes et les incohérences de
digest. Lire ses fichiers `VALIDATION.fr.md` et `provenance.json` pour le résultat
effectif de cette version ; les rapports d'octobre du dépôt restent historiques.

Le parcours utilise quatre services : frontend, backend, gateway et PostgreSQL.
Un agent supplémentaire sert aux tests synthétiques. TLS/mTLS, droits,
ordre des dépendances, reconnexions et persistance doivent être éprouvés par la recette de cette livraison.
Un scan sans alerte est daté ; il ne démontre pas l'absence de toute faille.

## Points à traiter avec le client

| Sujet | Périmètre et décision |
|---|---|
| Base d'image et registre | Parcours Windows léger : faire télécharger les images publiques `appcontrol-eval-*` par les nœuds, via Artifactory ou GHCR autorisé. Hors ligne : importer les OCI par digest. Reconditionner les binaires si les bases bancaires l'imposent, puis rescanner et retester. |
| Installation | Projet dédié, stockage, deux Routes, quotas et confiance TLS à préparer. Aucun besoin de compilation chez le client. |
| Agents extérieurs | Gateway incluse, WSS sortant sur 443, jeton à usage unique et certificat public de CA. Tester le DNS, les pare-feu, le système et le compte OS réels. |
| Haute disponibilité | Backend mono-instance/Recreate : interruption pour maintenance. Ne pas augmenter le nombre de répliques en supposant une HA qualifiée. |
| PKI, jetons, SSO et base client | La PKI générée sert à l'évaluation. Certificats de service 90 jours, jeton gateway 30 jours ; renouvellement explicite. Vérifier le précontrôle SSO, l’issuer SAML/OIDC, les callbacks et les références Secret avant application du manifeste ; qualifier le véritable fournisseur client. La MFA dépend de sa politique, sans attestation automatique par X4B. Voir [IAM](../IAM.md). |
| Sauvegarde et reprise | La persistance après redémarrage n'est pas un test de restauration. Vérifier une sauvegarde restaurable avant de dépendre des données. |
| Mise à jour existante | Tester sur une copie restaurée, préserver les paramètres et références Secret, puis vérifier les migrations V080–V086. Mettre à jour et vérifier le backend avant les agents pour les acquittements persistants. Restaurer une sauvegarde compatible en cas de retour à une version antérieure. Voir [UPGRADE](../UPGRADE.md). |
| Reconstruction applicative | Qualifier les procédures et la restauration de chaque application sur un périmètre non critique. Les commandes synthétiques de démo ne constituent pas cette qualification. |
| IA et automatisation | Sélectionner la source du dossier et le contexte d’affinage ; valider les propositions avant publication. Pour la Discovery native, configurer la clé dédiée et le consentement local sur l’agent Linux, puis approuver le plan exact. Une confirmation technique n'est pas une approbation métier. |

## Travaux de sûreté toujours nécessaires pour l'automatisation critique

Les notes `demo-rebuild/AMELIORATIONS-PRODUIT.fr.md` et
`demo-rebuild/ai-incident/DEVELOPPEMENTS-AVANT-PRODUCTION.fr.md` restent les
références de travail. La première installation traite le packaging et la recette
plateforme ; elle ne ferme pas les sujets suivants :

- Détection et réconciliation durable des opérations interrompues.
- Issue d'une commande inconnue après déconnexion, idempotence et résultats tardifs.
- Qualification indépendante des parcours IA et de leurs approbations serveur.
- Contrats des adaptateurs, charge, sauvegarde et rollback des applications réelles.

Le correctif de suppression conserve les historiques Knowledge/reconstruction
et les verrous d'opération : une suppression interdite renvoie un conflit sans
nettoyage partiel. Il ne remplace pas la réconciliation d'une opération bloquée.
Le premier POC peut rester manuel et non critique pendant ces qualifications.
