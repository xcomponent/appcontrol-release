# Sécurité du candidat OpenShift — 28 octobre 2026

> **Rapport historique du candidat : ne pas utiliser comme validation de la release.**
> Le contrôle complémentaire RustSec du 28 octobre a identifié huit alertes
> dans quatre dépendances absentes des résultats Trivy ci-dessous. Les versions
> corrigées sont intégrées à la préparation 1.20.4 ; seule sa nouvelle chaîne
> complète et les preuves jointes à cette release autorisent sa livraison.
> Les résultats Trivy historiques sont conservés tels quels.

**Les cinq images exactes du nouveau kit et les dépendances applicatives
analysées ne présentent aucune vulnérabilité signalée par Trivy au 28 octobre
2026, toutes sévérités comprises.** Le contrôle couvre aussi les dépendances de
développement. Il n’utilise ni exclusion d’avis ni filtre masquant les
vulnérabilités sans correctif.

Ce résultat concerne les artefacts identifiés ci-dessous. **La CI générale
reste en échec sur d’autres images, construites avec ses bases Wolfi épinglées.**
Son résultat et celui du kit doivent rester distincts dans la décision de
livraison. Aucun de ces contrôles ne constitue une certification de production
bancaire ou une garantie d’absence de faille.

## Périmètre et méthode

- Sources corrigées : `2268728478f117b2b578109eb9a2652794b74485`.
- Scanner du kit : **Trivy 0.76.1**.
- Base de vulnérabilités mise à jour le **28 octobre 2026 à 07:10:42 UTC**, puis
  téléchargée à 09:49:17 UTC. Les scans utilisent cette même base, conservée
  localement pour assurer la cohérence des résultats.
- Sévérités comptées : UNKNOWN, LOW, MEDIUM, HIGH et CRITICAL.
- Images : analyse des archives OCI finales, vérification de leur digest contre
  le verrou d’images et de l’identité de configuration dans les rapports ; SBOM
  CycloneDX associé à chaque image.
- Bibliothèques applicatives : scan séparé de `Cargo.lock`, des manifestes Rust
  et du lockfile npm correspondant aux sources de compilation. Un second scan
  avec `--include-dev-deps` conserve le périmètre complet des outils de build.

Le scan des paquets Linux ne suffit pas à identifier toutes les bibliothèques
Rust liées dans les exécutables ou tous les modules du JavaScript compilé.
Les deux contrôles sont donc nécessaires : images finales et dépendances de
leurs sources. La [synthèse des images](evidence/openshift-2026-10-28/security-current.json),
le [rapport de production](evidence/openshift-2026-10-28/updated-dependencies-production.json)
et le [rapport incluant le développement](evidence/openshift-2026-10-28/updated-dependencies-all.json)
permettent de vérifier ces périmètres séparément.

## Résultat sur les images à livrer

| Composant | Système analysé | Préfixe du digest SHA-256 | Alertes |
|---|---|---|---:|
| Backend | UBI 10 minimal / Red Hat 10.0 | `f4707c96de3dadc4` | 0 |
| Interface web | Alpine 3.24.3 | `b4bb7660ef6512ca` | 0 |
| Gateway | UBI 10 minimal / Red Hat 10.0 | `782e86e414337f2d` | 0 |
| PostgreSQL | Alpine 3.24.3 | `f647cb2073a95a46` | 0 |
| Agent | UBI 10 minimal / Red Hat 10.0 | `ff0ba3c4bd4e42c4` | 0 |

Les digests complets et références figurent dans la
[synthèse datée](evidence/openshift-2026-10-28/security-current.json) et dans
`images.source.lock.json` du kit. Les rapports bruts et les SBOM accompagnent
le paquet. Le [test de transfert hors ligne](evidence/openshift-2026-10-28/offline-transfer-current.json)
vérifie que le script client importe les cinq archives OCI dans un registre TLS
isolé en conservant ces digests. Le registre de la banque reste à qualifier.

## Pourquoi le kit du 8 octobre a été reconstruit

Le rescan du kit précédent avec la base du 28 octobre a trouvé les résultats
suivants. Le « zéro alerte » constaté le 8 octobre restait un résultat daté,
insuffisant pour autoriser une nouvelle livraison sans contrôle.

| Périmètre de l’ancien kit, rescanné le 28 octobre | Alertes |
|---|---:|
| Image backend | 0 |
| Image frontend | 59 : 6 HIGH, 7 MEDIUM, 44 LOW, 2 UNKNOWN |
| Image gateway | 0 |
| Image agent | 0 |
| Image PostgreSQL | 2 UNKNOWN |
| Dépendances applicatives de production | 4 : 1 MEDIUM, 3 LOW |
| Dépendances avec les outils de développement | 8, dont les 4 précédentes |

Le [bilan de reprise](evidence/openshift-2026-10-28/review-status.json) conserve
ces résultats et les empreintes des rapports. Son statut intermédiaire décrit
une reconstruction alors en cours ; le résultat final des images est porté par
la synthèse séparée ci-dessus. Les anciens paquets ne sont pas approuvés pour
cette nouvelle livraison.

Les corrections applicatives sont limitées aux mises à jour compatibles :

| Dépendance | Ancienne version | Version retenue | Périmètre |
|---|---|---|---|
| rustls | 0.23.45 | 0.23.46 | Transport TLS Rust ; quatre avis GHSA recensés |
| Vitest et sa famille, dont `@vitest/mocker` | 4.1.11 | 4.1.12 | Tests frontend ; CVE-2026-112949 et CVE-2026-112950 |
| postcss-selector-parser | 6.1.4 | 6.1.5 | Build CSS ; CVE-2026-104844, correctif désormais disponible en branche 6.x |
| zod | 4.6.5 | 4.6.7 | Dépendance d’outillage ; CVE-2023-54404, correctif introduit en 4.6.6 |

Aucun remplacement forcé de version majeure ni override global n’a été ajouté.
Les nouveaux exécutables sont reconditionnés sur UBI 10 minimal et les images
Alpine sont reconstruites avec leurs paquets système corrigés. Après ces
changements, les deux scans des dépendances donnent **zéro alerte**, y compris
dans le rapport contenant les outils de développement. Le rapport historique
du 8 octobre reste conservé ; ses alertes ne sont pas supprimées rétroactivement.

## Échec de la CI générale : périmètre distinct et explicite

Le job Kubernetes restreint de la
CI 40669149665
a réussi ses neuf contrôles fonctionnels puis échoué à l’étape de scan des
images. Le [diagnostic détaillé](evidence/openshift-2026-10-28/ci-restricted-diagnostic.json)
identifie des vulnérabilités dans les paquets système de ses bases Wolfi :

- backend : 13 occurrences, dont 1 HIGH et 12 MEDIUM ;
- gateway : 13 occurrences, dont 1 HIGH et 12 MEDIUM ;
- agent : 17 occurrences, dont 1 HIGH et 16 MEDIUM.

Il s’agit de cinq avis distincts, répétés selon les paquets présents :
`CVE-2026-111943`, `CVE-2026-8674`, `CVE-2026-86805`, `CVE-2026-89092` et
`CVE-2026-95818`. Ils concernent notamment le paquet de certificats racines et
les paquets glibc. Le scanner de ce job est Trivy 0.75.0 ; le contrôle de sécurité
a correctement refusé ces images. Le diagnostic ne constate pas une panne de
scanner ni un échec de la recette fonctionnelle.

Les images UBI 10/Alpine du kit possèdent leurs propres digests et rapports.
Leur validation séparée ne rend pas la CI générale verte. Les bases de cette
chaîne doivent encore être corrigées et sa validation rejouée avant de promouvoir
ses images ou d’utiliser le workflow de release générale. La
[procédure de release](../../RELEASE.md) décrit le canal d’évaluation dédié.

## Portée de la décision

La conclusion de ce rapport est **zéro vulnérabilité connue détectée dans les
périmètres analysés du nouveau kit à la date du scan**. Elle doit accompagner
la provenance, les preuves fonctionnelles OpenShift et les limites du candidat.
Elle ne remplace pas un pentest, les contrôles de la banque, une recette de
restauration ou la qualification des procédures d’exploitation.

Tout changement de binaire, de frontend, de paquet système ou de base d’image
impose de nouveaux scans et une recette adaptée. Avant un transfert ultérieur,
rafraîchir la base de vulnérabilités et réévaluer le paquet exact à remettre.
