# GALASS — état avant fix FullRun (2026-11-25)

Accès : `gh` refusé par le sandbox ; `git fetch` privé KO (auth). Refs locales complètes lues. Aucun code modifié ; aucun test exécuté (Flutter absent).

## Branches multistop (branche @ head)
- Galass_Rider: `feat/multistop-e2e-2026-11-15` @ `bceb7a0` — ISA 28/39 climbing, 11 ISC F4 ouverts.
- Galass_Driver: `feat/multistop-e2e-2026-11-15` @ `9208af6` — ISA `complete` incohérente, 14/20, 7 ISC F5 ouverts.
- Galass_backend: `feat/multistop-e2e-2026-11-15` @ `8523cf32` — 124/156, 29 cases `[ ]` + 5 bridges ouverts.
- galass-emu-actions-pub: `feat/multistop-e2e-2026-11-15` @ `0cc7a5c` — ISA 1/4 ; goldens/porte sur `feat/multistop-rider-close-2026-11-20` @ `b4b0c91`.
- galass-ci: `feat/multistop-e2e-2026-11-15` @ `10f1133` — pas d'ISA multistop ; 8 devant / 10 derrière main.

## Activité récente / diff vs main
- Rider: 15 commits = rapports r5/r6, autosave, fixes H1/H2 `ee14366`, M3 `b4a5c72`, revert F4-21. Diff 54 fichiers +4610/−170. Fait: F4-22/25/26/27 code + garde badge; reste preuves et F4-21/28/30/31.
- Driver: 15 = baseline goldens, checkpoints, F5-14 `fc2b822`, M3 `9208af6`. Diff 88 fichiers +11989/−321. Fait: F5-14 repère, F5-13 danger, D-11/CFG-1; reste F5-12/16/17/18.
- Backend: 15 = ISA F19 `8523cf32`, e2e cash-flow, checkpoints. Diff 73 fichiers +4964/−23. Fait: `RIDE_END`/details portent `stops` (ISC-64..67); reste preuves staging/device et bridges UI.
- Emu: 15 = composition/cash e2e, ISA harnais, nav content-desc `0eae2d1`. Diff e2e = ISA +119 ; close = 26 fichiers +3059/−105 (goldens/gate). Porte locale faite; EMU-1/2/3 non livrés.
- CI: 15 = start_step/autosave/verdicts, emu `--ref`/`head_branch`/KILL groupe `10f1133`. Diff 3 fichiers +461/−117. Fait: legs robustes; branche désynchronisée de main.

## (a) Correctifs UI (fichier:ligne, branche multistop)
- Rider F4-21 OUVERT: numérotation PENDING seulement (`lib/data/controller/map/ride_map_controller.dart:211`), repli `destinationIcon` (`:409-430`, cache rempli uniquement en PENDING), câblage sans index actif (`lib/data/controller/ride/ride_details/ride_details_controller.dart:438-453`).
- Rider F4-28/F4-31: SOS rendu seulement RUNNING (`lib/presentation/screens/ride/widget/ride_details_bottom_sheet_widget.dart:349-361`); pas de golden ACTIVE; CTA « prise en charge » absent → Papa.
- Rider fait code, non prouvé: F4-22 repère `galass.rider.stops` (`…bottom_sheet_widget.dart:125-131`); F4-25/26 tuile+message autonome (`:51-54`, `:647-730`); F4-27 liste complète (`lib/presentation/screens/ride/widget/ride_itinerary_timeline.dart:316-330`); F4-29 contrat partiel `test/widget/course_en_cours_contract_test.dart:88,104,115,126,153` (5 tests, éléments c-h manquants).
- Rider tests à retourner (rouges attendus): `test/unit/multistop_itinerary_test.dart:139-185` (F4-17 vs F4-27); `test/unit/multistop_running_sheet_test.dart:159-168,171-183,197-234` (tuile/badge/compteur).
- Driver F5-12 OUVERT: deux CTA, END seulement `isDisabled` (`lib/presentation/screens/ride_details/widgets/ride_details_bottom_sheet_widget.dart:219-260`); F5-16 icône uniforme (`lib/data/controller/map/ride_map_controller.dart:245-257`); F5-18 timeline sans `completedAt` (`lib/presentation/components/timeline/ride_itinerary_timeline.dart:342-359`); F5-17 contrat absent (`test/widget/` vide).
- Driver fait: F5-14 repère `galass.driver.stops` (`…ride_details_bottom_sheet_widget.dart:72-80`); F5-13 danger `:199-207`; D-11 `rKv` (`lib/core/helper/string_format_helper.dart:212-218`).
- Backend: `RIDE_END` charge `stops` avant l'event (`core/app/Http/Controllers/Api/Driver/RideController.php:152,192-194`); details/cash portent stops.

## (b) ISC multistop restants + preuve nécessaire
- Rider (11): F4-21..31. Preuves: flips tests widgets verts; helpers + capture e2e carte active/estompée (aucun golden ne contient `GoogleMap` → F4-10/21 = unit+e2e); goldens ACTIVE et sha distincts (F4-30: `course_en_cours_simple` == `tous_arrets_faits`); e2e Bridge-B3 create 2 stops → GET détail même ordre; décisions Papa F4-28/F4-30; éléments c-h du contrat F4-29.
- Driver (7): F5-12..18. Preuves: créer `test/widget/course_en_cours_driver_contract_test.dart`; unit `primaryRideActionFor`/`stopMarkers`; golden stop1/stop2 distincts; captures e2e; accept Papa F5-17.
- Backend: bloquants = Bridge-F4-1, Bridge-F4-3 (tarif), Bridge-F5-2 (segment courant), ISC-F4-6; ISC-39/39.1/39.2 (logs Pusher staging); ISC-24.1/24.2 (smoke staging); Bridge-F17-3/ISC-F17-4 (resync rider); ISC-F18-2/18-1b/Anti-F18-1 (start driver); ISC-61.1..7 (push device); ISC-21/22/23/45 (deploy SHA).
- Emu: ISC-EMU-1 — les apps exposent déjà les repères mais `e2e/run.sh:117-118,143-144` lit encore le texte compteur et `e2e/ui.sh` n'a pas de chemin réservé `^galass\.(rider|driver)\.stops=\d+/\d+$`; ISC-EMU-2/3 non livrés; ISC-EMU-4 coché sur preuve locale seulement.

## (c) Goldens / preuve pixel L2
- Rider: 10 PNG sur la branche Rider; `course_en_cours_simple.png` == `course_en_cours_tous_arrets_faits.png` (sha `4794e22d…`) → F4-30 faux; stop1 actif/fait distincts.
- Driver: 7 PNG sur la branche Driver; `driver_ride_running_multistop_stop_1_active.png` == `..._stop_2_active.png` (sha `9a571b18…`) → F5-18 faux.
- Porte (emu close `b4b0c91`): `goldens/gate.sh` restaure PNG + `*.dart` depuis la base, `flutter test` pixels stricts, exit 0/1/2; `goldens/board.py` planche; `.github/workflows/golden-diff.yml` (`workflow_dispatch` + `repository_dispatch`, Flutter 3.44.8, lecture seule, accept = `reason` obligatoire).
- Manque: workflow jamais dispatché; goldens Rider absents de `main` (`--base origin/main` → exit 2); `test/goldens/driver/` absent de `main`; porte Driver non branchée par défaut; ISC-EMU-1 non câblé. Bridge-B3 reste une preuve backend staging, pas un golden.

## (d) Tâches ordonnées pour un fix FullRun
1. Backend — `feat/multistop-e2e-2026-11-15`: smoke staging 24.1/24.2; logs `STOP_COMPLETED` 39/39.1/39.2; Bridge-F4-3 tarif; Bridge-F5-2; puis F17/F18.
2. Rider — `feat/multistop-e2e-2026-11-15`: flips tests F4-17/20/25; F4-21 sans changer `loadMap` (porteur `RideStopProgress`); compléter contrat F4-29 + F4-22/25/26/27; F4-31 capture ACTIVE; décisions F4-28/F4-30; preuve F4-10 + B3.
3. Driver — `feat/multistop-e2e-2026-11-15`: F5-12 CTA unique; F5-16 `stopMarkers`; F5-18 `completedAt`; créer F5-17; régénérer goldens via la porte.
4. Emu — `feat/multistop-rider-close-2026-11-20` (porte) et `feat/multistop-e2e-2026-11-15` (harnais): fusionner les goldens sur la référence; créer `test/goldens/driver` sur main; dispatcher `golden-diff`; câbler EMU-1 `content-desc` (run.sh + chemin réservé ui.sh); EMU-2/3.
5. CI — `feat/multistop-e2e-2026-11-15`: réconcilier avec `main` (10 commits) sans merge, rejouer `opencode/tests/with-emulators-test.sh`, puis un e2e courant avec `--ref`.
6. Clôture — preuves Rider/Driver/backend + golden gate + e2e P0 au même run; vérifier `flutter test`/PHPUnit; alors seulement FullRun.
