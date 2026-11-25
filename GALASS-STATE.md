# GALASS — état avant fix FullRun (2026-11-25)

Accès : `gh` refusé par le sandbox ; Rider/Driver/backend = clones shallow `main` seul (API 404, fetch auth KO). Seuls galass-ci et galass-emu-actions-pub ont pu être fetchés. Les tips multi-branches privés viennent de l'état/ISA du 2026-11-23, non re-vérifiés ce run.

## Branches (branche multistop + head)
- Galass_Rider : `feat/multistop-rider-close-2026-11-20` @47a2ee2 (tip cité ISA, non fetché ; 3a3731e cité plus récent) ; main @7984da7.
- Galass_Driver : `feat/multistop-e2e-2026-11-15` @c9c65ff (tip cité ISA, non fetché) ; main @9b34386 ; e2e workflow défaut `fix/multistop-close` (à réconcilier).
- Galass_backend : `fix/multistop-notifs` @3820b623 (tip cité ISA, non fetché) ; main @2aa0dcd1 (ISA 95/125, 39 ouverts).
- galass-emu-actions-pub : `feat/multistop-e2e-2026-11-15` @0cc7a5c (plus récent ; diff main = ISA + `e2e/run.sh`, 2 fichiers +122/-45, pas de merge-base) ; `feat/multistop-rider-close-2026-11-20` @b4b0c91 (goldens ; diff main 26 fichiers +3059/-105) ; main @33f9ab9.
- galass-ci : `feat/multistop-e2e-2026-11-15` @10f1133 (15 commits emu/fullrun ; diff main +461/-117 sur `opencode/emu-e2e.sh`, `opencode/tests/with-emulators-test.sh`, `opencode-fullrun.yml`) ; état `state/galass-2026-11-25` @5db110f ; main @a34cab2.

## (a) Correctifs UI (file:line, lus sur main ; branche close non fetchée)
- Rider ACTIVE : pas de SOS/notes/profil — `lib/presentation/screens/ride/widget/ride_details_bottom_sheet_widget.dart:172-269` ; SOS seulement RUNNING `:272-306` (contrats F4-26/27 FAIL).
- Rider notes : texte figé `lib/core/utils/my_strings.dart:155`, rendu `ride_details_bottom_sheet_widget.dart:606` au lieu de `ride.note` (régression F4-25).
- Rider timeline : RUNNING ne garde qu'une jambe `lib/presentation/screens/ride/widget/ride_itinerary_timeline.dart:248-294` ; sans `stops` dans RIDE_END, seul Destination (R8-2 ; backend ISC-65 clos mais preuve device absente).
- Rider compteur x/N : `ride_details_bottom_sheet_widget.dart:684` ; retirer le texte, poser Semantics/Key stable (ISC-F4-22).
- Rider carte ACTIVE : `lib/data/controller/ride/ride_details/ride_details_controller.dart:404-418` ne numérote que PENDING ; preuve device pins sans numéro + polyline (ISC-F4-10).
- Driver placeholders : `.rKv` remplace `{clé}` mais chaînes en `@clé` — `lib/presentation/components/dialog/custom_new_ride_dialog.dart:442-446`, `lib/presentation/screens/rides/home_screen/widget/new_ride_card.dart:238-242`, `lib/core/utils/my_strings.dart:82` → `@priceKey/@distanceKey` bruts (D-11).
- Driver build : `lib/core/route/route.dart:7` importe `screens/Profile/` alors que le dossier est `profile/` → échec Linux/CI (CFG-1).
- Driver compteur : `lib/presentation/components/timeline/ride_itinerary_timeline.dart:76-90` + `my_strings.dart:77-80` ; retrait x/N + Semantics (ISC-F5-14).

## (b) ISCs multistop restants + preuve
- Rider ISA `MEMORY/WORK/20261006-galass-rider-multistop/ISA.md` : 23/26, `climbing`. Ouverts : Bridge-B3 (ordre stops), Device ACTIVE F4-10, Bridge-B6 ; F4-22/F4-25..29 sur branche close. Preuve : e2e staging create 2 stops → GET detail, captures device, contrats widget, golden-diff.
- Backend ISA `MEMORY/WORK/20261006-galass-regression-multistop/ISA.md` : 95/125, 39 ouverts. Bloquants : Bridge-F4-1/F4-3, ISC-F4-6, Bridge-F5-2, ISC-F5-5, ISC-39/39.1/39.2, ISC-24.1/24.2, ISC-21/22/22.1/22.4/23, ISC-45/45.1, ISC-56.1, ISC-61.1..61.7. Preuve : logs Pusher staging, smoke staging, device dumpsys, e2e.
- Driver ISA 18/18 complete ; F6 (ISC-F5-14/17) reste à livrer/prouver.
- galass-ci : pas d'ISA multistop ; leg emu-e2e fonctionnel (dispatch `--ref`, garde `head_branch`, kill du groupe de processus), reste à prouver par un run courant.

## (c) Goldens / preuve pixel
- Vit dans `galass-emu-actions-pub`, branche `feat/multistop-rider-close-2026-11-20` @b4b0c91 : `goldens/gate.sh`, `goldens/board.py`, `.github/workflows/golden-diff.yml`, ISA `MEMORY/WORK/20261123-galass-emu-golden-anti-regression/ISA.md` (1/4).
- `gate.sh` restaure PNG + `*.dart` depuis la base, lance `flutter test test/goldens/<app>` (pixels stricts, sans seuil), exit 0/1/2 ; workflow `workflow_dispatch` + `repository_dispatch` `golden-diff`, lecture seule, accept seulement avec `reason`.
- Mesuré 2026-11-23 : base 7984da7+goldens (08cc8cd) VERT 10/10 ; Rider 47a2ee2 ROUGE 5/10 (max 27,33 %) ; F4-25 PASS main/FAIL branche, F4-26/27 FAIL/FAIL (préexistant), F4-28 PASS/PASS.
- Manque : goldens non fusionnés sur main Rider (`--base origin/main` exit 2), `test/goldens/driver/` absent, workflow jamais dispatché, ISC-EMU-1 bloqué (contrat de clé), ISC-EMU-2/3 non livrés. B3 existe (`e2e/b3_order.py`, `compose_order.py`) mais aucun run courant.

## (d) Tâches ordonnées pour un fix FullRun
1. Débloquer git authentifié (fetch/unshallow Rider, Driver, backend via secret CI, jamais en dur) et refaire l'état multi-branches réel.
2. Backend (`fix/multistop-notifs`) : STOP_COMPLETED + logs ISC-39/39.1/39.2 ; `stops` dans RIDE_END/cash ISC-64..66 ; ISC-24.2 staging ; Bridge-F4-3 tarif.
3. Rider (`feat/multistop-rider-close-2026-11-20`) : SOS/notes/profil ACTIVE ; retrait x/N + Semantics F4-22 ; contrats F4-25..29 ; carte ACTIVE F4-10 ; timeline R8-2.
4. Driver (`feat/multistop-e2e-2026-11-15`) : retrait x/N + Semantics F5-14 ; résumé stops offre ; placeholders D-11 ; CFG-1 ; contrat F5-17.
5. Goldens (`feat/multistop-rider-close-2026-11-20` emu) : fusionner `test/goldens/rider`, créer `test/goldens/driver`, dispatcher `golden-diff`, accepter la base explicitement.
6. E2E (`feat/multistop-e2e-2026-11-15` emu + galass-ci) : marqueurs sur repère stable (ISC-EMU-1), porte B3 + verdict global ISC-EMU-3.
7. Preuves et clôture : Bridge-B3/B6, device F4-10, dual-write SHA, flutter test/phpunit, puis FullRun.
