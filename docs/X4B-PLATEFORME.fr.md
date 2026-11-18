# X4B — Raccorder une application

X4B, édité par Invivoo, organise l’accueil `/x4b` en trois colonnes. Dans **Connaissance** (Knowledge Collect & Store, KCS), **Sources de connaissance** (CapabilityCatalog) donne accès aux réglages documentaires et aux ressources, dont le catalogue de composants. **Transformation** (Knowledge Transform & Refine, KTR) ouvre l’**Atelier de cartographie** (AppGraphGen) pour générer, affiner et publier les propositions. **Exploitation** (Knowledge Graph & Act, KGA) donne accès à **App Explorer** (AppExplore) pour consulter les fiches des applications accessibles et à **AppControl** pour exploiter leurs cartes. Le menu du compte donne aux administrateurs accès à **Comptes et accès** et **Applications raccordées**. Les liens directs, notamment `/map-generation` et `/apps/<id>`, restent valides.

Le bandeau donne accès au **Service d’IA**, à **Agents IA** et à **Intégrations** selon les droits de l’utilisateur. L’espace Intégrations présente un aperçu du bandeau, de la carte embarquée et du badge d’état. L’écran **Agents IA** regroupe les skills à télécharger et l’adresse du catalogue.

## Travailler avec un assistant externe

Sans MCP, téléchargez les fichiers du skill depuis **Agents IA**. Dans le
projet, placez-les dans `.agents/skills/<nom-du-skill>/` pour Kilo Code
ou dans `.claude/skills/<nom-du-skill>/` pour Claude Code. Placez `SKILL.md`
à la racine du dossier du skill et les fichiers complémentaires dans
`references/`. Kilo Code peut également télécharger ces fichiers depuis
le catalogue configuré dans `skills.urls`. [Skills dans Claude Code](https://code.claude.com/docs/en/skills)

Le skill `appcontrol-map-from-repository` fournit le schéma JSON AppControl
et un exemple importable. Demandez à l’assistant de construire `map.json`
dans le dépôt ouvert et de relever les preuves des composants et des
dépendances dans une note. La création et la validation par le schéma
peuvent se faire sans connexion à AppControl. L’instance cible vérifie
ensuite les règles du contrat avant la revue des affectations.

Les skills de cartographie guident la validation du JSON, la vérification des
affectations et la recette sur une cible de test. Le skill
`appcontrol-deployment-verification` couvre l’installation ou la mise à jour,
la disponibilité du backend et de l’interface, la reconnexion des agents et
la reprise des intégrations. Pour exécuter ces contrôles, l’assistant utilise
les accès AppControl et les outils d’administration disponibles dans
l’environnement cible. Il rend compte des vérifications effectuées et de
celles qui restent à réaliser.

Pour utiliser MCP, installez le binaire `appcontrol-mcp` sur le poste qui
exécute Kilo Code. Préparez la configuration locale dans **Agents IA**.
L’exécutable lit `APPCONTROL_API_KEY` dans l’environnement du processus.
Créez une clé dédiée dans **Clés API**, limitée à l’application et au droit
requis. La lecture suffit au premier essai. La conception permet de
préparer une proposition pour revue. Installez la configuration dans Kilo
Code et activez le connecteur dans ses paramètres MCP. Pour couper l’accès
de cet assistant à AppControl, révoquez sa clé dédiée.
[Configuration MCP dans Kilo Code](https://kilo.ai/docs/automate/mcp/using-in-kilo-code) · [Découverte des skills](https://kilo.ai/docs/customize/skills)

## Comptes et accès

L’administrateur réutilise les comptes locaux AppControl. Les comptes existants gardent leur accès AppControl après mise à jour. L’accès à l’Atelier, l’affectation d’un dossier et les droits sur une carte publiée sont distincts. Les équipes autorisées peuvent travailler sur un dossier et le faire passer en revue. La synchronisation de la source et la publication par lots restent réservées aux administrateurs. Un dossier hérité peut suivre le parcours de publication administrateur jusqu’à sa première affectation. Les autorisations AppControl sur les cartes et leurs sites s’appliquent aux cartes déjà publiées. [Droits et affectations X4B](X4B-ACCESS.fr.md)

Pour un POC avec un portail documentaire, créer un compte administrateur de revue et un compte de consultation. Donner à ce dernier accès au portail, puis un droit de lecture sur la map et les sites nécessaires, dont le site de simulation. Le compte peut ouvrir une simulation isolée. Les opérations sur une map réelle nécessitent les droits d’exploitation AppControl.

## Intégration d’un portail documentaire

1. Conserver les URL HTTPS du portail et d’AppControl. L’accueil X4B peut utiliser le même hôte qu’AppControl avec le chemin `/x4b`.
2. Dans **Applications raccordées**, enregistrer `documentation` et choisir son **Pilier de l’accueil**. Le placement est modifiable sans recréer l’application. Les applications précédemment raccordées figurent dans **Exploitation** par défaut. Pour l’hôte de référence, utiliser `https://documentation.example.test/` comme URL d’entrée et `https://documentation.example.test/x4b/callback` comme URL de retour, avec le domaine réel de l’hôte. Copier le secret affiché à la création dans le gestionnaire de secrets du serveur du portail.
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
bandeau ajoute **Connaissance** lorsque le compte dispose d’AppControl ou de
l’Atelier de cartographie, et **App Explorer** lorsque le compte dispose d’AppControl.

Le bandeau demande confirmation avant de déconnecter le compte. Après un `POST /x4b/logout` réussi, il dirige le navigateur vers la page de connexion X4B. La route de l'application hôte supprime sa session locale et révoque la session partagée. Si la révocation échoue, la route renvoie une erreur HTTP. L'application protège aussi ses propres pages et API.

Pour les deux routes Embedded, `credentials` contient `client_id`, `client_secret` et `session_token`. La source de la map est résolue par `source_reference.system` égal à la clé du module et `source_reference.id` égal à l’identifiant de la fiche. La configuration [AppControl Embedded](EMBEDDED.fr.md) déclare en plus l’origine du portail et le site de simulation. Le jeton de simulation reste court et suit la validité de la session X4B qui l’a demandé.

Pour les maps générées depuis une source documentaire externe, renseigner `documentation` comme nom de source dans **Connaissance → Source documentaire → Paramètres**, ou définir `X4B_KNOWLEDGE_SOURCE=documentation` lors du déploiement. L’`application_key` exposée par le connecteur doit correspondre à l’identifiant utilisé sur la fiche, par exemple `PAI-042`.

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
