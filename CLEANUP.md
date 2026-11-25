# CLEANUP — galass-ci : ne garder que la CI produit

Périmètre : tous les fichiers du dépôt (racine, `.github/`, `opencode/`, `prompts/`).
Critère : **KEEP** = ce qui teste/vérifie/déploie le PRODUIT (Galass/Antenly) ;
**REMOVE** = harnais opencode/FullRun/agents/prompts/guards générique, désormais
dans `LordThiouk/lifeos-ci` (lecture seule : lifeos non modifié).

Règle 2 appliquée : `opencode/allowed-repos.sh` est appelé par le workflow KEEP
`isa-human-tick.yml` → verdict **KEEP** (doublon présent dans lifeos-ci, mais exigé ici).

| Fichier | Verdict | Raison (une ligne) |
|---|---|---|
| `README.md` | KEEP | Doc du dépôt : CI produit Galass (réécrit à l'étape 3, pointer vers lifeos-ci). |
| `CLEANUP.md` | KEEP | Registre du nettoyage (ce fichier). |
| `.github/workflows/ci.yml` | REMOVE | CI du harnais : boucle `opencode/tests/*.sh` + gitleaks sur ce dépôt — doublon de la CI lifeos-ci (shellcheck/actionlint/tests opencode). |
| `.github/workflows/isa-human-tick.yml` | KEEP | Check produit : coche une claim `[scope:human]` d'une ISA dans un dépôt Galass (version canonique, absente de lifeos-ci). |
| `.github/workflows/opencode-fullrun.yml` | REMOVE | Moteur FullRun opencode générique → lifeos-ci (`opencode-fullrun.yml`). |
| `.github/workflows/opencode-task.yml` | REMOVE | Tâche opencode générique → lifeos-ci (`task.yml` + `_agent-run.yml`). |
| `opencode/allowed-repos.sh` | KEEP | Liste blanche des dépôts Galass, sourcée par `isa-human-tick.yml` (règle 2). |
| `opencode/autosave-deny.txt` | REMOVE | Liste noire d'autosave du FullRun → lifeos-ci (doublon). |
| `opencode/autosave.sh` | REMOVE | Démon d'autosave des commits wip FullRun → lifeos-ci (doublon). |
| `opencode/checkpoint.sh` | REMOVE | Checkpoints/reprise des runs FullRun → lifeos-ci (doublon). |
| `opencode/ci-preamble.md` | REMOVE | Préambule injecté au prompt FullRun → lifeos-ci (doublon). |
| `opencode/config/opencode.json` | REMOVE | Config opencode du harnais FullRun → lifeos-ci (doublon). |
| `opencode/done-check-call.sh` | REMOVE | Appelant du validateur de verdict → lifeos-ci (doublon). |
| `opencode/done_check.sh` | REMOVE | Validateur de verdict/fin de run FullRun → lifeos-ci (doublon). |
| `opencode/emu-e2e.sh` | REMOVE | Déclencheur e2e emu donné à opencode pendant FullRun ; doublon identique lifeos-ci, seul appelant (`opencode-fullrun.yml`) retiré. |
| `opencode/extra-repos.sh` | REMOVE | Checkout des dépôts supplémentaires FullRun → lifeos-ci (doublon). |
| `opencode/install-hook-profile.sh` | REMOVE | Installation du profil de hooks opencode → lifeos-ci (doublon). |
| `opencode/leaklog.sh` | REMOVE | Chiffrement age du journal fullrun-logs → lifeos-ci (doublon). |
| `opencode/livelog.sh` | REMOVE | Démon de journal en direct → lifeos-ci (doublon). |
| `opencode/log-recipient.txt` | REMOVE | Destinataire age du journal → lifeos-ci (doublon). |
| `opencode/merge-signed-carry.sh` | REMOVE | Fusion des carry signés FullRun → lifeos-ci (doublon). |
| `opencode/progress.sh` | REMOVE | Publication du rapport de progression → lifeos-ci (doublon). |
| `opencode/redact-log.sh` | REMOVE | Masquage du journal avant push → lifeos-ci (doublon). |
| `opencode/run-fullrun.sh` | REMOVE | Wrapper d'exécution FullRun → lifeos-ci (doublon). |
| `opencode/split-diff.sh` | REMOVE | Découpage du diff pour le prompt → lifeos-ci (doublon). |
| `opencode/wippush.sh` | REMOVE | Push périodique des commits wip → lifeos-ci (doublon). |
| `opencode/tests/agent-idle-test.sh` | REMOVE | Test du harnais (silence par agent) → suite lifeos-ci. |
| `opencode/tests/allowed-repos-cwd-test.sh` | REMOVE | Test du harnais (cwd de allowed-repos) → suite lifeos-ci. |
| `opencode/tests/allowed-repos-test.sh` | REMOVE | Test du harnais (options de workflow vs liste blanche) → suite lifeos-ci ; plus de fullrun/task ici à valider. |
| `opencode/tests/autosave-test.sh` | REMOVE | Test du harnais (autosave) → suite lifeos-ci. |
| `opencode/tests/chain-step-test.sh` | REMOVE | Test du harnais (chaînage FullRun) → suite lifeos-ci. |
| `opencode/tests/checkpoint-watchdog-verdict-test.sh` | REMOVE | Test du harnais (checkpoint/watchdog/verdict) → suite lifeos-ci. |
| `opencode/tests/done-check-test.sh` | REMOVE | Test du harnais (validateur done_check) → suite lifeos-ci. |
| `opencode/tests/extra-repos-test.sh` | REMOVE | Test du harnais (dépôts supplémentaires) → suite lifeos-ci. |
| `opencode/tests/first-link-prompt-test.sh` | REMOVE | Test du harnais (premier lien de chaîne) → suite lifeos-ci. |
| `opencode/tests/hmac-state-test.sh` | REMOVE | Test du harnais (état HMAC signé) → suite lifeos-ci. |
| `opencode/tests/hook-profile-install-test.sh` | REMOVE | Test du harnais (profil de hooks) → suite lifeos-ci. |
| `opencode/tests/internals-test.sh` | REMOVE | Test du harnais (interne run-fullrun) → suite lifeos-ci. |
| `opencode/tests/leaklog-test.sh` | REMOVE | Test du harnais (journal chiffré) → suite lifeos-ci. |
| `opencode/tests/lib.sh` | REMOVE | Bibliothèque partagée des tests du harnais → suite lifeos-ci. |
| `opencode/tests/livelog-test.sh` | REMOVE | Test du harnais (journal en direct) → suite lifeos-ci. |
| `opencode/tests/merge-signed-carry-test.sh` | REMOVE | Test du harnais (carry signé) → suite lifeos-ci. |
| `opencode/tests/oc-deadline-test.sh` | REMOVE | Test du harnais (délai opencode) → suite lifeos-ci. |
| `opencode/tests/prompt-contract-test.sh` | REMOVE | Test du harnais (contrat de prompt) → suite lifeos-ci. |
| `opencode/tests/split-diff-test.sh` | REMOVE | Test du harnais (split-diff) → suite lifeos-ci. |
| `opencode/tests/stall-resume-test.sh` | REMOVE | Test du harnais (stall/reprise) → suite lifeos-ci. |
| `opencode/tests/start-step-test.sh` | REMOVE | Test du harnais (porte start_step) → suite lifeos-ci. |
| `opencode/tests/stop-step-target-agent-test.sh` | REMOVE | Test du harnais (stop_after_step/target_agent) → suite lifeos-ci. |
| `opencode/tests/subagent-fail-test.sh` | REMOVE | Test du harnais (échec sous-agent) → suite lifeos-ci. |
| `opencode/tests/turn-end-test.sh` | REMOVE | Test du harnais (fin de tour) → suite lifeos-ci. |
| `opencode/tests/unit-contract-test.sh` | REMOVE | Test du harnais (contrat unit) → suite lifeos-ci. |
| `opencode/tests/verdict-cli.lib` | REMOVE | Bibliothèque de test du CLI de verdict → suite lifeos-ci. |
| `opencode/tests/watchdog-test.sh` | REMOVE | Test du harnais (watchdog) → suite lifeos-ci. |
| `opencode/tests/wippush-test.sh` | REMOVE | Test du harnais (push wip) → suite lifeos-ci. |
| `opencode/tests/with-emulators-test.sh` | REMOVE | Test du harnais (e2e emu via FullRun) → suite lifeos-ci ; l'e2e produit reste dans `galass-emu-actions-pub`. |
| `prompts/clean-product-ci.md` | REMOVE | Prompt de tâche opencode générique (harnais), pas un artefact de CI produit. |
