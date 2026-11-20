# Discovery native par les agents installés

Ce mode réutilise le binaire agent, son identité, sa connexion à la gateway et les six collecteurs de Discovery disponibles. Le serveur prépare un plan, un administrateur approuve sa version précise, puis une action distincte demande son exécution. Aucun shell ni programme Python n’est lancé par ce parcours natif.

Le [guide fonctionnel](AGENTIC_DISCOVERY.md) décrit les skills, missions, deux modes d’exécution et la revue des connaissances. Le présent document décrit l’autorisation locale et les garanties du transport natif.

## Conditions requises

- Agent, gateway et backend compatibles avec le protocole Discovery natif. Un ancien agent ou une ancienne gateway reste utilisable pour ses fonctions habituelles ; il n’est pas considéré comme capable d’exécuter ces plans.
- Linux, avec le service agent sous un compte **non root**. Le mode `advisory` refuse ce nouveau parcours d’exécution. Le passer en mode actif ne suffit pas à autoriser la Discovery.
- Connexion agent–gateway en mTLS avec vérification du certificat serveur et identité d’agent enrôlée. Toutes les URL de gateway, y compris les routes de secours, doivent utiliser explicitement `wss://`. `TLS_INSECURE` ne convient pas à ce mode.
- Consentement local explicite, clé publique d’approbation dédiée épinglée sur la machine et limites locales.
- Répertoires d’installation autorisés localement pour les collecteurs qui les utilisent. Le compte du service doit pouvoir les lire sans élévation de privilèges.
- Répertoire de données de l’agent accessible en écriture par son compte, avec un sous-répertoire privé pour le registre de rejeu. Un registre indisponible entraîne un refus de collecte.

Une mise à jour du serveur ou une affectation de composant n’active pas ces réglages locaux. La configuration distante des commandes d’exploitation ne peut pas les modifier.

## Clé publique d’approbation

Le backend utilise une clé Ed25519 dédiée, configurée par l’exploitant avec `APPCONTROL_DISCOVERY_SIGNING_SEED`. La graine privée reste exclusivement côté serveur. Ne jamais réutiliser une clé JWT ou une clé d’API, ni copier cette graine sur les agents.

Un administrateur peut consulter les champs `signing_public_key` et `signing_key_id` de `GET /api/v1/discovery/agentic/capabilities`. Vérifier l’origine de cette clé et son identifiant par le canal d’administration convenu, puis installer explicitement la clé publique sur la machine. La présence d’une clé dans un message de plan ne la rend jamais fiable : l’agent vérifie toujours avec sa propre clé publique configurée localement.

Les approbations et les demandes d’exécution portent des signatures séparées. L’approbation lie l’utilisateur, sa décision et le plan exact. Le dispatch signé lie également l’exécution, la cible, l’identité de l’agent, la version du collecteur et une courte fenêtre de validité. Une empreinte de plan seule n’autorise aucune lecture.

## Configuration locale

Ajouter cette section au fichier YAML de l’agent, en conservant ses paramètres d’enrôlement, gateway et certificats :

```yaml
mode: active
discovery:
  enabled: true
  approval_public_key: "<clé publique Ed25519 : 64 caractères hexadécimaux>"
  allowed_installation_roots:
    - "/opt/tomcat"
    - "/srv/tomcat"
    - "/opt/jdk"
  max_duration_seconds: 120
  max_output_bytes: 100000
```

Les chemins sont des exemples. Remplacer les valeurs par les répertoires réellement autorisés. Une racine autorise ce répertoire et ses sous-répertoires, selon les composants de chemin ; `/opt/tomcat` n’autorise pas `/opt/tomcat-other`. Les racines globales `/`, les chemins relatifs et les segments `.` ou `..` sont refusés. Les collecteurs refusent les liens symboliques dans les chemins consultés.

Une liste de racines vide convient à une mission limitée aux processus et ports, dont les paramètres d’installation sont vides. Elle n’autorise aucune lecture d’installation Java ou Tomcat : chaque répertoire de ces collecteurs doit appartenir à une racine explicitement configurée.

Les limites du plan doivent être inférieures ou égales aux limites locales. Les plafonds techniques sont de 600 secondes et 500 000 octets de données pour la mission ; les sommes des limites des opérations et des cibles restent dans ce budget. Les valeurs locales par défaut sont 120 secondes et 100 000 octets. Le serveur vérifie aussi les limites par opération. Aucun paramètre de plan ne peut relever les plafonds locaux.

Les variables d’environnement suivantes remplacent les valeurs YAML au démarrage :

| Variable | Format |
| --- | --- |
| `APPCONTROL_DISCOVERY_ENABLED` | `true`, `false`, `1` ou `0` |
| `APPCONTROL_DISCOVERY_APPROVAL_PUBLIC_KEY` | Clé publique de 32 octets encodée en hexadécimal |
| `APPCONTROL_DISCOVERY_ALLOWED_ROOTS` | Tableau JSON de chemins, par exemple `["/opt/tomcat","/srv/tomcat","/opt/jdk"]` |
| `APPCONTROL_DISCOVERY_MAX_DURATION_SECONDS` | Entier entre 1 et 600 |
| `APPCONTROL_DISCOVERY_MAX_OUTPUT_BYTES` | Entier entre 1 024 et 500 000 |

Redémarrer le service agent après modification de cette politique. La réception d’une configuration de composant ou d’un SIGHUP ne constitue pas une activation de ces paramètres. Pour retirer le consentement, désactiver `discovery.enabled` puis redémarrer le service selon le parcours d’exploitation habituel.

## Capacités annoncées et mises à jour

L’agent annonce ses capacités après son enregistrement et les renouvelle toutes les 60 secondes, y compris lorsqu’il est désactivé. Elles comprennent son activation locale, ses collecteurs, son empreinte de runtime, les identifiants de clés publiques approuvées, ses limites et un éventuel motif d’indisponibilité.

La gateway transmet ces métadonnées et les résultats dans une enveloppe associée à la connexion mTLS effective. Elle ne prend pas l’identité ou l’empreinte de certificat annoncée dans un fichier JSON comme preuve. Le backend vérifie la gateway, le certificat associé à l’agent, son organisation, sa route et le dispatch enregistré.

Le plan épingle l’empreinte de l’implémentation native, pas seulement le nom des collecteurs. Après une mise à jour qui change cette empreinte, un ancien plan peut être refusé ; préparer et approuver une nouvelle version. Un agent dont les capacités sont absentes, périmées ou incompatibles est présenté comme indisponible pour ce mode. Il n’y a pas de repli implicite vers un shell ou vers l’ancien scan passif.

## Exécution bornée

Avant toute collecte, l’agent vérifie sa politique locale, le plan structuré, l’approbation et la demande signées, son identité cible, les répertoires autorisés, les limites et la fenêtre de validité. Il inscrit ensuite une réservation persistante de l’exécution et de la cible.

Les lectures ont lieu dans un processus enfant du **même binaire agent**, avec une entrée privée et structurée, sans environnement hérité du service. Il appelle les collecteurs Rust fixes. Le processus principal limite les sorties, surveille la durée, demande l’arrêt du processus enfant en cas de dépassement et le récupère. Sous Linux, le processus enfant demande aussi sa terminaison si son parent disparaît. Ce mécanisme n’est pas un nouveau service agent ni un système de sandboxing.

Les collecteurs ne lisent pas les environnements de processus, ne lancent pas de commande externe, ne font pas d’appel réseau et ne cherchent pas à obtenir des privilèges supplémentaires. Les fichiers sont bornés et les configurations sont résumées selon les champs autorisés. Cela ne remplace pas la revue des informations sensibles ; une lecture peut notamment modifier une date d’accès.

## Reconnexion, rejeu et annulation

Le registre persistant est privé au compte du service : répertoire Unix en `0700` et fichier en `0600`. Il conserve les réservations avant lancement, les résultats non acquittés et les preuves d’annulation. Une reconnexion ou la réception du même dispatch ne relance pas une collecte déjà réservée. Un arrêt entre la réservation et l’enregistrement du résultat laisse un état interrompu, qui doit être examiné sans répéter silencieusement l’exécution.

Les résultats non acquittés sont retransmis après reconnexion et lors des rafraîchissements périodiques. Un acquittement efface leur contenu en attente, pas la protection contre le rejeu. Le registre est borné à 256 réservations et 16 Mio de données sérialisées. Seules les réservations terminées, acquittées et sorties de leur fenêtre de sécurité sont purgées ; les résultats non acquittés et les situations ambiguës sont conservés. Si aucune purge sûre n’est possible, une nouvelle exécution est refusée. Un recul important de l’horloge locale provoque également un refus ; maintenir la synchronisation horaire.

Une annulation signée est liée au dispatch exact. L’agent conserve d’abord un marqueur empêchant un lancement tardif, puis demande l’arrêt du processus éventuellement en cours. Une confirmation positive n’est émise qu’après arrêt récupéré ou lorsqu’un lancement a été empêché. Une annulation demandée sans confirmation ne prouve pas que le processus a été arrêté. Une collecte déjà terminée reste dans l’historique.

Les accusés de réception d’annulation identifient aussi l’empreinte de la preuve reçue : l’accusé d’une réponse encore négative ne peut pas effacer une confirmation positive arrivée ensuite. Les preuves tardives sont conservées côté serveur sans transformer une exécution annulée en succès ni publier une map.

## Connaissance et recette

Le résultat du collecteur ne s’authentifie pas lui-même. L’attribution à l’agent est établie par le backend après ses contrôles de transport et de dispatch. Cette attribution ne garantit pas à elle seule la vérité de chaque information et ne remplace pas la validation humaine du contenu.

Les résultats restent soumis à une revue avant consolidation dans la Knowledge de l’application. La provenance, les anciennes valeurs validées et les conflits sont conservés. Aucune map n’est publiée et aucune commande d’exploitation n’est appliquée automatiquement.

La qualification automatisée utilise des plans, signatures, registres et fichiers de fixture, ainsi que des processus enfants de test qui attendent ou émettent des octets synthétiques. Elle ne constitue pas une collecte réelle sur la machine du développeur ou du client. Pour une recette réelle, autoriser explicitement la cible, configurer le consentement local, préparer et approuver un plan natif, demander son exécution puis vérifier ses preuves, la revue et la révision Knowledge produite.
