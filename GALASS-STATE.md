# GALASS — état branches multistop avant fix FullRun (2026-11-25)

Lecture seule via `origin/<branche>` : `gh` refusé par le sandbox, fetch HTTPS sans credentials échoue, refs locales déjà complètes. Aucun code produit modifié, aucun test exécuté (Flutter absent).

## Branches multistop (branche @ head)
- Galass_Rider: `feat/multistop-e2e-2026-11-15` @ `bceb7a0` (68 devant / 0 derrière main)
- Galass_Driver: `feat/multistop-e2e-2026-11-15` @ `9208af6` (28 / 0)
- Galass_backend: `feat/multistop-e2e-2026-11-15` @ `8523cf32` (110 / 1)
- galass-emu-actions-pub: `feat/multistop-e2e-2026-11-15` @ `0cc7a5c` (2 / 4) ; goldens/gate sur `feat/multistop-rider-close-2026-11-20` @ `b4b0c91` (26 / 0)
- galass-ci: `feat/multistop-e2e-2026-11-15` @ `10f1133` (8 / 10) — aucun ISA multistop.

## Activité (15 derniers commits, diff vs main)
- Rider: rapports r5/r6, autosave, H1/H2 `ee14366`, M3 `b4a5c72`, revert F4-21 (`b81224d`/`0008a46`). Diff 54 fichiers +4610/−170. Fait code: F4-22/25/26/27 + garde badge. Reste: preuves + F4-21/23/24/28/29/30/31.
- Driver: baseline goldens, F5-14 `fc2b822`, M3 `9208af6`. Diff 88 fichiers +11989/−321. Fait code: F5-14, F5-13 (déjà conforme), D-11 `rKv`. Reste: F5-12/16/17/18.
- Backend: ISA F19 `8523cf32` (F19-1..5/7 cochés, F19-4/6/7 ouverts), e2e cash-flow, checkpoints. Diff 73 fichiers +4964/−23. Fait: `RIDE_END`/details/cash portent `stops` (`RideController.php:26,152`). Reste: preuves staging/device, bridges UI.
- Emu e2e: harnais + nav content-desc `0eae2d1` ; close: gate.sh/board.py/golden-diff `b4b0c91`. Reste: EMU-1/2/3.
- CI: start_step/autosave/verdicts, `--ref`/head_branch/KILL `10f1133`. Diff 3 fichiers +461/−117.

## (a) Correctifs UI restant (fichier:ligne, branche multistop)
- Rider F4-21 OUVERT: cache numéroté seulement PENDING (`ride_map_controller.dart:205-206`), repli `destinationIcon` (`:411-425`, `numberStopMarkers` gate `:412`), câblage sans index actif (`ride_details_controller.dart:445-453` — `RideStopProgress` absent).
- Rider F4-28/F4-31: SOS seulement bloc RUNNING (`ride_details_bottom_sheet_widget.dart:350`); ACTIVE = `cancelRide` seul; CTA « prise en charge » absent → décision Papa.
- Rider fait code, non prouvé: F4-22 repère `galass.rider.stops` (`…bottom_sheet_widget.dart:128-134`); F4-25/26 tuile+message (`:51-55`, `:647-701`); F4-27 liste complète (`ride_itinerary_timeline.dart:193-305`); F4-29 contrat 5 tests seulement (`test/widget/course_en_cours_contract_test.dart:88,104,115,126,153` — éléments c-h manquants); F4-24 test de reset absent.
- Rider tests à retourner (rouges attendus): `multistop_itinerary_test.dart:116-185` (F4-17 collapse vs F4-27); `multistop_running_sheet_test.dart:133-233` (tuile/badge/compteur).
- Driver F5-12 OUVERT: deux CTA, END `isDisabled` (`ride_details_bottom_sheet_widget.dart:219-260`); F5-16 icône uniforme `destinationIcon` (`ride_map_controller.dart:245-275`); F5-18 timeline sans `completedAt` (`ride_itinerary_timeline.dart:342-364`); F5-17 `test/widget/` absent.
- Driver fait: F5-14 repère `galass.driver.stops` (`…ride_details_bottom_sheet_widget.dart:75-79`); F5-13 danger `:200-206`; D-11 `rKv` (`string_format_helper.dart:212`).
- Backend: `RIDE_END` charge `stops` (`RideController.php:152,192`); details/cash portent stops.

## (b) ISC multistop restants + preuve nécessaire
- Rider ISA `MEMORY/WORK/20261006-galass-rider-multistop/ISA.md`: climbing 28/39, F4-21..31 ouverts (11) + B3/B7. Bloquants: flips tests widgets verts; F4-21 = unit+e2e (aucun golden ne contient `GoogleMap`); F4-22/25/26/27 prouvés e2e; F4-29 éléments c-h; F4-30 sha distincts; F4-31 golden ACTIVE; F4-28 décision Papa; Bridge-B3 = e2e backend 2 stops → GET détail même ordre.
- Driver ISA `MEMORY/WORK/20261006-galass-driver-multistop/ISA.md`: phase `complete` incohérente, 14/20 (F5-12..17 `[ ]`, F5-18 en table). Preuves: contrat `course_en_cours_driver_contract_test.dart` (à créer), unit `primaryRideActionFor`/`stopMarkers`, goldens stop1/stop2 distincts, captures e2e, accept F5-17.
- Backend ISA `MEMORY/WORK/20261006-galass-regression-multistop/ISA.md`: 124/156; 34 ISC `[ ]` (ISC-F4-6/Bridge-B3, Bridge-F4-1/F4-3/F5-2, Anti-F18-1). Bloquants: ISC-24.1/24.2 et ISC-39/39.1/39.2 (staging), ISC-61.1..7 (device), ISC-21/22/23/45 (deploy SHA), ISC-F17-4/F18-2/18-1b (resync/start driver).
- Emu ISA `MEMORY/WORK/20261123-galass-emu-golden-anti-regression/ISA.md`: 1/4; EMU-1/2/3 ouverts, EMU-4 `[x]` sur preuve locale. EMU-1: apps exposent le repère mais `e2e/run.sh:117-118,143-144` lit encore le texte compteur (`:106` négatif `-Arrêt 2`) et `e2e/ui.sh` n'a pas de chemin réservé `^galass\.(rider|driver)\.stops=\d+/\d+$`.

## (c) Goldens / preuve pixel L2
- Rider: 10 PNG sur la branche; `course_en_cours_simple.png` == `course_en_cours_tous_arrets_faits.png` (sha `4794e22d…`) → F4-30 faux; aucun golden ACTIVE.
- Driver: 7 PNG (`test/goldens/driver/goldens/`); `stop_1_active` == `stop_2_active` (sha `9a571b18…`) → F5-18 faux.
- Porte (emu close `b4b0c91`): `goldens/gate.sh` restaure PNG + `*.dart` depuis `origin/<base>`, `flutter test` pixels stricts, exit 0/1/2; `goldens/board.py` planche; `.github/workflows/golden-diff.yml` (`workflow_dispatch` + `repository_dispatch`, accept = `reason` obligatoire).
- Manque: workflow jamais dispatché; `test/goldens/{rider,driver}` absents de `main` (`--base origin/main` → exit 2); porte Driver non branchée; ISC-EMU-1 non câblé. Bridge-B3 reste une preuve backend staging, pas un golden.

## (d) Tâches ordonnées pour un fix FullRun
1. Backend — `feat/multistop-e2e-2026-11-15`: smoke staging 24.1/24.2; logs `STOP_COMPLETED` 39/39.1/39.2; Bridge-F4-3 tarif; Bridge-F5-2; puis F17/F18.
2. Rider — `feat/multistop-e2e-2026-11-15`: flips tests F4-17/20/25; F4-21 sans changer `loadMap` (porteur `RideStopProgress`); compléter contrat F4-29 + F4-22/25/26/27; F4-31 capture ACTIVE; décisions F4-28/F4-30; preuve F4-10 + B3.
3. Driver — `feat/multistop-e2e-2026-11-15`: F5-12 CTA unique; F5-16 `stopMarkers`; F5-18 `completedAt`; créer F5-17; régénérer goldens via la porte.
4. Emu — `feat/multistop-rider-close-2026-11-20` (porte) et `feat/multistop-e2e-2026-11-15` (harnais): fusionner les goldens sur la référence; créer `test/goldens/driver` sur main; dispatcher `golden-diff`; câbler EMU-1 (`run.sh` + `ui.sh`); EMU-2/3.
5. CI — `feat/multistop-e2e-2026-11-15`: réconcilier avec `main` (10 commits) sans merge, rejouer `opencode/tests/with-emulators-test.sh`, puis un e2e courant avec `--ref`.
6. Clôture — preuves Rider/Driver/backend + golden gate + e2e P0 au même run; vérifier `flutter test`/PHPUnit; alors seulement FullRun.
