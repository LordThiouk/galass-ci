# REVIEW — PR `clean/product-ci-2026-11-25` (galass-ci)

## Verdict : MERGE OK

Le nettoyage est sain : 51 fichiers supprimés, tous du harnais opencode/FullRun
(`opencode/` + les 3 workflows de harnais), et il ne reste que la CI produit
(`isa-human-tick.yml` + sa liste blanche `opencode/allowed-repos.sh`). Les points
ci-dessous sont des finitions (commentaires/doc), aucun blocage fonctionnel.

## Points hauts

Aucun.

## Points moyens

1. **Références obsolètes au workflow supprimé** — `.github/workflows/isa-human-tick.yml:6,8,9,15,53`
   citent encore `opencode-fullrun.yml` (fichier supprimé). Aucune dépendance
   fonctionnelle (le workflow ne source que `opencode/allowed-repos.sh`, conservé, en
   `:101`), mais le contrôle (b) « les workflows restants ne référencent aucun fichier
   supprimé » échoue au niveau des commentaires. Repointer vers `LordThiouk/lifeos-ci`
   ou reformuler.
2. **Liste blanche dupliquée sans garde** — `opencode/allowed-repos.sh:10` et
   `.github/workflows/isa-human-tick.yml:19-22` répètent la même liste. Le test qui
   garantissait la synchro (`opencode/tests/allowed-repos-test.sh`) est supprimé : plus
   rien ne détecte une dérive (qui provoquerait un refus runtime peu clair). Soit
   dériver les `options:` de `allowed_repos_list`, soit garder un test léger.
3. **Prompt générique laissé dans le dépôt produit** — `prompts/review-clean.md:1-8` est
   ajouté par la PR et n'apparaît pas dans l'inventaire `CLEANUP.md`. C'est un prompt de
   tâche de review (harnais), exactement la catégorie que `CLEANUP.md:68` déclare
   `REMOVE`. À supprimer, ou à documenter explicitement comme conservé.

## Points bas

4. **Commentaires obsolètes** — `opencode/allowed-repos.sh:3` cite `extra-repos.sh`,
   `livelog.sh`, `wippush.sh` (supprimés) et `:5-6` cite `allowed-repos-test.sh`
   (supprimé). Mettre à jour pour ne référencer que `isa-human-tick.yml`.
5. **Inventaire inexact** — `CLEANUP.md:68` liste `prompts/clean-product-ci.md` en
   `REMOVE`, mais ce fichier n'existe pas sur `origin/main`. Le fichier réel est
   `prompts/review-clean.md` (voir point 3).
6. **« doublon identique » inexact** — `CLEANUP.md:27` qualifie `opencode/emu-e2e.sh` de
   « doublon identique lifeos-ci » ; le diff montre que la copie lifeos-ci est plus
   récente (ex. `status` sort en code 2). Toujours supprimable (superseded), mais
   reformuler en « doublon (lifeos-ci plus récent) ».
7. **URL ajoutée** — `README.md:3` ajoute `https://github.com/LordThiouk/lifeos-ci` :
   lien public légitime, aucun secret.

## Contrôles demandés

- **(a) Fichiers supprimés = harnais, pas produit** : OK. Tous sous `opencode/` ou les
   workflows de harnais. Comparaison avec `LordThiouk/lifeos-ci` : 10 identiques, 9
   différents uniquement parce que lifeos-ci est en avance (rebrand antenly, features
   supplémentaires) ; aucune logique produit perdue. `opencode/emu-e2e.sh` n'est qu'un
   déclencheur FullRun du e2e produit, qui reste dans `galass-emu-actions-pub`.
- **(b) Aucune référence fonctionnelle à un fichier supprimé** : OK côté exécution ;
   restes en commentaires (point 1).
- **(c) Aucun secret dans le diff** : OK. Seule URL ajoutée = README public (point 7).
- **(d) YAML restant valide** : OK (`python3` + `yaml.safe_load` sur
   `.github/workflows/*.yml`). `shellcheck opencode/allowed-repos.sh` : OK.

## Produit vs lifeos-ci

`isa-human-tick.yml` est **produit** : options limitées aux dépôts Galass, coche une claim
`[scope:human]` d'une ISA Galass, pousse via `GALASS_TOKEN` ; absent de lifeos-ci. Sa
dépendance `opencode/allowed-repos.sh` (liste blanche Galass) doit donc rester ici pour
que le workflow soit autonome. `ci.yml` ne testait que le harnais (age, done_check,
lifeos) : sa suppression est attendue.
