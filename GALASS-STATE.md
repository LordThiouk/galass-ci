# GALASS — état avant fix FullRun (2026-11-25)

Périmètre : galass-ci `state/galass-2026-11-25` @8cefd2f ; extra Rider 7984da7, Driver 9b34386, backend 2aa0dcd1, emu main 33f9ab9 / branche close b4b0c91.
Limite : Rider/Driver/backend = clones superficiels (1 commit) ; fetch `+refs/heads/*` refusé (auth). Tips multi-branches cités par les ISAs : Rider close 3a3731e/47a2ee2, Driver e2e c9c65ff, backend notifs 3820b623, triage c40c30de.
Derniers commits multi-branches : Rider/Driver/backend indisponibles (shallow) ; emu 0cc7a5c 308decf b4b0c91 c6a782e bfabf60 da9814d f7753d0 f19369a 6ab3d66 3c35e43.

## Dépôts et branches
- Galass_Rider : main 7984da7 (F8 post-accept) ; branche `feat/multistop-rider-close-2026-11-20` (F9-F11 + goldens). Reste F4-10/B3/B6 + contrats F10/F11.
- Galass_Driver : main 9b34386 (1.1.1+53, multistop device clos) ; branche `feat/multistop-e2e-2026-11-15` (c9c65ff, e2e). Reste F6/F5-14/F5-17 + CFG-1.
- Galass_backend : main 2aa0dcd1 (ISA lot client 0/67, plan) ; multistop parent 95/125 ; branches `fix/multistop-notifs` (3820b623), `docs/bugs-triage-2026-11-22` (c40c30de).
- galass-emu-actions-pub : main 33f9ab9 (F19) ; 9 branches ouvertes (multistop-e2e, multistop-rider-close, e2e-artemis-hang, e2e-harness-wip, e2e-offer-flow, e2e-smoke-log, e2e-vision-chain, real-places, staging-http-guard). Reste ISC-EMU-1/2/3 + goldens Driver + dispatch workflow.
- galass-ci : branche courante 8cefd2f ; main a34cab2 ; branches fullrun/carry (dont `fix/porte-carry-perime-2026-11-24`, `feat/fullrun-chain-secure-2026-11-22`).

## (a) Correctifs UI (file:line)
- Rider ACTIVE : pas de SOS/notes/profil — `.../ride/widget/ride_details_bottom_sheet_widget.dart:172-269` ; SOS seulement RUNNING `:272-306`. Contrats F4-26/27 FAIL sur main et branche.
- Rider notes : texte figé `my_strings.dart:155`, rendu `ride_details_bottom_sheet_widget.dart:606` au lieu de `ride.note` (régression F4-25).
- Rider timeline : RUNNING ne garde qu'une jambe `ride_itinerary_timeline.dart:248-294` ; sans `stops` dans RIDE_END, seul Destination (R8-2 ; backend ISC-65).
- Rider compteur x/N + repère stable : `ride_details_bottom_sheet_widget.dart:684` et `ride_itinerary_timeline.dart` ; retirer le texte, poser Semantics/Key (ISC-F4-22).
- Rider carte ACTIVE : `ride_details_controller.dart:404-418` ne numérote que PENDING ; preuve device pins sans numéro + polyline (ISC-F4-10).
- Driver placeholders : `.rKv` remplace `{clé}` mais chaînes en `@clé` — `custom_new_ride_dialog.dart:442-446`, `new_ride_card.dart:238-242`, `my_strings.dart:82` → `@priceKey/@distanceKey` bruts (D-11).
- Driver build : `lib/core/route/route.dart:7` importe `screens/Profile/` au lieu de `profile/` → échec Linux/CI (CFG-1).
- Driver compteur : `components/timeline/ride_itinerary_timeline.dart:76-90` + `my_strings.dart:77-80` ; retrait x/N + Semantics (ISC-F5-14).

## (b) ISCs multistop restants et preuve
- ISA Rider `MEMORY/WORK/20261006-galass-rider-multistop/ISA.md` (pas de dossier `ISAs/` ; 23/26) : Bridge-B3 (ordre stops), Device ACTIVE F4-10, Bridge-B6 ; ISC-F0-1 SHA repo=LifeOS déjà égal (item Remaining Work périmé).
- Branche close Rider : ISC-F4-22 (repère stable), F4-25..29 (contrats d'écran) ; preuves device/e2e + golden-diff.
- ISA backend parent `MEMORY/WORK/20261006-galass-regression-multistop/ISA.md` (95/125, 39 ouverts) : Bridge-F4-1 (ajout/suppr/réordre), Bridge-F4-3 (tarif après stops, R8-5), ISC-F4-6, Bridge-F5-2, ISC-F5-5, ISC-39/39.1/39.2, ISC-24.2, ISC-21/22/23/24.1, ISC-45/45.1, ISC-56.1, ISC-61.1..61.7.
- Driver ISA 18/18 complete ; F6 (ISC-F5-14/17) reste à livrer/prouver.
- Preuve minimale : e2e staging create 2 stops → GET detail (B3), B6 ≤5 s, captures device F4-10, contrats F4-25..29/F5-17, golden-diff vert.

## (c) Goldens / preuve pixel
- Vit dans `galass-emu-actions-pub`, branche `feat/multistop-rider-close-2026-11-20` : `goldens/gate.sh`, `goldens/board.py`, `.github/workflows/golden-diff.yml`, ISA `MEMORY/WORK/20261123-galass-emu-golden-anti-regression/ISA.md` (1/4).
- `gate.sh` restaure PNG + `*.dart` depuis la base, lance `flutter test test/goldens/<app>` (pixels stricts, sans seuil), exit 0/1/2 ; workflow `workflow_dispatch` + `repository_dispatch` `golden-diff`, lecture seule, accept seulement avec `reason`.
- Mesuré 2026-11-23 : base 7984da7+goldens (08cc8cd) VERT 10/10 ; Rider 47a2ee2 ROUGE 5/10 (max 27,33 %) ; F4-25 PASS main/FAIL branche, F4-26/27 FAIL/FAIL (préexistant), F4-28 PASS/PASS.
- Manque : goldens non fusionnés sur main Rider (`--base origin/main` exit 2), `test/goldens/driver/` absent, workflow jamais dispatché, ISC-EMU-1 bloqué (contrat de clé), ISC-EMU-2/3 non livrés. B3 existe (`e2e/b3_order.py`, `compose_order.py`) mais aucun run courant.

## (d) Tâches ordonnées pour un fix FullRun
1. Débloquer git authentifié (fetch/unshallow Rider, Driver, backend via secret CI, jamais en dur) et refaire l'état multi-branches réel.
2. Backend d'abord : STOP_COMPLETED + logs ISC-39/39.1/39.2 ; `stops` dans RIDE_END/cash ISC-64..66 ; ISC-24.2 staging ; Bridge-F4-3 tarif.
3. Rider : SOS/notes/profil ACTIVE ; retrait x/N + Semantics F4-22 ; contrats F4-25..29 ; carte ACTIVE F4-10 ; timeline R8-2.
4. Driver : retrait x/N + Semantics F5-14 ; résumé stops offre ; placeholders D-11 ; CFG-1 ; contrat F5-17.
5. Goldens : fusionner `test/goldens/rider`, créer `test/goldens/driver`, dispatcher `golden-diff`, accepter la base explicitement.
6. E2E : marqueurs sur repère stable (ISC-EMU-1), porte B3 + verdict global ISC-EMU-3.
7. Preuves et clôture : Bridge-B3/B6, device F4-10, dual-write SHA, flutter test/phpunit, puis FullRun.
