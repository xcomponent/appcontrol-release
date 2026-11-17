# X4B — Raccorder une application

X4B, édité par Invivoo, réunit AppControl, Génération de maps et les applications enregistrées. L’accueil est à `/x4b`. Le menu du compte donne accès à **Comptes et accès** et **Applications raccordées** pour les administrateurs. AppControl conserve ses liens directs, notamment `/apps/<id>`.

## Comptes et accès

L’administrateur réutilise les comptes locaux AppControl. Les comptes existants gardent leur accès AppControl après mise à jour. Les nouveaux comptes créés dans X4B reçoivent les accès choisis dans l’administration. La génération et la publication par lots restent réservées aux administrateurs dans cette version. Les autorisations AppControl sur les maps, les sites et les opérations s’appliquent en plus de l’accès au module.

Pour un POC avec un portail documentaire, créer un compte administrateur de revue et un compte de consultation. Donner à ce dernier accès au portail, puis un droit de lecture sur la map et les sites nécessaires, dont le site de simulation. Le compte peut ouvrir une simulation isolée. Les opérations sur une map réelle nécessitent les droits d’exploitation AppControl.

## Intégration d’un portail documentaire

1. Conserver les URL HTTPS du portail et d’AppControl. L’accueil X4B peut utiliser le même hôte qu’AppControl avec le chemin `/x4b`.
2. Dans **Applications raccordées**, enregistrer `documentation`. Pour l’hôte de référence, utiliser `https://documentation.example.test/` comme URL d’entrée et `https://documentation.example.test/x4b/callback` comme URL de retour, avec le domaine réel de l’hôte. Copier le secret affiché à la création dans le gestionnaire de secrets du serveur du portail.
3. Protéger les fiches et les API du portail avec la session X4B. Lors d’un accès direct, conserver le chemin de la fiche côté serveur, effectuer l’échange d’autorisation et revenir à ce chemin. Le serveur du portail vérifie aussi ses propres droits de consultation de fiche. Voir [le contrat d’accès](X4B-ACCESS.fr.md).
4. Ajouter les composants à la mise en page et à la fiche. Le serveur du portail expose les routes locales ci-dessous. Les données d’identité restent sur les canaux serveur à serveur.

```html
<script defer src="https://appcontrol.example.test/x4b-portal.js"></script>
<script defer src="https://appcontrol.example.test/appcontrol-embedded.js"></script>
<x4b-shell module="documentation" platform-url="https://appcontrol.example.test"></x4b-shell>
<appcontrol-status endpoint="/fiches/PAI-042/status"></appcontrol-status>
<appcontrol-map backend-url="https://appcontrol.example.test"></appcontrol-map>
```

| Route du portail | Appel serveur X4B/AppControl |
| --- | --- |
| `GET /x4b/session` | `POST /api/v1/x4b/session` retourne le compte, ses entrées de navigation et la préférence de langue. |
| `PUT /x4b/settings` | Le bandeau envoie `{"language":"fr"}` ou `{"language":"en"}`. Le portail vérifie l’origine et la session, puis appelle `POST /api/v1/x4b/session/settings` avec `client_id`, `client_secret`, `session_token` et `language`. Transmettre la réponse `{"language":"fr"}` ou `{"language":"en"}`. |
| `POST /x4b/logout` | `POST /api/v1/x4b/session/revoke` révoque la session partagée, puis le portail efface sa session locale. Vérifier l’origine du POST. |
| `GET /fiches/<id>/status` | `POST /api/v1/x4b/embedded/status` avec `credentials` et `source_id`. Renvoie l’état agrégé, la dernière observation et l’indicateur de fraîcheur. Une map absente ou non autorisée donne `404`. |
| `POST /fiches/<id>/simulation` | `POST /api/v1/x4b/embedded/simulation` avec les mêmes champs et éventuellement `simulation_site_id`. Affecter la réponse à la propriété JavaScript `session` du composant map. Vérifier l’origine du POST. |

`GET /x4b/session` renvoie au bandeau les champs `user`, `modules` et `settings` issus de
la réponse serveur X4B. Chaque entrée de `modules` contient `key`, `name` et
`entry_url`. X4B calcule la liste selon les droits du compte connecté. Le
bandeau ajoute **Catalogue** lorsque **AppControl** figure dans cette liste.

Le bandeau demande confirmation avant de déconnecter le compte. Après un `POST /x4b/logout` réussi, il dirige le navigateur vers la page de connexion X4B. La route de l'application hôte supprime sa session locale et révoque la session partagée. Si la révocation échoue, la route renvoie une erreur HTTP. L'application protège aussi ses propres pages et API.

Pour les deux routes Embedded, `credentials` contient `client_id`, `client_secret` et `session_token`. La source de la map est résolue par `source_reference.system` égal à la clé du module et `source_reference.id` égal à l’identifiant de la fiche. La configuration [AppControl Embedded](EMBEDDED.fr.md) déclare en plus l’origine du portail et le site de simulation. Le jeton de simulation reste court et suit la validité de la session X4B qui l’a demandé.

Pour les maps générées depuis une source documentaire externe, renseigner `documentation` comme nom de source dans **Génération de maps → Paramètres**, ou définir `X4B_KNOWLEDGE_SOURCE=documentation` lors du déploiement. L’`application_key` exposée par le connecteur doit correspondre à l’identifiant utilisé sur la fiche, par exemple `PAI-042`.

Le badge actualise les données toutes les 15 secondes quand la page est visible. Autoriser l’hôte AppControl dans `script-src`, `style-src` et `frame-src` du portail. Le navigateur interroge les routes du portail sous sa propre origine.

L’hôte de référence `demo-rebuild/embedded/x4b_host.py` contient deux fiches fictives, dont `PAI-042`. Il est livré dans l’archive [demo-rebuild.tar.gz de la release](https://github.com/xcomponent/appcontrol-release/releases/download/v1.24.1/demo-rebuild.tar.gz). Le placer derrière un proxy HTTPS qui transmet le `Host` public. Configurer `X4B_URL=https://appcontrol.example.test`, `X4B_HOST_ORIGIN=https://documentation.example.test` et `X4B_MODULE_KEY=documentation` avec les valeurs de l’installation, puis injecter le secret client dans `X4B_CLIENT_SECRET`. Si plusieurs sites de simulation sont configurés, préciser `X4B_SIMULATION_SITE_ID`. L’hôte écoute en boucle locale sur le port `8081` par défaut. Le modèle de production doit s’appuyer sur les sessions du framework du portail et vérifier les droits de chaque fiche.

Si le certificat de X4B est signé par une autorité interne, configurer `X4B_CA_FILE` avec la chaîne de confiance PEM sur le serveur de l’hôte de référence. Le navigateur doit lui aussi faire confiance à l’autorité utilisée par les deux sites.

### Langue du bandeau et de l’application hôte

Le bandeau utilise la préférence `settings.language` du compte X4B dès qu’il
reçoit la session. En l’absence de préférence, il utilise la langue déclarée
dans l’attribut `lang` de la page hôte si elle est prise en charge, puis celle du
navigateur. Le sélecteur change la langue du bandeau et enregistre le choix sur le
compte pour les applications raccordées. Si la route locale porte un autre nom,
indiquez son chemin de même origine dans l’attribut `settings-endpoint` de
`<x4b-shell>`. Les identifiants et secrets de l’échange restent côté serveur.

L’application hôte peut réutiliser son mécanisme de traduction en écoutant
l’événement `x4b-language-change`. Le bandeau fournit `event.detail.language`
à l’initialisation et lors des changements. La propriété en lecture seule
`shell.language` permet de récupérer la valeur si le script est chargé après
l’initialisation. Appliquez la valeur à vos propres traductions, puis mettez à
jour la langue déclarée pour la page.

```js
const shell = document.querySelector('x4b-shell');
function applyLanguage(language) {
  setApplicationLanguage(language);
  document.documentElement.lang = language;
}
shell?.addEventListener('x4b-language-change', (event) => {
  applyLanguage(event.detail.language);
});
if (shell?.language) applyLanguage(shell.language);
```

## Catalogue complet et génération

Le catalogue appartient à AppControl. Les entrées acceptent `match_terms` (ou `keys` sur les exports existants). Le kit Windows envoie les entrées par lots. Chaque lot respecte les limites de la requête, sans plafond total sur le catalogue configuré. Pour enrichir une entrée déjà importée, utiliser le mode `upsert` de l’API catalogue avec une prévisualisation `dry_run` puis l’`expected_digest` obtenu. Le kit Windows conserve le mode ajout pour préserver les entrées existantes.

Quand le catalogue est renseigné, X4B demande d’abord à l’IA du client les termes observés dans le document. X4B recherche ces termes dans toutes les entrées du catalogue. Le second appel utilise la même révision du document et reçoit les candidats par composant. Les commandes et variables du catalogue ne sont pas envoyées au moteur de génération. La revue indique les rapprochements ambigus et inconnus, avec les candidats trouvés. Ces propositions nécessitent une confirmation individuelle. Une modification du catalogue rend caduques les propositions fondées sur son état antérieur.

Pour les ordonnanceurs, indiquez dans les sources le produit et le rôle précis de la brique, par exemple **Control-M Agent**. Le rapprochement reconnaît aussi les variantes du nom de produit, comme **VTOM** et **Visual TOM**. Lorsque le document nomme le produit et que le catalogue ne contient qu’une variante, X4B peut la suggérer pour confirmation. Le rôle d’ordonnancement aide à organiser le graphe. Les liens restent fondés sur les flux et prérequis documentés.

Dans l’aperçu, utilisez **Organiser automatiquement** pour disposer les prérequis et les composants qui en dépendent. Vous pouvez aussi déplacer les composants à la souris et enregistrer leur disposition dans la proposition avant de la publier.

Lors de la première publication, le site primaire sert de site par défaut pour les composants dont le site reste à déterminer. L’assistant propose un agent lorsqu’il trouve une correspondance unique ou un seul agent éligible. Si vous choisissez un site secondaire, renseignez les agents de chaque composant sur les deux sites. La publication enregistre un profil de secours inactif. Les commandes et les conditions de bascule restent à vérifier avant utilisation.

Le contrat [Knowledge Engine](KNOWLEDGE-ENGINE-CONNECTOR.fr.md) est conservé. Le point de terminaison `prompt-executions` doit pouvoir appliquer le prompt reçu, y compris quand le résultat demandé est un inventaire de composants. Le moteur de génération reste celui du client.
