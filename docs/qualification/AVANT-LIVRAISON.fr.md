# Première installation client et limites à qualifier

La version 1.21.1 réunit les évolutions du produit et les démonstrations.
Son kit OpenShift vise une première installation isolée, puis un POC cadré.
Le numéro de release stable ne constitue pas une certification de production bancaire.
Pour Windows, le parcours recommandé est le kit léger **1.21.1-2**, avec
PowerShell et le client `oc` existant. Les résultats à retenir sont ceux des
preuves de cette livraison, une fois sa qualification terminée ; les rapports
1.20.4 restent historiques.

## Contrôles exigés pour publier le kit

La CI vérifie les sources, construit les artefacts, scanne les images et les
dépendances de production/développement, puis exécute une recette OpenShift
avec les digests livrés. Le kit contient les rapports, SBOM et provenance.
L'assembleur refuse les preuves manquantes, les alertes et les incohérences de
digest. Lire ses fichiers `VALIDATION.fr.md` et `provenance.json` pour le résultat
effectif de cette version ; les rapports d'octobre du dépôt restent historiques.

Le parcours utilise quatre services : frontend, backend, gateway et PostgreSQL.
Un agent supplémentaire sert aux tests synthétiques. TLS/mTLS, droits,
ordre des dépendances, reconnexions et persistance sont éprouvés par la recette.
Un scan sans alerte est daté ; il ne démontre pas l'absence de toute faille.

## Points à traiter avec le client

| Sujet | Périmètre et décision |
|---|---|
| Base d'image et registre | Parcours Windows léger : faire télécharger les images publiques `appcontrol-eval-*` par les nœuds, via Artifactory ou GHCR autorisé. Hors ligne : importer les OCI par digest. Reconditionner les binaires si les bases bancaires l'imposent, puis rescanner et retester. |
| Installation | Projet dédié, stockage, deux Routes, quotas et confiance TLS à préparer. Aucun besoin de compilation chez le client. |
| Agents extérieurs | Gateway incluse, WSS sortant sur 443, jeton à usage unique et certificat public de CA. Tester le DNS, les pare-feu, le système et le compte OS réels. |
| Haute disponibilité | Backend mono-instance/Recreate : interruption pour maintenance. Ne pas augmenter le nombre de répliques en supposant une HA qualifiée. |
| PKI, jetons, SSO et base client | La PKI générée sert à l'évaluation. Certificats de service 90 jours, jeton gateway 30 jours ; renouvellement explicite. Les raccordements client demandent leur propre recette. |
| Sauvegarde et reprise | La persistance après redémarrage n'est pas un test de restauration. Vérifier une sauvegarde restaurable avant de dépendre des données. |
| Mise à jour existante | Tester sur une copie restaurée. Helm ne restaure ni les migrations ni les données. Voir [UPGRADE](../UPGRADE.md). |
| Reconstruction applicative | Qualifier les procédures et la restauration de chaque application sur un périmètre non critique. Les commandes synthétiques de démo ne constituent pas cette qualification. |
| IA et automatisation | Conserver les périmètres de clés, contrôles serveur et revues indépendantes requis ; une confirmation technique n'est pas une approbation métier. |

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
