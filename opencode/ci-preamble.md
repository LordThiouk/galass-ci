# Contexte CI (galass-ci, GitHub Actions) — à lire avant le prompt FullRun

Tu tournes sur un runner GitHub Actions public, pas sur la box. Suis le FullRun.

- Dépôt de travail : le répertoire courant (`$TARGET_DIR`), checkout de `LordThiouk/$TARGET_REPO`
  sur la branche `$OC_BRANCH`. Les chemins `/home/box/...` et `/workspace/...` du prompt
  désignent ici `$HOME/...` et ce checkout (`/home/box` est un lien vers `$HOME`).
- Dépôts supplémentaires : s'il y en a (`$EXTRA_REPOS`, vide si aucun), chacun est dans
  `$EXTRA_ROOT/<nom>` (ex. `$EXTRA_ROOT/galass-emu-actions-pub`). Tu peux y lire et y
  commiter, sur `$OC_BRANCH` uniquement. Tu ne pousses rien. Le journal `fullrun-logs`
  reste dans le dépôt cible (`$TARGET_REPO`).
- **Tu ne pousses rien.** Pas de `git push`, pas de `gh`, pas de PR, pas de commentaire : tu n'as
  aucun jeton d'écriture. Fais des commits locaux sur `$OC_BRANCH` uniquement (jamais de
  `git reset --hard`, `rebase`, `commit --amend` sur des commits déjà présents au départ :
  l'historique doit rester une suite du SHA de départ). Le workflow pousse lui-même tes
  commits sur `$OC_BRANCH` à la fin, sans force.
- Ne change pas de branche, ne crée pas d'autre branche, ne touche pas à `.github/workflows/`.
- **Logs publics, mais ta sortie n'y est jamais affichée.** N'écris quand même aucun secret
  nulle part (fichiers, commits, rapport).
- Rapport final : écris-le dans `$OC_REPORT` (hors dépôt). Le workflow le versionne dans
  `.fullrun/${OC_JOB}_DONE.md` sur la branche. Mets-y : étapes faites, commits, compte des
  tests, verdicts avec SHA, ISC cochés/total, ce qui reste et l'étape de reprise.
- **Reprise.** Ce run peut être une relance. Avant d'agir, lis `.fullrun/${OC_JOB}_DONE.md`
  s'il existe et l'état de l'ISA sur la branche, puis reprends à la première étape non
  terminée au lieu de tout refaire.
- Modèles : principal et Forge `$OC_MODEL_MAIN`, Max `$OC_MODEL_MAX` (gratuits opencode).
- Pas de VPS, pas de FreeLLM, pas de Mac. Pas de merge, pas de déploiement.

## Contrat de prompt (non négociable)

Dans cet ordre de priorité :

1. Tu ne termines jamais ton tour par une question ni par une demande d'arbitrage : en CI personne ne répond, une question vaut abandon.
2. Si une mesure contredit un ISC : consigne l'écart dans l'ISA (Log + claim), garde la garde en place, choisis l'option qui **ne réécrit pas** les seuils, commit, puis continue.
3. Tout correctif annoncé comme non négociable est commité dans la même passe que l'annonce, et le rapport `.fullrun/<job>_DONE.md` est écrit avant la dernière phrase.

Une fin de tour sans PASS vérifié n'est pas une fin de run : le moniteur relance une session
neuve ; relis l'ISA et continue au lieu d'attendre une réponse humaine.

---

