#!/usr/bin/env bash
# Option with_emulators du FullRun : entrée (défaut false), outil emu-e2e.sh
# (déclenchement distant sur galass-emu-actions-pub), pas de secrets e2e sur
# galass-ci, pas de FreeLLM ni d'appel HTTP direct à un modèle.
#   opencode/tests/with-emulators-test.sh
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=opencode/tests/lib.sh
. "$here/tests/lib.sh"
# shellcheck source=opencode/allowed-repos.sh
. "$here/allowed-repos.sh"

wf="$here/../.github/workflows/opencode-fullrun.yml"
sh="$here/emu-e2e.sh"
[ -f "$wf" ] || ko "workflow introuvable : $wf"
[ -x "$sh" ] || ko "emu-e2e.sh introuvable ou non exécutable"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- 1. liste blanche inchangée ----------------------------------------------
allowed_repo galass-emu-actions-pub || ko "galass-emu-actions-pub doit rester dans la liste blanche"
allowed_repo Galass_Rider || ko "Galass_Rider doit rester dans la liste blanche"
allowed_repo Galass_Driver || ko "Galass_Driver doit rester dans la liste blanche"
ok "liste blanche : dépôts Galass et emu inchangés"

# --- 2. prompt : chemin figé, pas de secret, pas de FreeLLM / HTTP modèle -----
blk=$("$sh" prompt-block)
printf '%s' "$blk" | grep -q '/opt/fullrun-tools/emu-e2e.sh' || ko "prompt sans le chemin figé emu-e2e.sh"
printf '%s' "$blk" | grep -q 'artemis-staging-e2e.yml' || ko "prompt sans le workflow emu"
printf '%s' "$blk" | grep -q 'galass-emu-actions-pub' || ko "prompt sans le dépôt emu"
printf '%s' "$blk" | grep -qi 'pas de FreeLLM' || ko "prompt doit interdire FreeLLM"
printf '%s' "$blk" | grep -q 'opencode/deepseek-v4.1-flash-free' || ko "prompt sans le modèle opencode/*-free par défaut"
printf '%s' "$blk" | grep -q 'opencode/\*-free' || ko "prompt doit rappeler les modèles opencode/*-free"
printf '%s' "$blk" | grep -qE 'https?://opencode.ai|OPENAI_API_KEY|OPENAI_BASE_URL|FREELLMAPI|GALASS_STAGING_URL|GALASS_E2E_|DEBUG_KEYSTORE' \
  && ko "prompt ne doit pas contenir d'URL d'API modèle ni de nom de secret e2e"
mkdir -p "$tmp/oc"
printf 'preamble\n' > "$tmp/oc/prompt.md"
OC_WORK="$tmp/oc" "$sh" append-prompt >/dev/null
grep -q '/opt/fullrun-tools/emu-e2e.sh' "$tmp/oc/prompt.md" || ko "append-prompt n'a pas écrit le bloc"
ok "prompt-block / append-prompt : outil distant, sans secret"

# --- 3. resolve-refs et run : gh mocké, jeton jamais affiché ------------------
tok="e2e-tok-$(rand_alnum 24)"
printf '%s\n' "$tok" > "$tmp/token"
chmod 600 "$tmp/token"
: > "$tmp/gh.log"
# Branches simulées : Rider a la branche de travail, Driver non → main.
cat > "$tmp/mock-gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${EMU_E2E_GH_LOG:?}"
cmd="${1:-}"; shift || true
case "$cmd" in
  api)
    silent=0 path=""
    for a in "$@"; do
      case "$a" in
        --silent) silent=1 ;;
        repos/*) path="$a" ;;
      esac
    done
    case "$path" in
      repos/LordThiouk/Galass_Rider/branches/feat%2Fmulti) exit 0 ;;
      repos/LordThiouk/Galass_Driver/branches/feat%2Fmulti) exit 1 ;;
      *) exit 1 ;;
    esac
    ;;
  workflow)
    [ "${1:-}" = run ] || exit 2
    printf '%s\n' "$*" >> "${EMU_E2E_GH_LOG}.dispatch"
    exit 0
    ;;
  run)
    sub="${1:-}"; shift || true
    case "$sub" in
      list)
        # Un run créé juste après le since du script.
        printf '%s\n' '[{"databaseId":4242,"createdAt":"2099-01-01T00:00:00Z","status":"in_progress","conclusion":"","url":"https://example.test/4242"}]'
        ;;
      view)
        id="${1:-}"
        if printf '%s\n' "$*" | grep -q -- '--log-failed'; then
          # Journal volontairement long, avec le jeton au milieu : l'outil doit le couper et le masquer.
          i=1
          while [ "$i" -le 200 ]; do
            if [ "$i" -eq 195 ]; then
              echo "fail line ${i} token=${EMU_E2E_FAKE_TOKEN:-secret} boom"
            else
              echo "fail line ${i} xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
            fi
            i=$((i + 1))
          done
        else
          printf '%s\n' '{"status":"completed","conclusion":"failure","url":"https://example.test/4242","displayTitle":"e2e"}'
        fi
        ;;
      *) exit 2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$tmp/mock-gh"

export EMU_E2E_GH="$tmp/mock-gh"
export EMU_E2E_GH_LOG="$tmp/gh.log"
export EMU_E2E_TOKEN_FILE="$tmp/token"
export EMU_E2E_FAKE_TOKEN="$tok"
export OC_BRANCH="feat/multi"
export EMU_E2E_TIMEOUT_SEC=5
export EMU_E2E_POLL_SEC=0
export EMU_LOG_TAIL=20
export EMU_LOG_WIDTH=120
export GITHUB_ACTIONS=true

refs=$(EMU_E2E_GH="$tmp/mock-gh" EMU_E2E_TOKEN_FILE="$tmp/token" OC_BRANCH="feat/multi" \
  "$sh" resolve-refs)
printf '%s\n' "$refs" | grep -qx 'rider_ref=feat/multi' || ko "rider_ref devrait être la branche de travail, obtenu : $refs"
printf '%s\n' "$refs" | grep -qx 'driver_ref=main' || ko "driver_ref devrait retomber sur main, obtenu : $refs"
printf '%s\n' "$refs" | grep -q 'Galass_Driver' || ko "resolve-refs doit signaler le fallback Driver"
printf '%s\n' "$refs" | grep -Fq "$tok" && ko "jeton fuité dans resolve-refs"
ok "resolve-refs : branche de travail ou main, sans fuite"

# Modèle non opencode/*-free refusé (avant tout appel réseau).
if out=$(EMU_E2E_MODEL=gemini-2.5-flash "$sh" run 2>&1); then
  ko "un modèle non *-free aurait dû être refusé"
fi
printf '%s' "$out" | grep -qi 'refusé' || ko "le refus de modèle doit être explicite"
printf '%s' "$out" | grep -Fq "$tok" && ko "jeton fuité lors du refus de modèle"
if out=$(EMU_E2E_MODEL=freellm/foo-free "$sh" run 2>&1); then
  ko "FreeLLM aurait dû être refusé"
fi
printf '%s' "$out" | grep -qi 'refusé' || ko "le refus FreeLLM doit être explicite"
# Défaut : le run (échec simulé) doit envoyer opencode/deepseek-v4.1-flash-free.
unset EMU_E2E_MODEL || true
: > "$tmp/gh.log.dispatch"
set +e
out=$("$sh" run 2>&1)
rc=$?
set -e
[ "$rc" -eq 1 ] || ko "run en échec simulé devrait sortir 1, obtenu $rc"
printf '%s' "$out" | grep -q 'verdict=failure' || ko "verdict d'échec manquant : $out"
printf '%s' "$out" | grep -q 'run=4242' || ko "id de run manquant"
printf '%s' "$out" | grep -q 'extrait des logs' || ko "extrait de logs manquant en échec"
# Pas le journal complet (200 lignes) : tail borné, plus le jeton en clair.
n=$(printf '%s\n' "$out" | grep -c 'fail line' || true)
[ "$n" -le 20 ] || ko "extrait trop long ($n lignes, max 20)"
printf '%s' "$out" | grep -Fq "$tok" && ko "jeton fuité dans l'extrait de logs"
printf '%s' "$out" | grep -q 'fail line 195' || ko "l'extrait devrait garder la fin du journal"
printf '%s' "$out" | grep -q 'token=\*\*\*' || ko "le jeton dans l'extrait doit être masqué"
grep -q 'model=opencode/deepseek-v4.1-flash-free' "$tmp/gh.log.dispatch" \
  || ko "le déclenchement doit passer model=opencode/deepseek-v4.1-flash-free"
grep -q 'rider_ref=feat/multi' "$tmp/gh.log.dispatch" || ko "dispatch sans rider_ref de travail"
grep -q 'driver_ref=main' "$tmp/gh.log.dispatch" || ko "dispatch sans driver_ref=main"
ok "run : déclenchement *-free, verdict et extrait court, pas de fuite"

# Succès : même mock, conclusion success, pas d'extrait.
cat > "$tmp/mock-gh-ok" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${EMU_E2E_GH_LOG:?}"
cmd="${1:-}"; shift || true
case "$cmd" in
  api)
    path=""
    for a in "$@"; do case "$a" in repos/*) path="$a" ;; esac; done
    case "$path" in
      repos/LordThiouk/Galass_Rider/branches/feat%2Fmulti) exit 0 ;;
      repos/LordThiouk/Galass_Driver/branches/feat%2Fmulti) exit 0 ;;
      *) exit 1 ;;
    esac
    ;;
  workflow) exit 0 ;;
  run)
    sub="${1:-}"
    case "$sub" in
      list) printf '%s\n' '[{"databaseId":7,"createdAt":"2099-01-01T00:00:00Z","status":"completed","conclusion":"success","url":"https://example.test/7"}]' ;;
      view) printf '%s\n' '{"status":"completed","conclusion":"success","url":"https://example.test/7","displayTitle":"e2e"}' ;;
      *) exit 2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$tmp/mock-gh-ok"
: > "$tmp/gh.log"
out=$(EMU_E2E_GH="$tmp/mock-gh-ok" "$sh" run 2>&1) || ko "run succès simulé a échoué : $out"
printf '%s' "$out" | grep -q 'verdict=success' || ko "verdict succès manquant : $out"
printf '%s' "$out" | grep -q 'extrait des logs' && ko "pas d'extrait de logs en succès"
printf '%s' "$out" | grep -qx 'rider_ref=feat/multi' || printf '%s' "$out" | grep -q 'rider_ref=feat/multi' \
  || ko "refs de succès manquantes"
printf '%s' "$out" | grep -q 'driver_ref=feat/multi' || ko "Driver aurait dû garder la branche de travail"
ok "run : succès sans extrait de logs"

# Timeout borné : le run reste in_progress.
cat > "$tmp/mock-gh-hang" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  api)
    path=""
    for a in "$@"; do case "$a" in repos/*) path="$a" ;; esac; done
    case "$path" in repos/LordThiouk/*/branches/*) exit 0 ;; *) exit 1 ;; esac
    ;;
  workflow) exit 0 ;;
  run)
    sub="${1:-}"
    case "$sub" in
      list) printf '%s\n' '[{"databaseId":9,"createdAt":"2099-01-01T00:00:00Z","status":"in_progress","conclusion":"","url":"https://example.test/9"}]' ;;
      view) printf '%s\n' '{"status":"in_progress","conclusion":"","url":"https://example.test/9","displayTitle":"e2e"}' ;;
      *) exit 2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$tmp/mock-gh-hang"
set +e
out=$(EMU_E2E_GH="$tmp/mock-gh-hang" EMU_E2E_TIMEOUT_SEC=1 EMU_E2E_POLL_SEC=0 "$sh" run 2>&1)
rc=$?
set -e
[ "$rc" -eq 124 ] || ko "timeout devrait sortir 124, obtenu $rc : $out"
printf '%s' "$out" | grep -q 'verdict=timeout' || ko "verdict timeout manquant : $out"
ok "run : timeout borné (124)"

# --- 4. workflow : input booléen, plus de setup local, gardes intactes --------
grep -q 'with_emulators:' "$wf" || ko "input with_emulators absent du workflow"
awk '
  $0 ~ /^      with_emulators:/ { p=1; print; next }
  p && $0 ~ /^      [A-Za-z0-9_]+:/ { exit }
  p { print }
' "$wf" > "$tmp/input.yml"
grep -q 'type: boolean' "$tmp/input.yml" || ko "with_emulators doit être type: boolean"
grep -q 'default: false' "$tmp/input.yml" || ko "with_emulators doit valoir false par défaut"
# Plus de démarrage local, plus de build APK, plus des 5 secrets e2e.
if grep -nE 'actions/setup-java@|android-actions/setup-android@|subosito/flutter-action@' "$wf"; then
  ko "workflow : setup Java / Android / Flutter encore présent (démarrage local)"
fi
if grep -nE 'secrets\.(GALASS_STAGING_URL|GALASS_E2E_RIDER_TOKEN|GALASS_E2E_DRIVER_TOKEN|GALASS_E2E_DEV_TOKEN|DEBUG_KEYSTORE_B64)' "$wf"; then
  ko "workflow : secret e2e encore demandé sur galass-ci"
fi
if grep -nE 'emulators\.sh|free-disk|Arrêter les émulateurs|Préparer et démarrer les émulateurs' "$wf"; then
  ko "workflow : anciennes étapes d'émulateurs locaux encore présentes"
fi
grep -q 'opencode/emu-e2e.sh' "$wf" || ko "workflow n'installe pas emu-e2e.sh"
grep -q '/opt/fullrun-tools' "$wf" && grep -q 'emu-e2e.sh' "$wf" \
  || ko "emu-e2e.sh n'est pas figé dans /opt/fullrun-tools"
# Interdiction documentée OK ; on refuse une clé ou une URL de modèle HTTP.
if grep -nE 'FREELLMAPI_|OPENAI_API_KEY|OPENAI_BASE_URL|secrets\.OPENCODE_API_KEY' "$wf"; then
  ko "workflow : FreeLLM ou appel HTTP direct à un modèle détecté"
fi
# Les modèles restent opencode/*-free (garde existante intacte).
grep -q 'opencode/\[a-z0-9.-\]+-free' "$wf" || grep -qE 'opencode/\[a-z0-9\.-\]\+-free' "$wf" \
  || ko "garde des modèles opencode/*-free introuvable"
# Plafond mémoire toujours présent (on ne l'affaiblit pas).
grep -q 'MemoryMax=' "$wf" || ko "plafond mémoire retiré du workflow"
# Liste blanche toujours sourcée / figée.
grep -q 'allowed-repos.sh' "$wf" || ko "allowed-repos.sh retiré du workflow"
ok "workflow : input false par défaut, e2e distant, gardes FullRun intactes"

echo "tous les contrôles with_emulators sont passés"
