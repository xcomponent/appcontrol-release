# Installer AppControl dans une banque — audit critique

> **Pour commencer l’installation depuis Windows :** suivre le
> [parcours Windows AppControl 1.20.4](INSTALLATION-WINDOWS.fr.md), mis à jour le
> 31 octobre 2026. Il explique PostgreSQL inclus, l’agent de démonstration et
> l’import des images dans Artifactory, sans Python. Le présent audit décrit
> les choix d’architecture et les intégrations à prévoir ; ce n’est pas le
> guide pas à pas de première installation.

## Conclusion

La topologie est raisonnable pour une évaluation OpenShift : **quatre services**
(interface, backend, gateway, PostgreSQL), ou **trois services AppControl** avec
PostgreSQL fourni par la banque. Ces services constituent la pile complète
du fonctionnement de base.
Le connecteur MCP est un binaire séparé (`appcontrol-mcp`, transport stdio),
lancé par le client IA et raccordé à l’API du backend. Il ne nécessite pas de pod
supplémentaire pour cette évaluation sans IA. Les fonctions utilisant un modèle IA
nécessitent séparément un fournisseur autorisé et les flux associés.

Le nombre de conteneurs n'est pas le principal obstacle. Les vrais travaux
d'intégration sont l'homologation des images, la PKI, le SSO, les flux vers les
agents, la sauvegarde et les règles d'exploitation. L'installation guidée est
adaptée à une évaluation isolée ; elle n'est pas encore un déploiement bancaire
de production « sans intégration ».

| Situation | Appréciation | Travail restant chez le client |
|---|---|---|
| Évaluation dans un projet dédié, images approuvées | Complexité modérée | Projet, registre, stockage, DNS/Routes, lancement et recette |
| Bases Linux et registre internes imposés | Modérée à élevée lors du premier raccordement | Reconditionnement des binaires, contrôle ABI, scan/SBOM et signature |
| Production avec PKI, SSO et PostgreSQL gérés | Élevée tant que ces raccordements ne sont pas qualifiés | Intégration plateforme, rotation, restauration et exploitation |
| Haute disponibilité sans interruption | Non couverte par cette version | Le backend est mono-instance ; une seconde réplique n'est pas une solution HA validée |

Ces appréciations sont un jugement d'ingénierie, pas un engagement de délai.
Les validations internes de la banque peuvent dominer le calendrier.

## Ce que je recommande de conserver ou de simplifier

1. **Conserver les trois services AppControl séparés.** Fusionner gateway,
   backend et interface réduirait le nombre de pods mais mélangerait les droits,
   les réseaux et les cycles de mise à jour. Cela ne supprime ni les dépendances
   logicielles à scanner ni les certificats à gérer.
2. **Réutiliser PostgreSQL 16 de la banque en production.** Cela enlève le pod
   PostgreSQL et son image du périmètre AppControl, et confie sauvegarde/HA à la
   plateforme existante. Le chart supporte la désactivation de la base embarquée ;
   le guide d'évaluation automatique n'effectue pas encore ce raccordement.
3. **Livrer les artefacts et les recettes, pas seulement les images.** La banque
   doit pouvoir choisir ses bases sans avoir à modifier le code AppControl.
   Les recettes `docker/corporate` n'installent aucun paquet pendant l'empaquetage.
4. **Utiliser une liste d'images immuables unique.** `--image-lock` accepte les
   noms de dépôt du client et impose les digests. Une reconstruction implique
   une nouvelle analyse CVE, un nouveau SBOM et une nouvelle recette.
5. **Réduire les décisions d'installation.** Le chemin guidé demande un contexte,
   un projet, un fichier d'images, deux noms DNS et un dossier privé. La classe
   de stockage et le secret de registre sont optionnels selon la plateforme.

## Images imposées : proposition à l'équipe plateforme

« Nous fournissons les binaires versionnés, les fichiers de l'interface, les
migrations SQL et les recettes de construction. Vous pouvez les intégrer à vos
bases approuvées et à votre registre. Nous qualifions ensuite le fonctionnement
sur ces images finales. »

Il ne s'agit pas de contourner leur politique. Si elle exige également de
recompiler depuis les sources, il faut convenir du périmètre livré, de la licence
et d'une chaîne de compilation reproductible. Reconditionner un binaire et le
recompiler sont deux opérations distinctes.

Attention : un binaire glibc récent ne fonctionne pas nécessairement sur UBI 8/9.
Le test de cette session utilise UBI 10 pour les services Rust. Le frontend
nécessite une base avec nginx. L'image PostgreSQL embarquée utilise l'entrypoint
de l'image officielle : ne pas lui substituer une image PostgreSQL Red Hat sans
adapter son contrat de démarrage.

## Corrections apportées pendant cet audit

- Installation depuis un JSON d'images par digest, sans noms de registre imposés.
- Choix explicite de la StorageClass et vérification préalable des outils/droits.
- Rejet de l'option d'UID local lorsqu'une Route OpenShift est demandée.
- Lancement explicite de nginx par le chart pour neutraliser les différences
  d'entrypoint entre bases clientes ; incompatibilité constatée sur le cluster.
- Recettes de packaging sur bases approuvées, avec séparation backend/runtime.
- Correction d'un bug de l'agent : une URL `wss://hote` utilisait à tort le port
  4443 au lieu du port standard 443, ce qui bloquait les connexions via Route
  après un enrôlement pourtant réussi. Un test couvre aussi `:443` explicite,
  normalisé par le parseur d'URL, les ports personnalisés et IPv6.
- Recette fonctionnelle passant par la Route web et la Route d'enrôlement, avec
  assertion des SCC effectivement attribuées aux cinq pods.
- Correction de la CI : les images de PR internes doivent être publiées si le
  test OpenShift de ces mêmes PR est activé. Les PR de forks restent exclues.

## Points à fermer avant une production bancaire

- Qualifier la **base exacte** choisie par le client, ses scans et sa politique
  de signature. Les scans fournis couvrent les images UBI 10 exactes du kit ;
  ils ne couvrent pas une autre base ou une reconstruction.
- Raccorder et tester PKI/rotation, PostgreSQL externe et SSO du client. La PKI
  de l'installateur est une PKI d'évaluation : certificats de service 90 jours,
  jeton gateway 30 jours, renouvellements explicites.
- Tester restauration, reprise après panne pendant une opération et comportement
  en cas de perte de connectivité. La persistance après redémarrage n'est pas un
  test de restauration ni une garantie de reprise d'opération.
- Définir les droits des comptes de service agents et les flux autorisés vers
  les applications. Un pod agent de test ne prouve pas l'accès aux serveurs client.
- Documenter maintenance mono-backend, supervision et politique de rétention.
  Des logs de chevauchement de partitions ont été observés au démarrage ; leur
  nettoyage est à traiter séparément de la validation du déploiement.
- Resserrer selon le réseau client les ouvertures d'entrée frontend/gateway et
  les destinations HTTPS optionnelles du backend (sortie désactivée par défaut). Les NetworkPolicies actuelles ne remplacent pas
  une matrice de flux validée par la banque.

## Preuves et limites

Le test réel utilise OpenShift 4.21.30 dans le projet Sandbox `frecarre-dev`.
Les builds d'images s'exécutent dans OpenShift et publient dans son registre
interne. Le compte applicatif ne reçoit ni privilège root ni SCC `anyuid`.
Les comptes techniques de construction sont ceux de la plateforme et ont un
périmètre distinct des pods applicatifs.

La [recette réelle](OPENSHIFT-RESULTATS-2026-10-08.fr.md) a réussi ses dix contrôles,
dont commandes start/stop, reconnexion gateway et persistance après redémarrages.
Les cinq images finales et les dépendances de production ont zéro alerte dans
les scans fournis. Deux alertes de développement CSS restent visibles dans le
[rapport de périmètre](SECURITE-DEPENDANCES-2026-10-08.fr.md), avec les SBOM. Ces résultats ne certifient pas une autre base ou le SI client.

Références : [règles Red Hat pour les UID arbitraires](https://docs.redhat.com/en/documentation/openshift_container_platform/4.7/html/images/creating-images),
[périmètre des bases UBI](https://access.redhat.com/support/policy/updates/ubi).
