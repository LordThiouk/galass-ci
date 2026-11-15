#!/usr/bin/env bash
# FullRun galass-ci : option with_emulators.
# Démarre les émulateurs Android Rider et Driver, expose les séries adb, prépare
# les APK (keystore debug) et le staging. Jamais de valeur de secret en sortie.
#   emulators.sh merge-extras      complète EXTRA_REPOS_RAW si WITH_EMULATORS=true
#   emulators.sh needed-repos      dépôts requis (sous-ensemble de la liste blanche)
#   emulators.sh required-secrets  noms des secrets (une ligne chacun)
#   emulators.sh guard-secrets     présence + masquage, sans afficher les valeurs
#   emulators.sh guard-base        garde staging (e2e/base_guard.py), masque l'hôte
#   emulators.sh prompt-block      bloc à ajouter au prompt (noms de variables seulement)
#   emulators.sh append-prompt     ajoute le bloc à $OC_WORK/prompt.md
#   emulators.sh setup             licences, keystore, APK, KVM, start, install, reset
#   emulators.sh stop              arrête les deux émulateurs
# Ne relâche aucune garde FullRun. Pas de FreeLLM, pas d'appel HTTP direct à un modèle.
set -euo pipefail
set +x

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=opencode/allowed-repos.sh
. "$here/allowed-repos.sh"

fail() { echo "$1" >&2; exit 1; }

# Sous-ensemble de allowed_repos_list, ordre stable. Pas une copie de la liste blanche.
needed_repos_list() {
  printf '%s\n' Galass_Rider Galass_Driver galass-emu-actions-pub
}

required_secrets_list() {
  printf '%s\n' \
    GALASS_STAGING_URL \
    GALASS_E2E_RIDER_TOKEN \
    GALASS_E2E_DRIVER_TOKEN \
    GALASS_E2E_DEV_TOKEN \
    DEBUG_KEYSTORE_B64
}

mask() {
  # Masque GitHub Actions : la valeur n'est jamais écrite ailleurs.
  local v="$1"
  [ -n "$v" ] || return 0
  printf '::add-mask::%s\n' "$v"
}

repo_dir() {
  local r="$1"
  allowed_repo "$r" || fail "dépôt non autorisé : $r"
  if [ "$r" = "${TARGET_REPO:-}" ]; then
    [ -n "${TARGET_DIR:-}" ] || fail "TARGET_DIR manquant"
    printf '%s\n' "$TARGET_DIR"
  else
    [ -n "${EXTRA_ROOT:-}" ] || fail "EXTRA_ROOT manquant"
    printf '%s\n' "$EXTRA_ROOT/$r"
  fi
}

emu_root() {
  repo_dir galass-emu-actions-pub
}

state_dir() {
  printf '%s\n' "${EMU_STATE_DIR:-${RUNNER_TEMP:-/tmp}/galass-emu}"
}

# --- merge-extras -------------------------------------------------------------
# Avec WITH_EMULATORS=true, ajoute les dépôts e2e manquants (sauf le target).
# Sinon, recopie EXTRA_REPOS_RAW tel quel (non normalisé).
merge_extras() {
  local raw="${EXTRA_REPOS_RAW-}" target="${TARGET_REPO:-}" r extras="" flag
  flag="${WITH_EMULATORS:-false}"
  case "$flag" in
    true|false) ;;
    *) fail "with_emulators invalide (true ou false)" ;;
  esac
  if [ "$flag" != "true" ]; then
    printf '%s\n' "$raw"
    return 0
  fi
  [ -n "$target" ] || fail "TARGET_REPO manquant"
  allowed_repo "$target" || fail "TARGET_REPO invalide"
  IFS=',' read -r -a ers <<<"$raw"
  for r in "${ers[@]}"; do
    r="${r//[[:space:]]/}"
    [ -n "$r" ] || continue
    allowed_repo "$r" || fail "extra_repos invalide : dépôt non autorisé"
    [ "$r" != "$target" ] || fail "extra_repos ne peut pas répéter target_repo"
    case ",$extras," in
      *",$r,"*) fail "extra_repos : dépôt en double" ;;
    esac
    extras="${extras:+$extras,}$r"
  done
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    allowed_repo "$r" || fail "dépôt e2e hors liste blanche : $r"
    [ "$r" = "$target" ] && continue
    case ",$extras," in
      *",$r,"*) continue ;;
    esac
    extras="${extras:+$extras,}$r"
  done < <(needed_repos_list)
  printf '%s\n' "$extras"
}

# --- secrets / staging --------------------------------------------------------
guard_secrets() {
  local name v missing=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    v="${!name-}"
    if [ -z "$v" ]; then
      echo "::error::secret $name absent (acte Papa requis)" >&2
      missing=1
      continue
    fi
    mask "$v"
  done < <(required_secrets_list)
  [ "$missing" -eq 0 ] || fail "secrets e2e manquants : with_emulators exige un acte Papa"
  # Alias attendus par e2e/api_flow.py et e2e/run.sh (mêmes valeurs, déjà masquées).
  if [ -n "${GALASS_STAGING_URL:-}" ]; then
    mask "$GALASS_STAGING_URL"
  fi
  if [ -n "${GALASS_E2E_RIDER_TOKEN:-}" ]; then
    mask "$GALASS_E2E_RIDER_TOKEN"
  fi
  if [ -n "${GALASS_E2E_DRIVER_TOKEN:-}" ]; then
    mask "$GALASS_E2E_DRIVER_TOKEN"
  fi
  if [ -n "${GALASS_E2E_DEV_TOKEN:-}" ]; then
    mask "$GALASS_E2E_DEV_TOKEN"
  fi
  echo "secrets e2e présents (valeurs masquées, jamais affichées)"
}

guard_base() {
  local base="${GALASS_STAGING_URL:-${BASE:-}}" emu py h
  [ -n "$base" ] || fail "GALASS_STAGING_URL / BASE manquant"
  mask "$base"
  h="${base#*://}"; h="${h%%[:/]*}"
  [ -n "$h" ] && mask "$h"
  emu=$(emu_root)
  py="$emu/e2e/base_guard.py"
  [ -f "$py" ] || fail "e2e/base_guard.py introuvable (galass-emu-actions-pub)"
  python3 "$py" "$base" >/dev/null
  case "$base" in
    *galassapp.com*) fail "BASE ne doit pas être la prod" ;;
  esac
  echo "BASE ok (staging, hôte masqué)"
}

# --- prompt -------------------------------------------------------------------
prompt_block() {
  local rider_s="${RIDER_ADB_SERIAL:-}" driver_s="${DRIVER_ADB_SERIAL:-}"
  local emu="${EMU_ROOT:-}" apk_r="${APK_RIDER:-}" apk_d="${APK_DRIVER:-}"
  cat <<BLOCK
# Émulateurs CI (with_emulators)

Deux émulateurs Android tournent déjà sur ce runner (KVM), contre le vrai staging.

- Série adb passager (Rider) : ${rider_s:-<RIDER_ADB_SERIAL>}
- Série adb chauffeur (Driver) : ${driver_s:-<DRIVER_ADB_SERIAL>}
- Comptes de test : passager \${RIDER_ID} (106), chauffeur \${DRIVER_ID} (23)
- APK déjà installés (keystore debug) : ${apk_r:-\$APK_RIDER} sur Rider, ${apk_d:-\$APK_DRIVER} sur Driver
- Scripts e2e (galass-emu-actions-pub) : ${emu:-\$EMU_ROOT}/e2e/run.sh, api_flow.py, ui.sh
- URL staging et jetons : variables d'environnement GALASS_STAGING_URL (alias BASE), RIDER_TOKEN, DRIVER_TOKEN, DEV_TOKEN. Ne les écris nulle part (fichier, commit, rapport, log).
- Le HTTP en clair n'est permis que pour l'IP staging, port 8080 (garde e2e/base_guard.py). Pas de prod (galassapp.com).
- Courses déjà fermées en entrée (passager 106, chauffeur 23) : fermer, ne pas supprimer.
- Tu codes et tu testes en même temps. Pilote les deux émulateurs avec \`adb -s <série>\` et les scripts e2e. Les scripts historiques parlent à un seul adb : exporte ANDROID_SERIAL ou passe \`-s\` pour viser le bon appareil.
- Si tu sers d'Artemis, uniquement comme outil local sous opencode : pas d'appel HTTP direct à une API de modèle, pas de FreeLLM, pas de clé OpenAI. Les modèles restent opencode/*-free.
- Si tu changes le code Rider/Driver : recompile en debug avec --dart-define=API_BASE_URL issu de GALASS_STAGING_URL (sans l'afficher), même keystore déjà en place dans ~/.android/debug.keystore, puis réinstalle sur la bonne série adb.
BLOCK
}

append_prompt() {
  local p="${OC_WORK:-}/prompt.md"
  [ -n "${OC_WORK:-}" ] || fail "OC_WORK manquant"
  [ -f "$p" ] || fail "prompt.md introuvable"
  { echo; prompt_block; } >> "$p"
  echo "Bloc émulateurs ajouté au prompt ($(wc -l < "$p") lignes)"
}

export_nonsecret_env() {
  [ -n "${GITHUB_ENV:-}" ] || return 0
  {
    echo "RIDER_ADB_SERIAL=${RIDER_ADB_SERIAL:-}"
    echo "DRIVER_ADB_SERIAL=${DRIVER_ADB_SERIAL:-}"
    echo "RIDER_ID=${RIDER_ID:-106}"
    echo "DRIVER_ID=${DRIVER_ID:-23}"
    echo "APK_RIDER=${APK_RIDER:-}"
    echo "APK_DRIVER=${APK_DRIVER:-}"
    echo "EMU_ROOT=${EMU_ROOT:-}"
  } >> "$GITHUB_ENV"
}

# --- disque / SDK / keystore / APK -------------------------------------------
free_disk() {
  sudo rm -rf /usr/share/dotnet /opt/ghc /usr/local/.ghcup /usr/share/swift \
    /usr/local/share/boost /opt/hostedtoolcache/CodeQL /usr/local/lib/node_modules \
    /opt/microsoft /opt/google/chrome /usr/local/share/powershell || true
  sudo docker image prune --all --force >/dev/null 2>&1 || true
  echo "disque libéré (best-effort)"
}

sdkmanager_bin() {
  local sdkm="${ANDROID_HOME:-}/cmdline-tools/latest/bin/sdkmanager"
  if [ ! -x "$sdkm" ]; then
    sdkm=$(ls -d "${ANDROID_HOME:-}"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | head -1 || true)
  fi
  [ -x "$sdkm" ] || fail "sdkmanager introuvable (ANDROID_HOME manquant ou SDK incomplet)"
  printf '%s\n' "$sdkm"
}

licenses_and_sdk() {
  local sdkm
  : "${ANDROID_HOME:?ANDROID_HOME manquant}"
  sdkm=$(sdkmanager_bin)
  yes | "$sdkm" --licenses >/dev/null || true
  # Mêmes NDK que artemis-staging-e2e.yml (Flutter 3.44.8).
  "$sdkm" --install \
    "platform-tools" \
    "platforms;android-34" \
    "system-images;android-34;google_apis;x86_64" \
    "emulator" \
    "build-tools;34.0.0" \
    "ndk;29.0.14033849" \
    "ndk;28.2.13676358" >/dev/null
  export PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${PATH}"
  echo "SDK Android et NDK prêts"
}

install_keystore() {
  local ks="${DEBUG_KEYSTORE_B64:-}" d
  [ -n "$ks" ] || fail "secret DEBUG_KEYSTORE_B64 absent (acte Papa requis)"
  umask 077
  mkdir -p "$HOME/.android"
  # Fichier temporaire : jamais listé, jamais copié dans un dépôt.
  printf '%s' "$ks" | base64 -d > /tmp/dbg.p12
  rm -f "$HOME/.android/debug.keystore"
  keytool -importkeystore -noprompt -srckeystore /tmp/dbg.p12 -srcstoretype PKCS12 \
    -srcstorepass android -srcalias androiddebugkey \
    -destkeystore "$HOME/.android/debug.keystore" -deststoretype JKS \
    -deststorepass android -destkeypass android -destalias androiddebugkey \
    2>/dev/null || true
  rm -f /tmp/dbg.p12
  [ -s "$HOME/.android/debug.keystore" ] || fail "keystore debug introuvable après import"
  for d in "$HOME/.android" "${ANDROID_SDK_HOME:-$HOME}/.android" \
           "${ANDROID_PREFS_ROOT:-$HOME}/.android" "${ANDROID_HOME:-}/.android"; do
    mkdir -p "$d" 2>/dev/null || continue
    cp -f "$HOME/.android/debug.keystore" "$d/debug.keystore" 2>/dev/null || true
  done
  if [ -n "${ANDROID_USER_HOME:-}" ]; then
    mkdir -p "$ANDROID_USER_HOME" 2>/dev/null || true
    cp -f "$HOME/.android/debug.keystore" "$ANDROID_USER_HOME/debug.keystore" 2>/dev/null || true
  fi
  mkdir -p "$HOME/.gradle/init.d"
  cat > "$HOME/.gradle/init.d/zz-debug-signing.gradle" <<'GRADLE'
allprojects { proj ->
  proj.plugins.withId('com.android.application') {
    proj.afterEvaluate {
      try {
        def android = proj.extensions.findByName('android')
        if (android == null) return
        def sc = android.signingConfigs.findByName('debug')
        if (sc == null) sc = android.signingConfigs.create('debug')
        sc.storeFile = new File(System.getenv('HOME'), '.android/debug.keystore')
        sc.storePassword = 'android'
        sc.keyAlias = 'androiddebugkey'
        sc.keyPassword = 'android'
        def bt = android.buildTypes.findByName('debug')
        if (bt != null) bt.signingConfig = sc
        proj.logger.lifecycle("debug signing force sur ~/.android/debug.keystore")
      } catch (Throwable t) {
        proj.logger.lifecycle("debug-signing init ignore")
      }
    }
  }
}
GRADLE
  echo "keystore debug en place (valeur jamais affichée)"
}

# Construit les APK sans afficher BASE ni les dart-defines.
build_apks() {
  local base="${GALASS_STAGING_URL:-${BASE:-}}" src dest app name log
  [ -n "$base" ] || fail "GALASS_STAGING_URL / BASE manquant pour le build"
  mask "$base"
  command -v flutter >/dev/null || fail "flutter introuvable"
  mkdir -p "${RUNNER_TEMP:-/tmp}/apk/rider" "${RUNNER_TEMP:-/tmp}/apk/driver"
  for app in rider driver; do
    if [ "$app" = rider ]; then name=Galass_Rider; else name=Galass_Driver; fi
    src=$(repo_dir "$name")
    [ -d "$src" ] || fail "sources $name introuvables"
    log="${RUNNER_TEMP:-/tmp}/apk/build-$app.log"
    (
      cd "$src"
      flutter pub get >/dev/null
      # La valeur de BASE ne doit pas apparaître dans les logs publics.
      flutter build apk --debug --dart-define="API_BASE_URL=$base" >"$log" 2>&1
    ) || fail "build APK $app en échec (journal local, BASE masquée)"
    dest="${RUNNER_TEMP:-/tmp}/apk/$app/app-debug.apk"
    cp "$src/build/app/outputs/flutter-apk/app-debug.apk" "$dest"
    [ -s "$dest" ] || fail "APK $app manquant après le build"
    echo "APK $app prêt"
  done
  APK_RIDER="${RUNNER_TEMP:-/tmp}/apk/rider/app-debug.apk"
  APK_DRIVER="${RUNNER_TEMP:-/tmp}/apk/driver/app-debug.apk"
  export APK_RIDER APK_DRIVER
  # GradleDaemon (Xmx élevé) étouffe les émulateurs : on le tue avant le start.
  pkill -f GradleDaemon >/dev/null 2>&1 || true
  pkill -f KotlinCompileDaemon >/dev/null 2>&1 || true
  echo "APK Rider et Driver construits"
}

# --- KVM + deux émulateurs en arrière-plan -----------------------------------
enable_kvm() {
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
    | sudo tee /etc/udev/rules.d/99-kvm4all.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger --name-match=kvm
  [ -e /dev/kvm ] || fail "KVM indisponible sur le runner : émulateurs impossibles"
  echo "KVM prêt"
}

avd_create() {
  local name="$1" avd
  avd="${ANDROID_HOME}/cmdline-tools/latest/bin/avdmanager"
  if [ ! -x "$avd" ]; then
    avd=$(ls -d "${ANDROID_HOME}"/cmdline-tools/*/bin/avdmanager 2>/dev/null | head -1 || true)
  fi
  [ -x "$avd" ] || fail "avdmanager introuvable"
  echo no | "$avd" create avd -n "$name" \
    --package "system-images;android-34;google_apis;x86_64" \
    --device pixel_6 --force >/dev/null
}

wait_boot() {
  local serial="$1" i boot
  command adb -s "$serial" wait-for-device
  for i in $(seq 1 90); do
    boot=$(command adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
    [ "$boot" = 1 ] && return 0
    sleep 4
  done
  fail "émulateur $serial : sys.boot_completed jamais atteint"
}

start_emulators() {
  local dir emu_bin rider_port=5554 driver_port=5556
  dir=$(state_dir)
  mkdir -p "$dir"
  export PATH="${ANDROID_HOME:?}/platform-tools:${ANDROID_HOME}/emulator:${PATH}"
  emu_bin="${ANDROID_HOME}/emulator/emulator"
  [ -x "$emu_bin" ] || fail "binaire emulator introuvable"
  command -v adb >/dev/null || fail "adb introuvable"
  adb start-server >/dev/null
  avd_create galass-rider
  avd_create galass-driver
  # RAM réduite (2048) pour cohabiter avec le plafond mémoire d'opencode (inchangé).
  # Options alignées sur artemis-staging-e2e.yml, deux instances en arrière-plan.
  "$emu_bin" -avd galass-rider -port "$rider_port" -no-window -gpu swiftshader_indirect \
    -noaudio -no-boot-anim -camera-back none -no-snapshot -memory 2048 -cores 2 \
    >"$dir/rider.log" 2>&1 &
  echo $! > "$dir/rider.pid"
  "$emu_bin" -avd galass-driver -port "$driver_port" -no-window -gpu swiftshader_indirect \
    -noaudio -no-boot-anim -camera-back none -no-snapshot -memory 2048 -cores 2 \
    >"$dir/driver.log" 2>&1 &
  echo $! > "$dir/driver.pid"
  RIDER_ADB_SERIAL="emulator-${rider_port}"
  DRIVER_ADB_SERIAL="emulator-${driver_port}"
  export RIDER_ADB_SERIAL DRIVER_ADB_SERIAL
  wait_boot "$RIDER_ADB_SERIAL"
  wait_boot "$DRIVER_ADB_SERIAL"
  printf '%s\n' "$RIDER_ADB_SERIAL" > "$dir/rider.serial"
  printf '%s\n' "$DRIVER_ADB_SERIAL" > "$dir/driver.serial"
  echo "émulateurs démarrés : Rider=$RIDER_ADB_SERIAL Driver=$DRIVER_ADB_SERIAL"
}

install_apks() {
  local r="${RIDER_ADB_SERIAL:-}" d="${DRIVER_ADB_SERIAL:-}"
  [ -n "$r" ] && [ -n "$d" ] || fail "séries adb manquantes"
  [ -s "${APK_RIDER:-}" ] || fail "APK_RIDER manquant"
  [ -s "${APK_DRIVER:-}" ] || fail "APK_DRIVER manquant"
  export PATH="${ANDROID_HOME:?}/platform-tools:${PATH}"
  command timeout 600 adb -s "$r" install -r -t -g "$APK_RIDER" >/dev/null
  command timeout 600 adb -s "$d" install -r -t -g "$APK_DRIVER" >/dev/null
  echo "APK installés sur les deux émulateurs"
}

reset_rides() {
  local emu py
  emu=$(emu_root)
  py="$emu/e2e/api_flow.py"
  [ -f "$py" ] || fail "e2e/api_flow.py introuvable"
  # Alias des jetons attendus par le script e2e, sans les afficher.
  BASE="${GALASS_STAGING_URL:-${BASE:-}}"
  RIDER_TOKEN="${RIDER_TOKEN:-${GALASS_E2E_RIDER_TOKEN:-}}"
  DRIVER_TOKEN="${DRIVER_TOKEN:-${GALASS_E2E_DRIVER_TOKEN:-}}"
  DEV_TOKEN="${DEV_TOKEN:-${GALASS_E2E_DEV_TOKEN:-}}"
  export BASE RIDER_TOKEN DRIVER_TOKEN DEV_TOKEN
  export RIDER_ID="${RIDER_ID:-106}" DRIVER_ID="${DRIVER_ID:-23}"
  [ -n "$BASE" ] && [ -n "$RIDER_TOKEN" ] && [ -n "$DRIVER_TOKEN" ] && [ -n "$DEV_TOKEN" ] \
    || fail "variables staging/jetons manquantes pour le nettoyage"
  # Fermer les courses (cancel), ne pas supprimer. Sortie jetée : peut contenir des ids.
  if ! STEP=reset python3 "$py" >/dev/null 2>&1; then
    fail "nettoyage des courses en échec (passager 106, chauffeur 23)"
  fi
  echo "courses fermées (passager 106, chauffeur 23, sans suppression)"
}

stop_emulators() {
  local dir r d pid
  dir=$(state_dir)
  export PATH="${ANDROID_HOME:-}/platform-tools:${PATH}"
  r=$(cat "$dir/rider.serial" 2>/dev/null || true)
  d=$(cat "$dir/driver.serial" 2>/dev/null || true)
  [ -n "$r" ] && command adb -s "$r" emu kill >/dev/null 2>&1 || true
  [ -n "$d" ] && command adb -s "$d" emu kill >/dev/null 2>&1 || true
  for pid in "$dir/rider.pid" "$dir/driver.pid"; do
    if [ -s "$pid" ]; then
      kill "$(cat "$pid")" >/dev/null 2>&1 || true
    fi
  done
  echo "émulateurs arrêtés (best-effort)"
  return 0
}

setup() {
  local emu
  guard_secrets
  EMU_ROOT=$(emu_root)
  export EMU_ROOT
  export RIDER_ID="${RIDER_ID:-106}" DRIVER_ID="${DRIVER_ID:-23}"
  export BASE="${GALASS_STAGING_URL:-${BASE:-}}"
  export RIDER_TOKEN="${RIDER_TOKEN:-${GALASS_E2E_RIDER_TOKEN:-}}"
  export DRIVER_TOKEN="${DRIVER_TOKEN:-${GALASS_E2E_DRIVER_TOKEN:-}}"
  export DEV_TOKEN="${DEV_TOKEN:-${GALASS_E2E_DEV_TOKEN:-}}"
  guard_base
  licenses_and_sdk
  install_keystore
  build_apks
  enable_kvm
  start_emulators
  install_apks
  reset_rides
  export_nonsecret_env
  if [ -n "${OC_WORK:-}" ] && [ -f "${OC_WORK}/prompt.md" ]; then
    append_prompt
  fi
  echo "émulateurs Rider et Driver prêts pour opencode"
}

cmd="${1:-}"
case "$cmd" in
  merge-extras) merge_extras ;;
  needed-repos) needed_repos_list ;;
  required-secrets) required_secrets_list ;;
  guard-secrets) guard_secrets ;;
  guard-base) guard_base ;;
  prompt-block) prompt_block ;;
  append-prompt) append_prompt ;;
  repo-dir) repo_dir "${2:?nom de dépôt manquant}" ;;
  emu-root) emu_root ;;
  free-disk) free_disk ;;
  setup) setup ;;
  stop) stop_emulators ;;
  start) start_emulators ;;
  *) fail "commande inconnue : ${cmd:-<vide>}" ;;
esac
