# Discovery agentique : préparation, revue et capitalisation

La Discovery agentique prépare une collecte à partir de skills Markdown et d’un périmètre AppControl. L’IA propose un plan ; un utilisateur habilité examine ses opérations et approuve une version précise. Le mode d’exécution est choisi avant la préparation du plan et reste attaché à sa version approuvée : script exécuté manuellement ou collecteurs natifs transmis aux agents AppControl installés et compatibles. Ni la génération IA ni l’approbation ne démarrent une collecte. Une action distincte est requise pour l’exécution par les agents.

## Périmètre disponible

Le parcours partagé est accessible depuis les applications, le catalogue de composants et les agents installés. Il réunit les missions, les skills et les configurations d’agents de Discovery. L’inventaire historique `/discovery` reste disponible séparément.

Une **skill** est un document Markdown libre. Aucun en-tête YAML n’est exigé. Son identifiant, son propriétaire, son nom, sa description, sa version, son empreinte, son statut et ses associations sont gérés dans le catalogue. Une modification crée une nouvelle version ; elle ne change pas le contenu déjà enregistré dans une mission.

Un **agent de Discovery** est une configuration réutilisable : objectif, sélection de skills, répertoires d’installation et limites. Il ne correspond pas à un nouveau service installé sur les machines. Une **mission** fige les versions des skills et les cibles résolues depuis cette configuration.

La génération du plan peut utiliser le Service d’IA du Client ou une préparation manuelle d’opérations structurées. Les opérations acceptées sont limitées aux collecteurs suivants :

| Collecteur | Informations recherchées | Fichiers ou emplacements consultés |
| --- | --- | --- |
| `processes` | Processus Java/Tomcat candidats, sans arguments ni environnement | `/proc/*/comm` |
| `listeners` | Ports TCP en écoute du namespace courant, sans attribution à un processus | `/proc/net/tcp`, `/proc/net/tcp6` |
| `java_release` | Métadonnées de la distribution Java | `java_home/release` |
| `tomcat_version` | Version déclarée de Tomcat | `tomcat_home/RELEASE-NOTES` |
| `tomcat_configuration` | Résumés de connecteurs et paramètres de chargement autorisés | `tomcat_base/conf/server.xml`, `tomcat_base/conf/catalina.properties` |
| `deployed_apps` | Noms des déploiements accessibles | `tomcat_base/webapps` |

L’ajout d’une procédure dans le Markdown ne crée pas un nouveau collecteur. Un objectif exigeant d’autres commandes ou un autre système doit être adapté ou faire l’objet d’une extension du moteur. Le mode par agents installés réutilise les agents et gateways AppControl existants ; il n’installe pas un second agent. Les six collecteurs sont natifs et ne lancent ni Python ni commande shell. Les commandes shell libres, SSH et WinRM restent indisponibles dans ce parcours. Le contrat de capacités et le contrôle par cible indiquent les modes réellement utilisables ; une connexion seule ne suffit pas.

## Prérequis

- Un compte administrateur de l’organisation, connecté dans le navigateur. Les clés API ne permettent pas de créer, approuver, exporter ou consolider ces missions dans le MVP.
- Un backend et un frontend de la même version, avec la migration additive V082 appliquée. Les anciennes applications, maps, identités d’agents et connexions restent dans leurs tables existantes.
- Pour la préparation IA : un connecteur client configuré, autorisé et compatible avec le contrat de prompt 1.1, acceptant `document: null`.
- Pour toute collecte réelle : Linux, un compte **non root**, les droits de lecture nécessaires et une autorisation explicite de l’exploitant.
- Pour le mode **Script manuel** : Python 3.8 ou ultérieur sur la cible.
- Pour le mode **Agents AppControl installés** : un agent actif et compatible, une connexion mTLS vérifiée, une autorisation locale explicite de Discovery et une clé publique Ed25519 d’approbation reconnue. Les racines consultables sont aussi contrôlées localement. Voir la [configuration technique des agents](NATIVE_AGENT_DISCOVERY.md).
- Des chemins d’installation absolus et précis pour les collecteurs concernés : `java_home`, `tomcat_home`, `tomcat_base`. Ils doivent désigner les répertoires réels, sans lien symbolique dans le chemin. Un alias tel qu’un répertoire Java pointant vers une autre installation sera refusé.

Dans ce MVP, les répertoires autorisés sont situés sous `/opt`, `/srv`, `/usr/share`, `/usr/local`, `/usr/lib`, `/var/lib`, `/home`, `/apps` ou `/app`. Les autres racines nécessitent une extension de la politique du collecteur ; une instruction Markdown ne lève pas cette restriction.

Le script n’installe aucun logiciel, ne lance aucun processus externe, ne fait aucun appel réseau et ne demande pas d’élévation de privilèges. Ces choix limitent les opérations disponibles ; ils ne constituent pas un système de sandboxing. Lire un fichier peut notamment modifier sa date d’accès. L’expression « lecture seule » dans une skill ne constitue pas une garantie technique.

## Parcours Tomcat

1. Ouvrir le catalogue de skills, créer une skill et y copier [l’exemple Tomcat](examples/discovery-tomcat/SKILL.md). Renseigner son nom et ses associations dans les champs du catalogue ; relire son contenu avant de la marquer validée.
2. Créer une configuration d’agent de Discovery en sélectionnant cette skill. Préciser l’objectif et les répertoires réellement utilisés sur la cible. La configuration peut être réutilisée pour d’autres missions compatibles.
3. Créer la mission depuis l’application, une brique de catalogue ou un agent installé. Vérifier les machines résolues, y compris les membres de cluster et les affectations de sites. Une machine sans agent peut être désignée manuellement ; son identité restera déclarative.
4. Sélectionner explicitement la source IA souhaitée et le **mode d’exécution du prochain plan**, puis demander sa préparation. Les cibles et versions de skills viennent du contexte enregistré ; l’IA ne peut pas les remplacer. Une erreur IA conserve les plans précédents.
5. Examiner les fichiers consultés, chaque collecteur, sa commande déterminée par le serveur, ses arguments, ses droits, ses durées et ses budgets de sortie. Rejeter le plan si le périmètre ou les informations proposées ne conviennent pas. Un nouveau plan doit être approuvé séparément. Le mode d’exécution est figé dans le plan ; le changer exige une nouvelle version et une nouvelle approbation.
6. Approuver le plan exact, identifié par son empreinte. Pour un plan en mode **Script manuel**, créer une exécution manuelle puis télécharger le script de chaque cible. Pour un plan en mode **Agents AppControl installés**, suivre la variante ci-dessous puis reprendre à l’étape 10 pour la revue de Knowledge. Le téléchargement ne prouve pas que le script a été exécuté ; le suivi attend ensuite son résultat.
7. Après autorisation de l’exploitant, transférer le fichier sur la cible et le relire. Lancer `python3 -I -S appcontrol-discovery.py > discovery-result.json`, sous le compte non root retenu. Les options d’isolation évitent le chargement de modules depuis le répertoire courant et de personnalisations de démarrage ; le script les exige avant ses imports. Lancer le script complet, sans option `--operation`, pour obtenir un résultat importable contenant toutes les opérations de cette cible. Un code de sortie non nul signale un échec à examiner ; le JSON peut conserver les résultats des autres opérations.
8. Examiner localement les informations collectées avant de les importer. Les filtres du collecteur ne remplacent pas cette revue : noms de machines, logiciels, applications, chemins et valeurs de configuration peuvent être sensibles.
9. Importer le JSON dans l’exécution correspondante. Chaque résultat doit référencer le bon plan, son empreinte, l’exécution, la cible et les opérations attendues. Les tailles, champs, durées et statuts sont vérifiés. Importer une deuxième preuve différente pour la même cible nécessite une nouvelle exécution.
10. Après réception des résultats de toutes les cibles, examiner les observations puis confirmer leur consolidation. Cette action valide le contenu examiné ; elle n’authentifie pas la machine. Pour une mission rattachée à une seule application, AppControl ajoute une révision à sa Knowledge existante. Pour une mission sans application, les preuves restent attachées à l’exécution et ne sont pas injectées implicitement dans une autre application. Les missions couvrant plusieurs applications doivent être séparées pour cette première version de la consolidation.

### Variante avec les agents AppControl installés

Après approbation d’un plan préparé pour ce mode :

1. Examiner la **Compatibilité des agents installés**, cible par cible. Une ancienne version, une connexion absente, une autorisation locale désactivée, un moteur incompatible ou une clé d’approbation non reconnue est affiché comme indisponible. Mettre à jour ou configurer l’agent selon la procédure d’exploitation ; aucune commande shell de remplacement n’est tentée.
2. Choisir **Préparer l’exécution par les agents installés**. Cette action crée l’exécution et son historique, sans démarrer la collecte.
3. Relire les cibles puis cocher l’autorisation explicite de lancement. Cliquer sur **Lancer le plan approuvé sur les agents installés**. Le backend recontrôle les droits, le plan exact, son approbation signée et les capacités des cibles avant transmission. Le LLM ne modifie pas le plan pendant son exécution.
4. Suivre les états par cible : en attente, transmis, terminé, échec ou résultat indéterminé. Les résultats sont actualisés pendant l’affichage d’une exécution en cours. En cas de réponse perdue, actualiser le suivi ; l’interface ne relance pas silencieusement une collecte. Un résultat indéterminé demande de consulter l’agent et l’historique d’audit avant toute autre exécution.
5. Après réception des résultats, examiner les observations et leur provenance, puis valider explicitement la consolidation dans Knowledge. La réception par un agent ne vaut pas validation humaine du contenu. Les étapes d’import de fichier du mode manuel ne sont pas utilisées.

Un hôte sans agent compatible peut suivre le parcours manuel, avec un plan préparé et approuvé pour ce mode. Changer le mode sélectionné dans la zone de préparation ne transforme pas un plan déjà approuvé.

L’exécution réelle sur une machine de développement, de test ou cliente demande son autorisation. Une demande de préparation de plan ou un test du code ne vaut pas autorisation de collecte.

## États, approbation et intégrité

Les missions commencent en brouillon. Un plan préparé est en attente d’approbation, puis approuvé ou rejeté. Une exécution préparée attend une intervention explicite : exécution et import du script manuel, ou lancement par les agents installés. Après réception des résultats attendus, elle est terminée ou en échec. Les états par cible conservent les envois et les résultats indéterminés. Une mission peut être annulée ; une collecte déjà transmise peut se terminer et un script déjà téléchargé ne peut pas être rappelé. Pour le mode par agents, l’interface distingue l’annulation demandée de l’arrêt confirmé par un accusé de réception authentifié. Une expiration ou une perte de connexion ne prouve pas l’arrêt. Le suivi de cette confirmation est actualisé pendant une période bornée et reste consultable ensuite. L’interface conserve les plans, preuves et historiques précédents.

Le plan comprend le contexte, les versions de skills, les cibles, le mode d’exécution, les fichiers, les opérations et les limites. Son empreinte SHA-256 est calculée sur une représentation canonique versionnée. Une empreinte vérifie une correspondance de contenu ; elle ne constitue pas une autorisation. AppControl exige un enregistrement d’approbation par un utilisateur habilité pour le plan exact avant de créer une exécution ou de fournir un script.

Le plan fige aussi l’empreinte de l’implémentation des collecteurs (`runner_sha256`). Une mise à jour de ce code ne permet pas de télécharger un script modifié sous une ancienne approbation : une nouvelle préparation et une nouvelle approbation sont nécessaires. Les plans et les preuves précédents restent consultables.

Une infrastructure de signature, facultative pour le mode manuel et nécessaire au mode par agents installés, est disponible avec `APPCONTROL_DISCOVERY_SIGNING_SEED` : une graine Ed25519 dédiée de 32 octets, encodée en 64 caractères hexadécimaux. Elle doit être fournie comme secret d’exploitation, séparément des clés JWT, des clés d’API et des certificats de transport. Ne jamais la copier dans une skill, une mission ou un journal. L’approbation garde l’algorithme, l’identifiant de clé, la clé publique et la signature. Un changement de clé peut nécessiter une nouvelle approbation. Une signature serveur ne constitue pas une signature personnelle de l’utilisateur ni une attestation d’exécution sur la machine.

Dans Helm, `backend.discoveryApproval.existingSecret` et `secretKey` référencent un Secret existant contenant cette graine. Dans Compose, la variable peut être fournie à l’environnement du backend. Une valeur absente ou vide laisse la signature désactivée ; l’approbation humaine enregistrée reste obligatoire. Activer la signature sur une installation ayant des approbations non signées exige de nouvelles versions approuvées avant export ou import. Conserver la clé dédiée dans la sauvegarde sécurisée de la configuration ; les historiques restent consultables après une rotation.

## Connaissances et provenance

Les preuves de Discovery alimentent les mêmes révisions de Knowledge que les autres preuves applicatives. Leur origine est explicitement `discovery`, avec une référence `discovery-run:<identifiant>` ; elle n’est pas présentée comme un commit Git.

Chaque observation conserve sa preuve textuelle et ses liens vers la mission, l’exécution, le plan et son empreinte, la cible, l’opération, la skill et sa version, son empreinte, la date de collecte et, lorsqu’ils existent, le composant et l’agent prévus par le plan. Le nom de machine annoncé par le fichier ne vaut pas authentification de cette machine.

La **nature** d’une information et sa **validation** sont distinctes : une observation est déclarée par le collecteur ; une inférence désigne une interprétation ; la validation enregistre la revue humaine, son auteur et sa date. Les collecteurs produisent des observations ; leurs résultats ne sont pas des inférences IA. Le résultat manuel conserve une identité déclarative, distincte de la provenance de transport du mode par agents. Après revue, ces observations peuvent être validées tout en conservant `identity_verified: false`.

Les nouvelles preuves ne remplacent pas automatiquement une information validée contradictoire. Les alternatives et leurs sources sont conservées et le conflit est signalé. Les versions Java et Tomcat sont distinguées ; les instances d’un composant déployé sur plusieurs machines gardent leur provenance propre. Une synchronisation Git ne retire pas les preuves indépendantes de Discovery.

La consolidation n’applique aucune commande, ne publie aucune map et n’envoie aucune configuration à un agent. Une proposition de map exécutable reste soumise à ses propres contrôles de complétude, de rapprochement et d’approbation. Les observations de versions ne constituent pas, à elles seules, un diagnostic de vulnérabilité ou une modification des données d’obsolescence du catalogue.

Les limites de Knowledge sont vérifiées avant écriture : une source textuelle de 100 Ko, 1 000 nouveaux claims par import, 100 sources, 1,5 Mo et 2 000 claims consolidés par application. Une preuve agrégée est ajoutée par exécution. Si ce budget est dépassé, les résultats bruts restent dans l’exécution ; la consolidation renvoie une erreur et ne supprime pas les anciennes révisions. Aucun historique n’est évincé silencieusement.

La politique de mission borne la somme des durées et volumes d’opérations sur toutes les cibles : au plus 600 secondes et 500 000 octets de données, avec au plus 100 opérations. Chaque opération est limitée à 30 secondes et 50 000 octets. Les métadonnées d’import disposent d’une enveloppe bornée séparément. Un plan multi-machine doit répartir le budget entre ses cibles.

## Connexion à l’IA du Client

La préparation du plan utilise le connecteur nommé choisi dans X4B. Elle lui transmet une demande `prompt-executions` avec `document: null`, les Instructions et un contexte comprenant l’objectif, le Markdown complet des skills sélectionnées, leurs identifiants et versions, les cibles connues, les paramètres de répertoires et les limites. Ce parcours ne transmet pas automatiquement un fichier collecté ni le contenu brut des configurations à l’IA.

Les skills et le contexte sont traités comme des données non fiables. Une instruction insérée dans le Markdown ne peut pas ajouter une cible, lever une limite ou introduire un shell libre : le serveur valide les opérations proposées et détermine les fichiers et commandes autorisés. Une source incompatible ou indisponible entraîne une erreur explicite ; elle ne provoque pas de collecte automatique.

## Vérification et limites des preuves de test

Les tests de qualification doivent couvrir la préparation, le mode figé, l’approbation, l’action de lancement distincte, les refus d’accès et de capacités, les transitions et conflits de révision, les limites, l’immutabilité, l’import manuel, les résultats des agents, la provenance et la consolidation transactionnelle. Les tests d’interface utilisent des réponses simulées et ne collectent aucune donnée sur une machine réelle. Le runner possède des tests sur fichiers et réponses simulés dans `tests/test_agentic_discovery_runner.py` ; ils ne constituent pas une discovery réellement exécutée chez le client.

Pour une recette autorisée, conserver l’identifiant du plan et de l’exécution, les versions déployées, l’autorisation de collecte, les résultats importés, les erreurs éventuelles et la révision Knowledge créée. Vérifier qu’un résultat rejeté ne retire pas les anciennes connaissances, qu’un échec conserve les preuves du run et qu’aucune publication de map n’a eu lieu. Qualifier ensuite séparément le connecteur IA et une vraie cible Linux dans le périmètre convenu.

Voir aussi le [contrat d’API du parcours](AGENTIC_DISCOVERY_API.md). Les capacités retournées par l’instance et la version effectivement installée prévalent sur un exemple de document.
