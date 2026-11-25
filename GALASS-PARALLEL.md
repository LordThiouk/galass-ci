# FullRun correctif vs multistop — parallèle ?

Lecture seule via `origin/<b>` (aucun checkout/commit produit). État au 2026-11-25.

## 1. Branche corrective la plus récente avec ISA (+ commits devant main)
- galass-ci — `fix/porte-carry-perime-2026-11-24` @ `70f35d5` (+1, doublon déjà mergé #21). Aucun ISA : galass-ci n'en porte plus.
- Galass_Rider — `fix/multistop-close` @ `5b2533f` (+6 ; fork main 2026-10-12). ISA `20261006-galass-rider-multistop` 25/27 : 5 ISC ouverts (Bridge-B3, ISC-F4-8, F4-3.4, device ACTIVE, Bridge-B3 staging).
- Galass_Driver — `fix/multistop-close` @ `fe153c0` (+8 ; fork main 2026-10-10). ISA `20261006-galass-driver-multistop` 14/17 : 13 ouverts (Bridge-B6, F5-5/12/13, Anti-F5-4, dettes A1-A7, preuves device).
- Galass_backend — pas de correctif actif avec ISA : `fix/multistop-notifs` @ `98f3fe2` EST le merge-base (déjà mergée, +0) ; le plus récent nommé « bugs » est `docs/bugs-triage` @ `c40c30d` (+8) mais docs/BUGS.md seul, sans ISA, 39 ISC ouverts dans l'ISA parent multistop.
- galass-emu-actions-pub — aucun `fix/bug` ne porte d'ISA ; l'ISA EMU vit sur `feat/multistop-rider-close-2026-11-20` @ `b4b0c91` (+26) : EMU-1/2/3 ouverts + 14 notes bloquantes.

## 2. Fichiers touchés par les DEUX branches (merge-base correctif/multistop)
- Rider : 17 fichiers communs (31 vs 54) — `home_controller.dart`, `ride_details_bottom_sheet_widget.dart`, `string_format_helper.dart`, `my_strings.dart`, `url_container.dart`, `location_picker_screen.dart`, ISA, tests multistop, AGENTS/CLAUDE.
- Driver : 60 fichiers communs (75 vs 88) — `dispatch_offer_*` (alert/presenter/state/snapshot/headless), `pusher_ride_controller.dart`, `ride_details_controller.dart`, `ride_meassage_controller.dart`, `custom_new_ride_dialog.dart`, `string_format_helper.dart`, `main.dart`, manifests Android, ISA, tests dispatch/multistop.
- Backend : 0 (le correctif est déjà le merge-base) ; `docs/bugs-triage` ne touche que `docs/BUGS.md`, aucun code.
- Emu : 1 fichier commun, `MEMORY/WORK/20261123-galass-emu-golden-anti-regression/ISA.md` (close touche e2e/goldens ; e2e n'ajoute que l'ISA).
- galass-ci : 3 fichiers communs (28 vs 3) — `.github/workflows/opencode-fullrun.yml`, `opencode/emu-e2e.sh`, `opencode/tests/with-emulators-test.sh` (venus de main côté correctif ; le commit `70f35d5` seul ne touche que `merge-signed-carry*` + `ci-preamble.md`).

## 3. Verdict : SEQUENTIAL
Raison : sur Rider et Driver, le correctif et le multistop réécrivent les mêmes contrôleurs/services depuis des forks divergents (main 2026-10-10/12) ; deux FullRuns parallèles se marcheraient dessus et écriraient le même ISA.
Ordre : lancer le **multistop d'abord** (branche active, +68 Rider / +28 Driver), puis rejouer/rebase le correctif dessus.
Backend/emu : aucun conflit code, FullRuns suivants possibles en parallèle (emu : sérialiser l'écriture de l'ISA). galass-ci : 3 fichiers CI communs, les relancer seulement une fois les deux branches mergées/sérialisées.
CI : des branches différentes peuvent tourner en même temps, mais runner self-hosted, émulateurs et staging sont partagés → sérialiser les étapes e2e/device.
