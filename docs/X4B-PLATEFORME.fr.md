# X4B — Raccorder une application

X4B, édité par Invivoo, réunit AppControl, Génération de maps et les applications enregistrées. L’accueil est à `/x4b`. Le menu du compte donne accès à **Comptes et accès** et **Applications raccordées** pour les administrateurs. AppControl conserve ses liens directs, notamment `/apps/<id>`.

## Comptes et accès

L’administrateur réutilise les comptes locaux AppControl. Les comptes existants gardent leur accès AppControl après mise à jour. Les nouveaux comptes créés dans X4B reçoivent les accès choisis dans l’administration. La génération et la publication par lots restent réservées aux administrateurs dans cette version. Les autorisations AppControl sur les maps, les sites et les opérations s’appliquent en plus de l’accès au module.

Pour un POC avec Panoramisk, créer un compte administrateur de revue et un compte de consultation. Donner à ce dernier accès à Panoramisk, puis un droit de lecture sur la map et les sites nécessaires, dont le site de simulation. Le compte peut ouvrir une simulation isolée. Les opérations sur une map réelle nécessitent les droits d’exploitation AppControl.

## Intégration Panoramisk

1. Conserver les URL HTTPS de Panoramisk et d’AppControl. L’accueil X4B peut utiliser le même hôte qu’AppControl avec le chemin `/x4b`.
2. Dans **Applications raccordées**, enregistrer `panoramisk`. Pour l’hôte de référence, utiliser `https://panoramisk.example.test/` comme URL d’entrée et `https://panoramisk.example.test/x4b/callback` comme URL de retour, avec le domaine réel de l’hôte. Copier le secret affiché à la création dans le gestionnaire de secrets du serveur Panoramisk.
3. Protéger les fiches et les API Panoramisk avec la session X4B. Lors d’un accès direct, conserver le chemin de la fiche côté serveur, effectuer l’échange d’autorisation et revenir à ce chemin. Le serveur Panoramisk vérifie aussi ses propres droits de consultation de fiche. Voir [le contrat d’accès](X4B-ACCESS.fr.md).
4. Ajouter les composants à la mise en page et à la fiche. Le serveur Panoramisk expose les routes locales ci-dessous. Les données d’identité restent sur les canaux serveur à serveur.

```html
<script defer src="https://appcontrol.example.test/x4b-portal.js"></script>
<script defer src="https://appcontrol.example.test/appcontrol-embedded.js"></script>
<x4b-shell module="panoramisk" platform-url="https://appcontrol.example.test"></x4b-shell>
<appcontrol-status endpoint="/fiches/PAI-042/status"></appcontrol-status>
<appcontrol-map backend-url="https://appcontrol.example.test"></appcontrol-map>
```

| Route Panoramisk | Appel serveur X4B/AppControl |
| --- | --- |
| `GET /x4b/session` | `POST /api/v1/x4b/session` retourne le compte et ses entrées de navigation. |
| `POST /x4b/logout` | `POST /api/v1/x4b/session/revoke` révoque la session partagée, puis Panoramisk efface sa session locale. Vérifier l’origine du POST. |
| `GET /fiches/<id>/status` | `POST /api/v1/x4b/embedded/status` avec `credentials` et `source_id`. Renvoie l’état agrégé, la dernière observation et l’indicateur de fraîcheur. Une map absente ou non autorisée donne `404`. |
| `POST /fiches/<id>/simulation` | `POST /api/v1/x4b/embedded/simulation` avec les mêmes champs et éventuellement `simulation_site_id`. Affecter la réponse à la propriété JavaScript `session` du composant map. Vérifier l’origine du POST. |

Pour les deux routes Embedded, `credentials` contient `client_id`, `client_secret` et `session_token`. La source de la map est résolue par `source_reference.system` égal à la clé du module et `source_reference.id` égal à l’identifiant de la fiche. La configuration [AppControl Embedded](EMBEDDED.fr.md) déclare en plus l’origine Panoramisk et le site de simulation. Le jeton de simulation reste court et suit la validité de la session X4B qui l’a demandé.

Pour les maps générées depuis Panoramisk, renseigner `X4B_KNOWLEDGE_SOURCE=panoramisk` dans le Secret de source documentaire OpenShift. L’`application_key` exposée par le connecteur doit correspondre à l’identifiant utilisé sur la fiche, par exemple `PAI-042`.

Le badge actualise les données toutes les 15 secondes quand la page est visible. Autoriser l’hôte AppControl dans `script-src`, `style-src` et `frame-src` du portail. Le navigateur interroge les routes Panoramisk sous sa propre origine.

L’hôte de référence `demo-rebuild/embedded/x4b_host.py` contient deux fiches fictives, dont `PAI-042`. Il est livré dans l’archive [demo-rebuild.tar.gz de la release](https://github.com/xcomponent/appcontrol-release/releases/download/v1.24.1/demo-rebuild.tar.gz). Le placer derrière un proxy HTTPS qui transmet le `Host` public. Configurer `X4B_URL=https://appcontrol.example.test`, `X4B_HOST_ORIGIN=https://panoramisk.example.test` et `X4B_MODULE_KEY=panoramisk` avec les valeurs de l’installation, puis injecter le secret client dans `X4B_CLIENT_SECRET`. Si plusieurs sites de simulation sont configurés, préciser `X4B_SIMULATION_SITE_ID`. L’hôte écoute en boucle locale sur le port `8081` par défaut. Le modèle de production doit s’appuyer sur les sessions du framework Panoramisk et vérifier les droits de chaque fiche.

Si le certificat de X4B est signé par une autorité interne, configurer `X4B_CA_FILE` avec la chaîne de confiance PEM sur le serveur de l’hôte de référence. Le navigateur doit lui aussi faire confiance à l’autorité utilisée par les deux sites.

## Catalogue complet et génération

Le catalogue appartient à AppControl. Les entrées acceptent `match_terms` (ou `keys` sur les exports existants). Le kit Windows envoie les entrées par lots. Chaque lot respecte les limites de la requête, sans plafond total sur le catalogue configuré. Pour enrichir une entrée déjà importée, utiliser le mode `upsert` de l’API catalogue avec une prévisualisation `dry_run` puis l’`expected_digest` obtenu. Le kit Windows conserve le mode ajout pour préserver les entrées existantes.

Quand le catalogue est renseigné, X4B demande d’abord à l’IA du client les termes observés dans le document. X4B recherche ces termes dans toutes les entrées du catalogue. Le second appel utilise la même révision du document et reçoit les candidats par composant. Les commandes et variables du catalogue ne sont pas envoyées au moteur de génération. La revue indique les rapprochements ambigus et inconnus, avec les candidats trouvés. Ces propositions nécessitent une confirmation individuelle. Une modification du catalogue rend caduques les propositions fondées sur son état antérieur.

Le contrat [Knowledge Engine](KNOWLEDGE-ENGINE-CONNECTOR.fr.md) est conservé. Le point de terminaison `prompt-executions` doit pouvoir appliquer le prompt reçu, y compris quand le résultat demandé est un inventaire de composants. Le moteur de génération reste celui du client.
