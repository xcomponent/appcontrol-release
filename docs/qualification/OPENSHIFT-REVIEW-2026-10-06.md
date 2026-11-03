# Qualification du livrable — état au 7 octobre 2026

Objectif : conserver les évolutions de démonstration et fournir une installation cliente reproductible, avec preuves de fonctionnement et de sécurité.

## État des preuves

- Sauvegarde locale du dépôt, de l'historique Git et des médias effectuée avant modifications.
- Cluster local isolé k3d/Kubernetes 1.35.5 démarré ; aucun contexte Kubernetes existant modifié.
- Test réel du transport HTTPS backend réussi : certificat serveur vérifié, identité cliente requise hors sondes GET /health et /ready, en-tête d'identité falsifié refusé.
- Compilation de contrôle agent et gateway réussie après corrections.
- Rendu Helm des transports TLS et lint réussis.
- Installation des quatre services réussie sur Kubernetes local, admission Pod Security `restricted`, UID arbitraire `1000760000`, racines en lecture seule et comptes de service non montés.
- Seconde installation entièrement neuve depuis le paquet exporté, dans un namespace et une base distincts : bootstrap et les neuf contrôles fonctionnels réussis à nouveau.
- Scénario réel réussi : connexion HTTPS vérifiée, refus anonyme, enrôlement agent avec CA vérifiée, clé de lecture refusée pour start, démarrage/arrêt de deux composants dans l'ordre, reconnexion après redémarrage gateway, persistance après redémarrages backend et PostgreSQL.
- Les commandes synthétiques créent/suppriment réellement des marqueurs et vérifient la présence/absence de leur dépendance. Ce résultat ne constitue pas une qualification des commandes métier d'un client.
- Trivy 0.75.0 : zéro CVE détectée sur les cinq images exactes et les fichiers de verrouillage Rust/JavaScript au 7 octobre 2026 ; un SBOM CycloneDX par image. L'absence de CVE détectée n'est pas une preuve d'absence de faille applicative.
- CI du commit `a5d6023` : Rust/PostgreSQL, Clippy, SQLite, frontend, Windows et scénarios complets standalone réussis. OpenShift réel a échoué avant déploiement : jeton sandbox invalide ou expiré. Nouvelle qualification Kubernetes automatisée ajoutée, résultat à suivre séparément.
- OpenShift réel : NON TESTÉ. Le cluster local ne valide ni l'admission SCC OpenShift ni le routeur OpenShift.

## Défauts constatés et corrections en cours

| Sujet | Défaut initial | Correction |
|---|---|---|
| Enrôlement agent | Vérification serveur toujours désactivée, configuration persistée non sûre | Vérification par défaut ; ENROLLMENT_CA_FILE pour PKI interne ; dérogation de développement explicite, interdite avec APP_ENV=production |
| Identité agent | Empreinte de certificat acceptée via un en-tête HTTP | Identité issue uniquement du transport TLS |
| Transport backend | HTTP uniquement ; gateway→backend non chiffré dans Helm | HTTPS natif et authentification TLS cliente, sans proxy supplémentaire |
| Proxy d'enrôlement | N'utilisait pas la PKI du lien gateway→backend | Même CA et identité cliente pour HTTP et WebSocket |
| Isolation réseau | Règle Prometheus ouvrait tout le port backend | Sources de supervision explicites ; règle absente par défaut |
| PostgreSQL | Pas d'isolation des entrées | Accès limité au backend |
| Identité gateway | Identifiant par défaut partagé entre installations | Identifiant stable propre au namespace et à la release |
| Installation | Deux instances frontend/gateway inutiles pour la démo | Un exemplaire de chacun, un backend, une base ; base externe possible |
| Base intégrée | Activation PostgreSQL sans DATABASE_URL backend | Secret commun comportant database-url, ou URL construite si mot de passe explicite |
| OpenShift | Écritures PostgreSQL dans /var/run et /tmp | Volumes temporaires dédiés ; UID non imposé par le chart |
| Premier démarrage | Les migrations peuvent dépasser le délai de vivacité | Sonde de démarrage distincte avant activation de la surveillance de vivacité |
| Droits d'installation | Administration du namespace demandée même si le projet existe | Création du namespace uniquement sur option explicite ou en mode local |
| Dépendances | CVE dans les dépendances web et l'outil gosu de l'image PostgreSQL | Dépendances mises à jour ; image PostgreSQL non-root sans gosu inutilisé |

## Limites à maintenir visibles

Le backend reste mono-instance : ce travail ne crée pas une haute disponibilité applicative. Une mise à jour requiert une fenêtre de maintenance. Les jetons de gateway expirent et doivent être renouvelés avant échéance. La base fournie pour essai ne remplace pas la politique cliente de sauvegarde, restauration et exploitation PostgreSQL. Les résultats CVE doivent porter sur les images effectivement livrées, avec leur digest et la date du scanner.

Références : [images OpenShift et UID arbitraires](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/images/creating-images), [image PostgreSQL officielle](https://github.com/docker-library/docs/blob/master/postgres/README.md).
