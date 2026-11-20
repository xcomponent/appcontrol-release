# Dossiers applicatifs et procédures versionnées

Le dossier **Préparation de la reprise**, accessible depuis l’accueil X4B,
App Explorer ou le menu d’une map AppControl, utilise les applications réelles
auxquelles le compte a accès. L’ouverture d’un dossier, la capture de son
architecture et la préparation d’un brouillon ne lancent aucune commande.

Le [catalogue de capacités](CAPABILITY-CATALOG.fr.md) permet également de
retrouver les procédures de l’application aux côtés des guides pour assistants
et des skills de discovery. Le lien **Skills et procédures** conserve le contexte
de l’application et du site depuis le dossier.

L’onglet **Préparer** relie maintenant les skills, les documents générés, les
commandes manquantes de la map et les missions de collecte dans le même dossier.
Voir le [parcours de boucle de connaissance](KNOWLEDGE-LOOP.fr.md), ses contrôles
de revue et les limites de chaque exécutant.

## Parcours

1. Ouvrir une application, puis consulter son architecture et sa Knowledge.
2. Créer une procédure : démarrage, secours, retour au nominal ou procédure
   personnalisée. Elle peut commencer par un texte et des étapes manuelles.
3. Choisir un site exact. Les opérations et affectations de ce site sont
   enregistrées dans un instantané immuable. Les commandes du site principal
   ne sont pas reprises par défaut sur un autre site.
4. Décrire les étapes, leurs composants, leurs prérequis, le résultat attendu
   et les notes d’exploitation. Enregistrer crée une nouvelle révision.
5. Soumettre à la revue. Une autre personne habilitée approuve la révision
   exacte après lecture du plan, des sources et du périmètre.
6. Adopter la référence documentaire séparément de son exécution. Documenter
   le motif de la revue humaine et les incertitudes. Les reçus des commandes
   classiques indiquent leur corrélation avec la demande. L’adoption relève
   d’une décision documentaire.
7. Exécuter les opérations natives prises en charge après autorisation
   explicite, ou exporter la skill et faire exécuter la procédure dans un
   système extérieur autorisé.
8. Examiner les résultats. Un import reste une preuve manuelle dont l’identité
   de la machine n’est pas authentifiée par le fichier.
9. Après revue explicite, intégrer les observations dans la Knowledge. Leur
   procédure, révision, site, date, empreinte et origine restent conservés.
10. Utiliser les sources sélectionnées et un objectif en texte libre pour
    proposer un nouveau brouillon avec l’IA. La référence et les retouches
    précédentes restent disponibles si le service ou sa réponse échoue.

## Versions, concurrence et preuves

Une procédure possède une identité stable et plusieurs révisions. Son texte,
ses notes, son plan, les sources retenues et l’architecture sont immuables dans
une révision. L’édition crée une nouvelle version, y compris lorsqu’elle part
d’une ancienne référence. Les approbations et adoptions sont tracées séparément.

Les écritures envoient la dernière révision ou référence attendue. Un conflit
renvoie HTTP 409 ; l’éditeur conserve la saisie afin de comparer les versions ou
de télécharger le brouillon. Une synchronisation des sources ne remplace pas
automatiquement le travail humain. Les révisions historiques lourdes sont
chargées à la demande pour limiter le volume du dossier.

Une preuve correspond à une procédure, une révision, un site et une empreinte
d’architecture exacts. Elle ne qualifie pas un autre scénario ou un autre site.
Une commande de démarrage acquittée ne constitue pas un contrôle de santé.
Les échecs et les interruptions restent consultables. Les preuves conservent un
snapshot et une empreinte ; elles ne reposent pas sur une ligne de log modifiable.

## Exécution native

Cette version exécute les actions déclaratives `check`, `start` et `stop` sur
les opérations AppControl déjà configurées et approuvées. Le Markdown et les
instructions de l’IA ne deviennent jamais des commandes shell.

Le plan exact est compilé avant l’approbation et l’exécution. Le précontrôle
refuse tout le parcours si une opération, une affectation ou un contrôle requis
manque. Un `start` exige un contrôle positif de disponibilité ; un `stop` exige
un `stop_check` explicite. Le plan respecte les dépendances pour le démarrage et
les dépendances inverses pour l’arrêt. Les délais et le nombre d’opérations sont
bornés ; le parcours cesse dès un échec.

Les étapes manuelles, les composants à plusieurs membres, les applications
imbriquées et les étapes de reconstruction ne sont pas exécutés par cet
adaptateur. Le dossier indique les blocages. Pour les reconstructions et
bascules, utiliser les parcours AppControl existants qui conservent leurs
contrôles d’intégrité, d’infrastructure et d’autorisation. La skill peut décrire
ces étapes pour une exécution externe ou manuelle.

Le lancement confirme le site de la révision. Un changement de sa configuration
effective exige une nouvelle revue. À l’envoi, AppControl vérifie les droits
et conserve la passerelle approuvée comme route de l’opération. Un changement
de route bloque l’envoi et la preuve consigne le périmètre de l’exécution. Le
verrou d’application couvre l’exécution et l’écriture des résultats.
Une maintenance repère les exécutions interrompues
sans inventer leur réussite ni relancer automatiquement une commande.

## Bascule contrôlée

Dans le panneau de bascule AppControl, choisir le mode **Contrôlé** pour une
bascule complète entre deux sites. À la phase de synchronisation, une seconde
personne habilitée renseigne le traitement externe, le point de restauration
constaté et le résultat du rapprochement. Avant la confirmation finale, elle
référence une transaction témoin et consigne le trafic observé sur le secours.
Chaque constat est rattaché à la bascule, à la phase et aux deux sites. Une
preuve absente ou un échec empêche la phase de se terminer.

Le mode contrôlé s’appuie sur les jobs et vérifications du client. X4B garde
la déclaration et l’identité du relecteur. La restauration des données et le
routage du trafic relèvent des procédures et outils du client. Le mode
technique reste disponible pour les parcours existants.

## Droits et intégration

- Lecture du dossier : droit `View`, organisation et sites autorisés.
- Création, révision, raffinement IA et import manuel : droit `Edit`.
- Approbation, adoption, exécution native et consolidation : droit `Manage`
  et session humaine. L’auteur ne peut pas approuver sa propre révision.
- Les clés API peuvent lire ou préparer selon leurs capacités `read` et
  `design` ; elles ne peuvent pas approuver ou déclencher ce parcours natif.

La Knowledge reste commune à une application. Lorsqu’une de ses révisions
contient des preuves de reprise d’un site inaccessible au compte, cette
révision entière reste masquée dans les lectures, l’historique et les
sélections pour l’IA. Le dossier signale cette restriction sans masquer les
procédures et preuves des sites autorisés.

Le connecteur IA de l’organisation est réutilisé, sans nouveau secret ou
nouveau fournisseur à configurer. L’appel transmet l’objectif, la procédure,
le contexte d’architecture et les sources explicitement choisies. Les valeurs
des commandes et des paramètres natifs sont retirées du contexte d’architecture
envoyé. Les documents sélectionnés restent des données du Client ; ne pas y
inclure de secrets inutiles à l’analyse.

## API et skill

Le Swagger expose le groupe `Procedures`. Les principales routes sont :

| Opération | Route après `/api/v1` |
| --- | --- |
| Dossier / création | `GET / POST /apps/{app}/procedures` |
| Nouvelle révision | `POST /apps/{app}/procedures/{procedure}/revisions` |
| Révision historique | `GET /apps/{app}/procedures/{procedure}/revisions/{revision}` |
| Revue | `POST .../{revision}/submit`, `.../return`, `.../approve` |
| Adoption | `POST .../{revision}/adopt` |
| Proposition IA | `POST .../{revision}/refine` |
| Export | `GET .../{revision}/skill` |
| Dossier de reprise hors ligne chiffré | `POST .../{revision}/offline-dossier` |
| Exécution native | `POST .../{revision}/runs` |
| Preuves et décisions de la révision | `GET .../{revision}/evidence?offset=0&limit=20` |
| Import manuel | `POST .../{revision}/evidence` |
| Consolidation revue | `POST .../{revision}/evidence/{evidence}/consolidate` |

L’export `SKILL.md` contient les identifiants, versions, empreintes, statut,
prérequis et notes d’exploitation. Il documente des opérations à raccorder et
ne donne aucun droit supplémentaire à l’exécutant. Il précise la route de
lecture de la révision et du plan exact ; les valeurs de commande ne sont pas
copiées dans le fichier Markdown. Leur accès exige les droits correspondants.

Pour préparer une indisponibilité de X4B, utiliser le [dossier hors ligne chiffré](OFFLINE-RECOVERY-DOSSIER.fr.md).

Un résultat manuel suit ce contrat (remplacer toutes les valeurs illustratives
par celles de la révision réellement exécutée) :

```json
{
  "application_id": "UUID de l’application",
  "procedure_id": "UUID de la procédure",
  "revision": 1,
  "site_id": "UUID du site",
  "architecture_hash": "SHA-256 de l’architecture figée",
  "plan_digest": "SHA-256 de la révision de procédure",
  "status": "passed",
  "collected_at": "2026-11-20T10:00:00Z",
  "results": {
    "observations": [
      {"step_id": "check-api", "target": "machine concernée", "result": "résultat observé", "evidence": "référence ou extrait"}
    ]
  }
}
```

Les statuts de preuve acceptés sont `passed`, `failed` et `inconclusive`.
L’API fixe toujours l’origine d’un import à `manual` et son identité à non
vérifiée. Les champs réservés à la collecte native sont refusés.

## Mise à jour

La migration additive V085 crée les tables de procédures, révisions, décisions,
exécutions et preuves sur PostgreSQL et SQLite. Elle ne déplace pas les maps,
agents, gateways, comptes ou réglages des connecteurs existants. Les instances
existantes commencent avec un dossier sans procédure ; aucun contenu fictif
n’est ajouté automatiquement.

Préparer la sauvegarde habituelle avant la mise à jour. Un retour à un ancien
binaire après utilisation de ces nouvelles fonctions exige de restaurer la
sauvegarde correspondante : les anciens lecteurs de Knowledge ne connaissent
pas l’origine `recovery` des nouvelles observations.

La maquette Atlas reste disponible uniquement dans l’entrée de prévisualisation
locale `procedure-preview.html`. Les données fictives et leur stockage navigateur
sont séparés du dossier réel `/x4b/recovery`.
