#!/usr/bin/env bash
# Option with_emulators du FullRun : entrée (défaut false), extras, secrets (noms),
# bloc prompt, gel du script, pas de FreeLLM ni d'appel HTTP direct à un modèle.
#   opencode/tests/with-emulators-test.sh
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=opencode/tests/lib.sh
. "$here/tests/lib.sh"
# shellcheck source=opencode/allowed-repos.sh
. "$here/allowed-repos.sh"

wf="$here/../.github/workflows/opencode-fullrun.yml"
sh="$here/emulators.sh"
[ -f "$wf" ] || ko "workflow introuvable : $wf"
[ -x "$sh" ] || ko "emulators.sh introuvable ou non exécutable"

# --- 1. needed-repos : sous-ensemble de la liste blanche, pas une copie ------
needed=$("$sh" needed-repos)
printf '%s\n' "$needed" | grep -qx Galass_Rider || ko "Galass_Rider manquant dans needed-repos"
printf '%s\n' "$needed" | grep -qx Galass_Driver || ko "Galass_Driver manquant dans needed-repos"
printf '%s\n' "$needed" | grep -qx galass-emu-actions-pub || ko "galass-emu-actions-pub manquant dans needed-repos"
printf '%s\n' "$needed" | grep -qx Galass_backend && ko "Galass_backend ne doit pas être exigé pour les émulateurs"
while IFS= read -r r; do
  [ -n "$r" ] || continue
  allowed_repo "$r" || ko "needed-repos hors liste blanche : $r"
done <<<"$needed"
ok "needed-repos : sous-ensemble de la liste blanche"

# --- 2. merge-extras : false = identité, true = complète sans doublon --------
got=$(WITH_EMULATORS=false TARGET_REPO=Galass_backend EXTRA_REPOS_RAW="" "$sh" merge-extras)
[ -z "$got" ] || ko "merge-extras false + vide devrait rester vide, obtenu : $got"
got=$(WITH_EMULATORS=false TARGET_REPO=Galass_backend EXTRA_REPOS_RAW="Galass_Rider" "$sh" merge-extras)
[ "$got" = "Galass_Rider" ] || ko "merge-extras false doit recopier les extras, obtenu : $got"
got=$(WITH_EMULATORS=true TARGET_REPO=Galass_backend EXTRA_REPOS_RAW="" "$sh" merge-extras)
[ "$got" = "Galass_Rider,Galass_Driver,galass-emu-actions-pub" ] \
  || ko "merge-extras true depuis backend vide, obtenu : $got"
got=$(WITH_EMULATORS=true TARGET_REPO=Galass_Rider EXTRA_REPOS_RAW="" "$sh" merge-extras)
[ "$got" = "Galass_Driver,galass-emu-actions-pub" ] \
  || ko "merge-extras true depuis Rider ne doit pas se répéter, obtenu : $got"
got=$(WITH_EMULATORS=true TARGET_REPO=Galass_backend EXTRA_REPOS_RAW="Galass_Rider,galass-emu-actions-pub" \
  "$sh" merge-extras)
[ "$got" = "Galass_Rider,galass-emu-actions-pub,Galass_Driver" ] \
  || ko "merge-extras true conserve l'ordre puis complète, obtenu : $got"
if WITH_EMULATORS=maybe TARGET_REPO=Galass_backend EXTRA_REPOS_RAW="" "$sh" merge-extras >/dev/null 2>&1; then
  ko "WITH_EMULATORS=maybe aurait dû être refusé"
fi
if WITH_EMULATORS=true TARGET_REPO=Galass_backend EXTRA_REPOS_RAW="Galass_backend" "$sh" merge-extras >/dev/null 2>&1; then
  ko "extra_repos égal au target aurait dû être refusé"
fi
ok "merge-extras : false conservateur, true complète sans doublon du target"

# --- 3. secrets : noms seulement, garde sans fuite ---------------------------
sec=$("$sh" required-secrets)
for n in GALASS_STAGING_URL GALASS_E2E_RIDER_TOKEN GALASS_E2E_DRIVER_TOKEN \
         GALASS_E2E_DEV_TOKEN DEBUG_KEYSTORE_B64; do
  printf '%s\n' "$sec" | grep -qx "$n" || ko "secret requis manquant : $n"
done
printf '%s\n' "$sec" | grep -qE 'OPENCODE_API_KEY|OPENAI_|FREELLM' \
  && ko "required-secrets ne doit pas exiger une clé de modèle HTTP"
tok="e2e-tok-$(rand_alnum 24)"
url="http://203.0.113.9:8080"
ks="$(rand_alnum 32)"
if out=$(GALASS_STAGING_URL= GALASS_E2E_RIDER_TOKEN= GALASS_E2E_DRIVER_TOKEN= \
         GALASS_E2E_DEV_TOKEN= DEBUG_KEYSTORE_B64= "$sh" guard-secrets 2>&1); then
  ko "guard-secrets sans secret aurait dû échouer"
fi
printf '%s' "$out" | grep -q "GALASS_STAGING_URL" || ko "garde doit nommer le secret manquant"
# Présents : succès, la valeur n'apparaît pas hors ::add-mask::
out=$(GALASS_STAGING_URL="$url" GALASS_E2E_RIDER_TOKEN="$tok" \
      GALASS_E2E_DRIVER_TOKEN="$tok" GALASS_E2E_DEV_TOKEN="$tok" \
      DEBUG_KEYSTORE_B64="$ks" "$sh" guard-secrets 2>&1) || ko "guard-secrets en échec avec secrets présents"
printf '%s' "$out" | grep -q '::add-mask::' || ko "guard-secrets doit masquer les valeurs"
# La valeur ne doit pas apparaître en clair hors de la directive de masquage.
plain=$(printf '%s\n' "$out" | grep -v '::add-mask::' || true)
printf '%s' "$plain" | grep -Fq "$tok" && ko "jeton e2e fuité hors masquage"
printf '%s' "$plain" | grep -Fq "$url" && ko "URL staging fuite hors masquage"
printf '%s' "$plain" | grep -Fq "$ks" && ko "keystore fuité hors masquage"
ok "required-secrets et guard-secrets : noms seuls, pas de fuite"

# --- 4. prompt : variables, pas de valeurs, pas de FreeLLM / HTTP modèle -----
blk=$(RIDER_ADB_SERIAL=emulator-5554 DRIVER_ADB_SERIAL=emulator-5556 \
      EMU_ROOT=/tmp/emu APK_RIDER=/tmp/r.apk APK_DRIVER=/tmp/d.apk \
      "$sh" prompt-block)
printf '%s' "$blk" | grep -q 'emulator-5554' || ko "prompt sans série Rider"
printf '%s' "$blk" | grep -q 'emulator-5556' || ko "prompt sans série Driver"
printf '%s' "$blk" | grep -q 'e2e/run.sh' || ko "prompt sans e2e/run.sh"
printf '%s' "$blk" | grep -q 'api_flow.py' || ko "prompt sans api_flow.py"
printf '%s' "$blk" | grep -q 'ui.sh' || ko "prompt sans ui.sh"
printf '%s' "$blk" | grep -q 'GALASS_STAGING_URL' || ko "prompt sans nom de l'URL staging"
# Mention d'interdiction (« pas de FreeLLM ») attendue ; pas d'URL ni de clé.
printf '%s' "$blk" | grep -qi 'pas de FreeLLM' || ko "prompt doit interdire FreeLLM"
printf '%s' "$blk" | grep -qE 'https?://opencode.ai|OPENAI_API_KEY|OPENAI_BASE_URL|FREELLMAPI' \
  && ko "prompt ne doit pas contenir d'URL d'API modèle ni de clé HTTP"
printf '%s' "$blk" | grep -q 'opencode/\*-free' || ko "prompt doit rappeler les modèles opencode/*-free"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/oc"
printf 'preamble\n' > "$tmp/oc/prompt.md"
OC_WORK="$tmp/oc" RIDER_ADB_SERIAL=emulator-5554 DRIVER_ADB_SERIAL=emulator-5556 \
  "$sh" append-prompt >/dev/null
grep -q 'emulator-5554' "$tmp/oc/prompt.md" || ko "append-prompt n'a pas écrit le bloc"
ok "prompt-block / append-prompt : séries et scripts, sans secret"

# --- 5. workflow : input booléen, défaut false, steps gardés -----------------
grep -q 'with_emulators:' "$wf" || ko "input with_emulators absent du workflow"
# Bloc de l'entrée : type boolean, default false.
awk '
  $0 ~ /^      with_emulators:/ { p=1; print; next }
  p && $0 ~ /^      [A-Za-z0-9_]+:/ { exit }
  p { print }
' "$wf" > "$tmp/input.yml"
grep -q 'type: boolean' "$tmp/input.yml" || ko "with_emulators doit être type: boolean"
grep -q 'default: false' "$tmp/input.yml" || ko "with_emulators doit valoir false par défaut"
# Les steps émulateurs (sauf l'arrêt always()) sont conditionnés.
# java / flutter / setup-android / secrets / setup / disque
n=$(grep -c 'if: inputs.with_emulators' "$wf" || true)
[ "$n" -ge 5 ] || ko "pas assez de steps gardés par if: inputs.with_emulators (trouvé $n)"
grep -q 'always() && inputs.with_emulators' "$wf" || ko "step d'arrêt des émulateurs manquant"
grep -q 'opencode/emulators.sh' "$wf" || ko "workflow n'appelle pas emulators.sh"
grep -q '/opt/fullrun-tools' "$wf" && grep -q 'emulators.sh' "$wf" \
  || ko "emulators.sh n'est pas figé dans /opt/fullrun-tools"
# Interdiction documentée (commentaire) OK ; on refuse une clé ou une URL de modèle HTTP.
if grep -nE 'FREELLMAPI_|OPENAI_API_KEY|OPENAI_BASE_URL|secrets\.OPENCODE_API_KEY' "$wf"; then
  ko "workflow : FreeLLM ou appel HTTP direct à un modèle détecté"
fi
# Les modèles restent opencode/*-free (garde existante intacte).
grep -q 'opencode/\[a-z0-9.-\]+-free' "$wf" || grep -qE 'opencode/\[a-z0-9\.-\]\+-free' "$wf" \
  || ko "garde des modèles opencode/*-free introuvable"
# Plafond mémoire toujours présent (on ne l'affaiblit pas).
grep -q 'MemoryMax=' "$wf" || ko "plafond mémoire retiré du workflow"
ok "workflow : input false par défaut, steps gardés, gardes FullRun intactes"

echo "tous les contrôles with_emulators sont passés"
