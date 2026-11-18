# Comptes et accès X4B

X4B réutilise les comptes locaux AppControl. L’administration des comptes attribue
les modules visibles et accessibles pour chaque personne. Les comptes existants
conservent leur accès AppControl jusqu’à la première modification explicite de
leurs accès. Un compte non administrateur créé dans X4B commence sans module.
Les droits opérationnels sur les maps et les équipes restent gérés dans AppControl.
Le module **Map Builder** est inclus pour les administrateurs et peut être accordé
aux autres comptes. Son accès ne donne pas accès à tout le portefeuille : chaque
dossier de cartographie conserve son propre périmètre d’équipe.

Pour accorder le module à un compte non administrateur, ouvrez **Comptes et accès**,
choisissez **Accès aux applications** sur ce compte, cochez **Map Builder**, puis
enregistrez. Cette opération rend le module disponible ; elle ne fait pas de ce compte
un gestionnaire de portefeuille et ne lui attribue aucun dossier.

## Accès au Map Builder et distribution des dossiers

Une synchronisation documentaire crée d’abord un **dossier de cartographie** pour
la source et la clé applicative. Ce dossier existe avant la map AppControl et reste
le même au fil des générations et des updates. Les réglages du connecteur, le test
de connexion et la synchronisation globale restent réservés aux administrateurs.
Le travail de construction et de revue peut être délégué sans donner de rôle
d’administration de la plateforme.

L’administrateur peut désigner des **gestionnaires de portefeuille**, directement
ou par équipe. Ils voient les vues **À répartir** et **Portefeuille**, affectent un
dossier ou un lot, et peuvent modifier une affectation. Cette délégation concerne
uniquement la distribution des dossiers ; elle n’accorde aucun accès opérationnel
aux maps publiées.

Dans **Map Builder**, l’administrateur ouvre **Gestionnaires du portefeuille**, choisit
**Une équipe** ou **Un utilisateur**, puis clique sur **Ajouter le gestionnaire**. Le
retrait de cette délégation ferme la vue transverse, mais ne modifie ni les dossiers
déjà affectés à ses équipes ni les permissions des maps AppControl.

Pour chaque dossier, l’affectation comprend :

- une **équipe responsable** unique, qui porte la création ou l’update ;
- un **référent** facultatif, choisi parmi les membres de cette équipe ;
- des équipes **contributrices**, autorisées à modifier la proposition ;
- des équipes **relectrices**, autorisées à consulter la proposition pour relecture ;
- une priorité et, si nécessaire, une date cible.

Le lead de l’équipe responsable ou le référent nommé accepte l’affectation. Si
l’équipe ne peut pas prendre le dossier, elle le renvoie dans **À répartir** avec un
motif. Le gestionnaire peut aussi le réaffecter à une autre équipe. Ces actions et
leurs auteurs sont audités. Les vues sont filtrées : un utilisateur ordinaire voit
les dossiers accordés à ses équipes dans **Mon équipe**, tandis que la file sans
responsable et la vue transverse restent limitées aux gestionnaires et administrateurs.
L’affectation, l’acceptation, le retour et le changement d’avancement demandent une
session utilisateur ; une clé API ne peut pas prendre ces décisions de gouvernance.

Le statut d’avancement — **À répartir**, **Affecté**, **Pris en charge**, **En cours**,
**En révision**, **Prêt à publier**, **Publié** ou **Bloqué** — est distinct de l’état
technique de l’IA et de la synchronisation. Cette séparation permet par exemple de
conserver un dossier en révision même si sa génération est terminée, ou d’indiquer un
blocage métier sans masquer l’état technique.

### Séparer collaboration et exploitation

Les niveaux `view`, `edit` et `manage` d’un dossier sont des droits de collaboration
propres au Map Builder. Ils ne correspondent pas aux permissions de même nom dans la
hiérarchie opérationnelle AppControl, où `edit` et `manage` incluent notamment
`operate`. Le tableau suivant résume cette séparation.

| Droit sur le dossier | Capacité dans le Map Builder | Ce qu’il ne donne pas |
| --- | --- | --- |
| `view` | Consulter la proposition pour relecture. | Aucune commande sur la map. |
| `edit` | Modifier et affiner la proposition. | Ni Start, ni Stop, ni Reconstruction. |
| `manage` | Piloter le dossier et publier lorsque les contrôles sont satisfaits. | Aucun droit d’exploitation implicite. |
| Gestionnaire de portefeuille | Affecter ou transférer les dossiers du portefeuille. | Aucun accès implicite aux applications publiées. |

À la première publication, son auteur et les équipes associées au dossier reçoivent un
accès de consultation à la map. Lorsqu’une map déjà publiée est réaffectée, les nouvelles
équipes reçoivent aussi cet accès. La synchronisation est additive : elle ne retire ni ne
réduit les droits applicatifs existants, car ceux-ci peuvent avoir été accordés ou élevés
explicitement. Accordez ensuite dans AppControl toute permission plus élevée nécessaire.
L’affectation d’un dossier ne doit jamais produire
automatiquement `operate`. Les restrictions de workspace et de site, ainsi que les
passerelles et agents choisis, sont contrôlées séparément au moment de la publication.

L’accès au module et l’accès aux données sont également distincts. Accorder le module
**Map Builder** permet d’ouvrir l’outil, mais n’expose pas les dossiers des autres
équipes. À l’inverse, l’accès à un dossier rend le Map Builder disponible pour ce
travail sans donner accès à la configuration globale du connecteur.

Quand la source d’une map publiée évolue, l’update revient dans le même dossier et à
la même équipe responsable avec le statut **Affecté** ; elle doit reprendre le dossier
avant sa revue. Si cette équipe n’existe plus ou si aucun responsable
valide ne subsiste, le dossier rejoint **À répartir**. La map publiée et ses droits
AppControl restent inchangés jusqu’à la publication explicite de l’update.

## Raccorder une application externe

1. Enregistrez son identifiant, son nom, son URL d’entrée et son URL de retour dans
   l’administration X4B. Les deux URL doivent utiliser la même origine HTTPS.
   X4B présente le secret client une seule fois. Conservez-le côté serveur, par
   exemple dans un Secret OpenShift, et configurez le serveur hôte avec l’URL
   publique de X4B. Pour l’hôte de référence, l’URL d’entrée est
   `https://documentation.example.test/` et l’URL de retour est
   `https://documentation.example.test/x4b/callback`. Remplacez le domaine par celui
   de votre hôte.
2. Accordez l’accès à une personne dans « Comptes et accès ». Cet accord couvre
   uniquement le module. Ajoutez les droits AppControl sur les maps qui doivent
   apparaître dans la fiche de l’application externe.
3. Vérifiez le lien direct vers une fiche, les accès refusés, le retour à la fiche
   après connexion et la déconnexion. Protégez les pages et les API du module
   externe avec son adaptateur, y compris lorsqu’elles sont ouvertes directement.

Utilisez l’identifiant du module comme système de référence des maps pour le badge
et la simulation. Un module enregistré sous `documentation` utilise donc des
références `{ "system": "documentation", "id": "PAI-042" }`.

## Protocole côté serveur

Le serveur hôte crée un état aléatoire et un vérificateur PKCE uniques pour
chaque tentative. Il conserve ces valeurs et le chemin de retour local dans la
session temporaire du navigateur. Le chemin de retour doit être validé comme
chemin de la même origine.

| Appel | Comportement |
| --- | --- |
| `GET /api/v1/x4b/authorize?client_id=…&state=…&code_challenge=…` | Le navigateur présente sa session X4B. X4B vérifie le compte et l’accès au module puis renvoie un code et l’état à l’URL de retour enregistrée. La méthode de défi est S256. |
| `POST /api/v1/x4b/token` | Le serveur hôte vérifie l’état reçu puis envoie le JSON `{client_id,client_secret,code,code_verifier}`. Le code est valable une minute et s’utilise une seule fois. La réponse contient `session_token`, `expires_in` en secondes, `user` avec `user_id` et `email`, ainsi que `settings`. |
| `POST /api/v1/x4b/session` | Le serveur hôte envoie le JSON `{client_id,client_secret,session_token}`. X4B vérifie le compte, l’accès au module, l’expiration et la session X4B d’origine. La réponse contient `user`, `modules` et `settings`. |
| `POST /api/v1/x4b/session/settings` | Le serveur hôte ajoute `language` aux champs de la requête de session. X4B effectue les mêmes vérifications, enregistre la préférence de langue sur le compte et retourne `{"language":"fr"}` ou `{"language":"en"}`. |
| `POST /api/v1/x4b/session/revoke` | Sur déconnexion explicite et protégée du site hôte, le serveur envoie les mêmes champs. X4B révoque la session d’origine et ses sessions associées. |

Dans les réponses d’échange et de session, `settings.language` vaut `fr` ou
`en` si le compte a enregistré une préférence. Le champ est absent tant
qu’aucune langue n’a été enregistrée. Le [guide du bandeau](X4B-PLATEFORME.fr.md#langue-du-bandeau-et-de-lapplication-hôte)
décrit les routes à exposer sur le portail hôte pour partager cette préférence.

Les chemins relatifs des modules natifs se résolvent par rapport à l’URL publique
de X4B configurée sur le serveur hôte. L’accueil X4B et les modules natifs
partagent cette origine. Les modules externes gardent leur
propre origine. L’adaptateur garde le secret et le jeton de
session côté serveur et utilise une session hôte distincte. Les jetons de
simulation Embedded gardent leurs droits et leur durée propres.

Sur une navigation depuis un autre site, le cookie X4B peut être absent de la
première requête. Dans ce cas, X4B ouvre son écran de connexion puis reprend
l’autorisation depuis sa propre origine. Le navigateur revient ensuite à la fiche
conservée par l’adaptateur.

Pour retirer un module, supprimez son inscription. Cette opération révoque ses
accès et sessions. Pour le raccorder de nouveau, enregistrez-le et configurez le
nouveau secret côté serveur.
