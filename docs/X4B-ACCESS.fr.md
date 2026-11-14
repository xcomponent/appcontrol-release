# Comptes et accès X4B

X4B réutilise les comptes locaux AppControl. L’administration des comptes attribue
les modules visibles et accessibles pour chaque personne. Les comptes existants
conservent leur accès AppControl jusqu’à la première modification explicite de
leurs accès. Un compte non administrateur créé dans X4B commence sans module.
Les droits sur les maps, les équipes et les opérations restent gérés dans AppControl.
La génération de maps est accessible aux administrateurs de l’organisation.

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
| `POST /api/v1/x4b/token` | Le serveur hôte vérifie l’état reçu puis envoie le JSON `{client_id,client_secret,code,code_verifier}`. Le code est valable une minute et s’utilise une seule fois. La réponse contient `session_token`, `expires_in` en secondes et `user` avec `user_id` et `email`. |
| `POST /api/v1/x4b/session` | Le serveur hôte envoie le JSON `{client_id,client_secret,session_token}`. X4B vérifie le compte, l’accès au module, l’expiration et la session X4B d’origine. La réponse contient `user` et `modules`. |
| `POST /api/v1/x4b/session/revoke` | Sur déconnexion explicite et protégée du site hôte, le serveur envoie les mêmes champs. X4B révoque la session d’origine et ses sessions associées. |

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
