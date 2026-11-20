# Catalogue de capacités : skills et procédures

**Accueil → Connaissance → Catalogue de capacités**, ou **IA → Skills et
procédures**, ouvre le catalogue commun. Il réunit les guides livrés avec X4B,
les skills de discovery de l’organisation et les procédures versionnées d’une
application. Les données restent dans leurs catalogues et dossiers d’origine.

## Choisir une capacité

Rechercher par nom ou objectif, puis filtrer par fonction : connaissance
documentaire, cartographie, discovery, démarrage et reprise, intégration et
administration. Chaque fiche présente ses entrées, ses sorties, ses associations,
sa version et son statut.

Les trois types d’entrée ont des usages distincts :

| Type | Version et statut | Utilisation |
| --- | --- | --- |
| Guide pour assistant | Empreinte SHA-256 du fichier et de ses références ; guide distribué | Télécharger le SKILL.md pour un assistant externe et ouvrir le parcours associé s’il est disponible. |
| Skill de discovery | Version et validation conservées par l’organisation | Ouvrir son Markdown, configurer un agent réutilisable ou préparer une mission. |
| Procédure applicative | Révision, statut de revue et référence documentaire | Ouvrir la révision exacte dans le dossier de reprise, examiner le dernier brouillon ou exporter la skill avec les droits requis. |

Un guide distribué n’est pas une procédure approuvée pour une application. Une
empreinte identifie un contenu ; elle n’autorise aucune exécution.

## Conserver le contexte

Depuis une fiche applicative, le menu d’une map ou le dossier de reprise,
**Skills et procédures** ouvre le catalogue avec cette application. Depuis la
fiche d’une brique, le lien conserve sa clé de type.

Dans le catalogue, sélectionner une application charge son dossier autorisé et
ajoute ses procédures. Les skills génériques restent disponibles. Les skills
liées explicitement à une autre application sont écartées ; les associations aux
briques et aux agents servent à retrouver les skills pertinentes.

La sélection, la recherche, les filtres et la fiche ouverte sont portés par
l’URL. Les liens de discovery reprennent les cibles choisies. Préparer une
mission depuis une skill exige de sélectionner un profil réutilisable qui la
contient. Le catalogue ne crée pas d’agent installé et ne lance aucune commande.

Une procédure conserve sa référence et son dernier brouillon distincts. Le
catalogue ouvre la référence accessible en priorité et propose le dernier
brouillon séparément. Le dossier de reprise reste l’atelier de création,
d’édition, d’approbation et de vérification.

## Droits et disponibilité

- Les guides livrés restent accessibles aux comptes disposant d’un module
  natif X4B. Leurs téléchargements et l’URL de flux `/skills/` sont conservés.
- Les skills et missions de discovery suivent l’accès administrateur existant.
- Les procédures suivent les droits d’application, d’organisation et de site
  contrôlés par l’API existante. L’export exige le droit `Edit`.
- Le téléchargement d’un guide ou d’une skill ne donne aucun droit d’exécution.
  Le choix des cibles, la revue et l’autorisation restent dans les ateliers.

Le flux `/skills/` contient uniquement les guides distribués avec le Produit.
Les skills propres à l’organisation et les procédures applicatives restent dans
les API authentifiées ; elles ne sont pas ajoutées à ce flux public.

Une source indisponible est signalée sans supprimer les guides ni les autres
sources disponibles. Une réponse d’accès refusé masque les données privées
précédemment chargées. Changer de compte ou d’organisation ne reprend pas les
données privées du compte précédent.

Si le manifeste des guides est indisponible, leur empreinte est indiquée comme
indisponible ; aucune version fictive n’est affichée. Les liens historiques
`/x4b/agents#skills` et `/x4b/agents#skill-…` rejoignent le catalogue commun.

## Installation existante

Cette évolution réutilise les API, les skills, les procédures et les réglages
existants. Elle n’ajoute ni migration de données ni secret de connexion. Les
parcours d’installation, d’intégration et d’exécution restent ceux de la version
installée.

Voir aussi [les procédures versionnées et leurs preuves](APPLICATION-PROCEDURES.fr.md).
