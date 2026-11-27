# galass-ci

CI **produit** des dépôts Galass (`Galass_Driver`, `Galass_Rider`, `Galass_backend`, `galass-emu-actions-pub`) : ce dépôt ne contient que ce qui teste, vérifie ou déploie le produit. Workflows :

- `phpunit.yml` — PHPUnit de `Galass_backend` (`workflow_dispatch` / `workflow_call`, `ubuntu-latest`, checkout privé via `GALASS_TOKEN`)
- `deploy-staging-branch.yml` — deploy staging d'une branche/SHA backend
- `isa-human-tick.yml` — coche une claim `[scope:human]` d'une ISA Galass via `opencode/allowed-repos.sh`

L'inventaire du nettoyage est dans `CLEANUP.md`. Le harnais opencode / FullRun / agents / prompts générique ne vit plus ici : les runs opencode sont dans [`LordThiouk/lifeos-ci`](https://github.com/LordThiouk/lifeos-ci).
