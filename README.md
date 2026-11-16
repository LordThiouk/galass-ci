# galass-ci

CI publique (minutes GitHub Actions gratuites) pour les dépôts Galass :
`LordThiouk/Galass_Driver`, `LordThiouk/Galass_Rider`, `LordThiouk/Galass_backend`
et `LordThiouk/galass-emu-actions-pub` (tests e2e).

Ce dépôt ne contient que des workflows et le harnais FullRun. Le code et les PR
restent dans les dépôts Galass concernés, récupérés au run avec le secret
`GALASS_TOKEN` (jeton fine-grained limité à ces dépôts). Le journal `fullrun-logs`
reste dans le dépôt cible. Le harness de travail LifeOS est lu en lecture seule
depuis `LordThiouk/lifeos` (`LIFEOS_READ_TOKEN`).

- `ci.yml` : tests de `opencode/tests/` et `gitleaks detect` sur ce dépôt.
- `opencode-fullrun.yml` : longs jobs opencode (FullRun LifeOS) sur une branche de
  fonctionnalité du dépôt cible, à la main uniquement (voir plus bas).

Les logs et artifacts de ce dépôt sont publics. Aucun push direct sur une branche de
base d'un dépôt Galass ; le merge reste manuel.

## FullRun opencode (`opencode-fullrun.yml`)

Fait tourner un long job opencode (FullRun LifeOS) pour un dépôt Galass sur un runner
GitHub standard, à la place de la box. Dépôt public : les minutes des runners standards
sont **gratuites**. Limite : 6 h par job (le workflow s'arrête à 350 min ; opencode est
arrêté au plus tard à 335 min, pour laisser 15 min au rapport, aux contrôles et au push).

**Ce qui est versionné ici (public).** Le workflow, `opencode/config/opencode.json`
(config assainie : sans provider FreeLLM ni VPS, sans MCP `github`/`rea`/`playwright`,
chemins en `{env:HOME}`, modèle `{env:OC_MODEL_MAIN}`, `git push`/`gh` interdits à
l'IA), `opencode/ci-preamble.md` (contexte CI ajouté avant le prompt) et les scripts
`opencode/` (run, suivi, journal en direct, push des wip, dépôts supplémentaires, masquage). Les agents,
commandes, plugin LifeOS et prompt restent **privés** dans `LordThiouk/lifeos`,
dossier `opencode/` (entrée `lifeos_ref`, défaut `main`).

**Secrets à créer (Settings → Secrets → Actions)** — noms seulement, jamais dans un fichier :

| Secret | Contenu | Portée |
|---|---|---|
| `GALASS_TOKEN` | jeton fine-grained, **seulement** `Galass_Driver`, `Galass_Rider`, `Galass_backend`, `galass-emu-actions-pub` (et `galass-ci` si besoin) | Contents, Pull requests, Workflows : read & write. Pour `with_emulators` : aussi **Actions : read & write** sur `galass-emu-actions-pub` (déclencher et lire `artemis-staging-e2e.yml`) |
| `LIFEOS_READ_TOKEN` | même valeur que sur `antenly-ci` : jeton fine-grained, **seulement** `LordThiouk/lifeos` | Contents: read |
| `ISA_STAMP_KEY` | même valeur que sur `antenly-ci` : contenu de `~/.claude/LIFEOS/MEMORY/STATE/.isa-stamp-key` de la box (64 hex) | — |
| `OC_NOTIFY_URL` | URL du webhook opencode-notify (la même que `OC_NOTIFY_URL` de `~/.oc-run/config` sur la box) | optionnel |
| `OC_NOTIFY_KEY` | clé du webhook (`OC_NOTIFY_KEY` de `~/.oc-run/config`) | optionnel |

Sans `OC_NOTIFY_URL`/`OC_NOTIFY_KEY`, le run marche pareil mais n'envoie pas de notification
de fin (avertissement dans le step).

Aucune clé de modèle : les modèles `opencode/*-free` n'en demandent pas. Le workflow
refuse tout modèle qui n'est pas `opencode/…-free`.

**Protection de `main`.** Un jeton fine-grained ne peut pas être limité à une branche, et
la protection de branche / les rulesets ne sont pas disponibles sur un dépôt privé en plan
gratuit. Garde-fous en place : l'IA ne reçoit **aucun** jeton d'écriture (checkout sans
identifiants, hook `pre-push` bloquant, `git push` refusé dans la config) ; seul le dernier
step pousse, vers `refs/heads/<branche>` exacte, sans `--force`, après avoir vérifié que la
branche n'est ni `main` ni `master`, que l'historique part bien du SHA de départ, que
`.github/workflows/` n'est pas touché et que gitleaks ne trouve rien dans les commits du
run. Si un jour le dépôt cible passe en Pro/public : ajouter une règle « interdire les push
directs sur `main` ».

**Lancer.** Pré-requis : la branche de fonctionnalité existe déjà sur le dépôt cible et
contient le travail de départ.

Onglet Actions → `opencode FullRun` → `Run workflow` :

| Entrée | Rôle |
|---|---|
| `target_repo` | Dépôt cible : `Galass_Driver`, `Galass_Rider`, `Galass_backend` ou `galass-emu-actions-pub` (obligatoire). Le journal `fullrun-logs` reste dans ce dépôt. |
| `extra_repos` | Dépôts supplémentaires, séparés par des virgules, parmi les mêmes quatre noms (défaut vide). Chacun est récupéré dans `$EXTRA_ROOT/<nom>` (`<workspace>/extra/<nom>`). Même branche de fonctionnalité. Ex. multi-stop : `target_repo=Galass_backend` et `extra_repos=Galass_Rider,Galass_Driver,galass-emu-actions-pub`. Pas de doublon ni de répétition de `target_repo`. |
| `branch` | Branche du dépôt cible (ex. `feat/…`), jamais `main`/`master` ; aussi interdites : `fullrun-logs/*` et `fullrun-prompts`. Si elle n'existe pas encore sur un dépôt supplémentaire, elle est créée localement depuis sa branche par défaut, puis poussée à la fin (sans force). |
| `prompt_path` | `prompts:<chemin>` sur la branche `fullrun-prompts` du dépôt cible (recommandé, jamais fusionnée, donc aucun prompt sur la branche de travail ; la référence est retirée du checkout avant opencode), sinon `repo:<chemin>` ou `ci:<chemin>` ; un prompt mis dans ce dépôt public est public. |
| `job_name` | Lettres, chiffres, `- _ .` ; rapport `.fullrun/<job>_DONE.md`. |
| `lifeos_ref` | Branche de `LordThiouk/lifeos` (défaut `main`). |
| `isa_path` | `MEMORY/WORK/<dossier>/ISA.md`, ou vide (déduite du prompt). |
| `base_branch` | Cible de la PR en brouillon (vide = branche par défaut du dépôt concerné). |
| `idle_minutes` / `wip_push_minutes` | Silence max et rythme de push des wip (dépôt cible). |
| `with_emulators` | Défaut `false`. Si `true`, opencode reçoit l'outil figé `/opt/fullrun-tools/emu-e2e.sh`, qui déclenche `artemis-staging-e2e.yml` sur `LordThiouk/galass-emu-actions-pub` (les secrets e2e restent dans ce dépôt : rien à poser sur galass-ci), avec `rider_ref`/`driver_ref` = la branche de travail du FullRun si elle existe sur le dépôt, sinon `main`. L'outil attend la fin (délai borné), rend le verdict et, en échec, un court extrait des logs. opencode peut corriger et relancer en boucle. Le jeton utilisé est `GALASS_TOKEN` (hors de l'environnement d'opencode). Pas de FreeLLM : les modèles FullRun restent `opencode/*-free` ; Artemis côté emu reçoit `deepseek-v4.1-flash-free`. Prérequis : [PR emu #5](https://github.com/LordThiouk/galass-emu-actions-pub/pull/5) (API opencode `*-free`, risque 403) et le droit Actions write du jeton sur le dépôt emu. |

Ou en CLI :

```
gh workflow run opencode-fullrun.yml -R LordThiouk/galass-ci \
  -f target_repo=Galass_backend -f extra_repos=Galass_Rider,Galass_Driver,galass-emu-actions-pub \
  -f branch=… -f prompt_path=prompts:… -f job_name=… \
  -F with_emulators=true
```

**À la fin du run.** Contrôles (gitleaks, clé ISA, branche, historique) puis push de ce
qui est commité, puis le job finit **en succès seulement** si le validateur de fin est vert.
Une PR en brouillon est ouverte sur le dépôt cible, **jamais fusionnée**. Chaque dépôt
supplémentaire modifié est poussé sur la même branche (gitleaks avant push, jamais main,
jamais de force) et reçoit sa propre PR en brouillon, **jamais fusionnée**. Le journal
opencode est poussé sur une **branche dédiée** du dépôt cible,
`fullrun-logs/<job>-<run_id>` (privé) : un commit normal qui remplace le fichier, jamais
de force. Il est d'abord masqué par `redact-log.sh`, puis passé à gitleaks en mode
fichier. **À supprimer après lecture** (par Papa).

Un démon pousse aussi un instantané du journal toutes les 10 min sur cette branche, et
les commits `wip:` de la branche de travail toutes les `wip_push_minutes` min, après les
mêmes contrôles. Le jeton `GALASS_TOKEN` arrive aux démons sur l'entrée standard : il
n'est ni dans l'environnement d'opencode, ni dans un fichier, ni dans une URL.

**Journal chiffré quand un contrôle refuse le push.** Si gitleaks (ou un autre contrôle
avant push) refuse, le journal masqué et le rapport gitleaks (réduit à fichier, lignes,
règle, commit : jamais la valeur) sont chiffrés avec `age` pour la clé publique de
`opencode/log-recipient.txt` et publiés en artefact (rétention 7 jours).

Lire un artefact :

```
gh run download <run_id> -R LordThiouk/galass-ci -n fullrun-log-<job>-<run_id>.age -D log
```

Lire le journal en direct : GitHub → dépôt cible → branche `fullrun-logs/…`.

Tests locaux (sans réseau réel, sauf téléchargement de gitleaks s'il manque) :

```
opencode/tests/done-check-test.sh
opencode/tests/internals-test.sh
opencode/tests/leaklog-test.sh
opencode/tests/livelog-test.sh
opencode/tests/stall-resume-test.sh
opencode/tests/watchdog-test.sh
opencode/tests/wippush-test.sh
opencode/tests/checkpoint-watchdog-verdict-test.sh
opencode/tests/extra-repos-test.sh
opencode/tests/allowed-repos-test.sh
```

## Reprise, surveillance, verdicts réels

- **Reprise depuis la dernière étape.** Après chaque étape validée, l'agent appelle
  `/opt/fullrun-tools/checkpoint.sh write --job J --step N …` : `.fullrun/<job>_checkpoint.json`
  (étape, commit, résumé, verdicts), pas de saut d'étape. À chaque reprise (`stall_resume`,
  `new_session`) et à chaque relance du job, le prompt reçoit ce fichier et le début de `_DONE.md`
  avec l'ordre de reprendre à l'étape suivante ; un verdict encore valable (aucun commit de code
  depuis son SHA) n'est pas redemandé. Le fichier est un indice, pas une preuve.
- **Ne pas couper un travail en cours.** Comptent comme activité : le journal, les fichiers de
  session (sous-agents) et le CPU des processus ENFANTS de l'agent (`OC_CHILD_CPU_MIN`, 10 ticks par
  sonde). Coupure après `OC_IDLE_MIN` minutes sans aucune de ces activités ; le seuil fixe de 8 min
  n'est plus appliqué par défaut (`OC_SUBAGENT_IDLE_SEC` reste un plafond optionnel).
- **Verdicts réels seulement.** `done_check.sh` exige, pour chaque agent de `OC_DONE_AGENTS` (entrée
  `done_agents`, défaut `Max`, ex. `Max,Silas`), une vraie tâche terminée dans le stockage opencode
  et la ligne `SUBAGENT done` du plugin ; un PASS écrit par l'agent principal ne compte pas.

## Limites et garde-fous

- Jamais de push sur `main`/`master`, jamais de `--force`, jamais de fusion automatique
  d'une PR en brouillon.
- L'IA n'a aucun jeton d'écriture. `GALASS_TOKEN` n'est exposé qu'aux steps de push,
  aux démons root et à la création de PR, jamais à opencode.
- Le prompt FullRun est lu depuis la branche `fullrun-prompts` du dépôt cible (privé,
  recommandé), depuis la branche de travail (`repo:<chemin>`) ou depuis ce dépôt
  (public) : un prompt mis ici est public.
- Hooks LifeOS : le service local `localhost:31337` et `cc-diff` n'existent pas sur le
  runner ; le plugin replie les hooks http sur leur équivalent local. `rtk` est installé
  (release officielle `rtk-ai/rtk` **v1.2.0**, sha256 vérifié).
- Permissions CI : `opencode/config/opencode.json` ne contient **aucune** valeur `"ask"`.
- Pas de FreeLLM, de VPS, de Playwright ni de MCP GitHub sur le runner.
