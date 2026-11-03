# Sécurité : images, dépendances applicatives et outils de build

Un scan des paquets Linux des images ne suffit pas à qualifier les bibliothèques
Rust liées dans les exécutables ou les modules intégrés dans le JavaScript.
Le premier bilan « zéro CVE » des images ne couvrait donc pas toutes ces couches.
Les paquets intermédiaires ont été marqués comme non distribuables.

## Contrôles distincts

- **Images exactes :** scan des archives OCI, identification par digest, SBOM,
  contrôle SHA-256 après export. Tout changement d'image impose un nouveau scan.
- **Dépendances de production :** Cargo.lock avec les manifestes de tous les
  crates, et package-lock.json du frontend. Ces sources doivent correspondre à
  la compilation des binaires et du frontend livrés.
- **Outils de développement :** second scan avec `--include-dev-deps`, conservé
  même si ses résultats ne sont pas présents dans les images d'exécution.

La CI ajoute le contrôle Trivy des manifestes à RustSec. Elle bloque sur toute
alerte de production et sur toute alerte critique de développement. Le rapport
complet reste disponible : les autres sévérités de développement ne sont pas
supprimées ni présentées comme corrigées.

## Corrections appliquées

Le scan étendu initial identifiait 43 alertes : trois Rust et quarante npm.
Les mises à jour portent notamment sur jsonwebtoken 10.4.0, rand 0.8.6,
rustls 0.23.45, Vitest 4.1.11 et les correctifs compatibles des outils frontend.
La validation JWT vérifie aussi le champ optionnel `nbf` et un test couvre son
absence de validité temporelle ou son type incorrect. Voir l'[avis de
jsonwebtoken](https://github.com/Keats/jsonwebtoken/security/advisories/GHSA-h395-gr6q-cpjc).

Après ces mises à jour, le scan complet des manifestes indique **zéro alerte
Rust et zéro alerte npm de production**, avec **deux alertes de développement
restantes**. Ce résultat ne remplace ni un pentest ni le scan de la banque.
Les rapports du paquet final font foi pour les versions exactes et la date.

## Deux alertes restantes, sans exclusion

| Dépendance | Avis | Sévérité | Périmètre et suite |
|---|---|---|---|
| braces 3.0.3 | CVE-2026-93687 | Haute | Analyse de motifs lors du build CSS ; aucune version corrigée indiquée dans le scan. Évolution de la chaîne Tailwind à qualifier séparément. |
| postcss-selector-parser 6.1.4 | CVE-2026-104844 | Moyenne | Analyse CSS lors du build ; correction annoncée en 7.1.6, hors plage majeure de la chaîne actuelle. Migration de la chaîne CSS et non simple remplacement aveugle. |

Ces deux paquets sont transitifs de la chaîne de compilation CSS. Le frontend
livré contient les fichiers statiques compilés et nginx, pas Node, Tailwind ou
son compilateur. L'application ne propose pas un service de compilation CSS
pour les entrées des utilisateurs. La CI doit compiler uniquement les sources
revues du dépôt ; il reste nécessaire de qualifier la migration des outils CSS.
Les avis restent visibles dans le rapport complet, y compris leur sévérité.

La banque n'a pas besoin de cette chaîne de compilation pour installer les
images ou reconditionner les exécutables déjà compilés dans une base approuvée.
Si elle impose une reconstruction du frontend depuis les sources ou une règle
zéro alerte sur tous les outils de développement, ces deux points doivent être
résolus avant ce mode de livraison.
