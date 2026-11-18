#!/usr/bin/env bash
# FullRun galass-ci : option with_emulators.
# Déclenche le e2e Artemis sur LordThiouk/galass-emu-actions-pub (secrets e2e déjà
# présents là-bas), attend un verdict borné, et n'affiche qu'un court extrait en
# échec. Pas de démarrage local d'émulateurs, pas de build APK, pas de secret e2e
# sur galass-ci. Le jeton (GALASS_TOKEN) n'est jamais affiché ni passé à opencode.
#
#   emu-e2e.sh run            déclenche, attend, affiche le verdict
#   emu-e2e.sh resolve-refs   affiche rider_ref et driver_ref
#   emu-e2e.sh prompt-block   bloc à ajouter au prompt (aucun secret)
#   emu-e2e.sh append-prompt  ajoute le bloc à $OC_WORK/prompt.md
#
# Ne relâche aucune garde FullRun. Modèle dispatché : opencode/*-free (jamais FreeLLM, jamais de clé API).
set -euo pipefail
set +x

FROZEN="/opt/fullrun-tools/emu-e2e.sh"
CANON_STATE="/opt/fullrun-tools/emu-e2e.state"
CANON_TOKEN="/opt/fullrun-live/emu-e2e.token"
EMU_OWNER="LordThiouk"
EMU_REPO_NAME="galass-emu-actions-pub"
EMU_REPO="${EMU_OWNER}/${EMU_REPO_NAME}"
EMU_WORKFLOW="artemis-staging-e2e.yml"
RIDER_REPO="Galass_Rider"
DRIVER_REPO="Galass_Driver"
DEFAULT_MODEL="opencode/deepseek-v4.1-flash-free"
DEFAULT_TIMEOUT_SEC=10800
DEFAULT_POLL_SEC=30
DEFAULT_LOG_TAIL=80
DEFAULT_LOG_WIDTH=300
FALLBACK_REF="main"

fail() { echo "$1" >&2; exit 1; }

# Rebond sur le binaire figé (root) pour run / resolve-refs : le jeton n'est pas
# dans l'environnement d'opencode, seulement dans un fichier root 0600.
maybe_sudo() {
  local cmd="${1:-}"
  case "$cmd" in
    run|resolve-refs) ;;
    *) return 0 ;;
  esac
  [ "$(id -u)" -eq 0 ] && return 0
  [ -f "$CANON_TOKEN" ] || return 0
  [ -x "$FROZEN" ] || fail "outil figé absent : $FROZEN"
  exec sudo -n -H -- "$FROZEN" "$@"
}

load_file_vars() {
  local f="$1" line k v
  [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
    esac
    k="${line%%=*}"
    v="${line#*=}"
    case "$k" in
      OC_BRANCH) OC_BRANCH="$v" ;;
      EMU_E2E_MODEL) EMU_E2E_MODEL="$v" ;;
      EMU_E2E_TIMEOUT_SEC) EMU_E2E_TIMEOUT_SEC="$v" ;;
      EMU_E2E_POLL_SEC) EMU_E2E_POLL_SEC="$v" ;;
      EMU_LOG_TAIL) EMU_LOG_TAIL="$v" ;;
      EMU_LOG_WIDTH) EMU_LOG_WIDTH="$v" ;;
      *) ;;
    esac
  done < "$f"
}

# En CI (root + état figé) : ignorer les variables d'environnement injectables.
# En test : EMU_E2E_STATE / l'environnement.
load_config() {
  OC_BRANCH="${OC_BRANCH:-${IN_BRANCH:-}}"
  EMU_E2E_MODEL="${EMU_E2E_MODEL:-$DEFAULT_MODEL}"
  EMU_E2E_TIMEOUT_SEC="${EMU_E2E_TIMEOUT_SEC:-$DEFAULT_TIMEOUT_SEC}"
  EMU_E2E_POLL_SEC="${EMU_E2E_POLL_SEC:-$DEFAULT_POLL_SEC}"
  EMU_LOG_TAIL="${EMU_LOG_TAIL:-$DEFAULT_LOG_TAIL}"
  EMU_LOG_WIDTH="${EMU_LOG_WIDTH:-$DEFAULT_LOG_WIDTH}"
  if [ "$(id -u)" -eq 0 ] && [ -f "$CANON_STATE" ]; then
    OC_BRANCH=""; EMU_E2E_MODEL="$DEFAULT_MODEL"
    EMU_E2E_TIMEOUT_SEC="$DEFAULT_TIMEOUT_SEC"
    EMU_E2E_POLL_SEC="$DEFAULT_POLL_SEC"
    EMU_LOG_TAIL="$DEFAULT_LOG_TAIL"
    EMU_LOG_WIDTH="$DEFAULT_LOG_WIDTH"
    load_file_vars "$CANON_STATE"
  elif [ -n "${EMU_E2E_STATE:-}" ] && [ -f "$EMU_E2E_STATE" ]; then
    load_file_vars "$EMU_E2E_STATE"
  fi
  [[ "${EMU_E2E_TIMEOUT_SEC}" =~ ^[0-9]+$ ]] || fail "timeout invalide"
  [[ "${EMU_E2E_POLL_SEC}" =~ ^[0-9]+$ ]] || fail "intervalle de sondage invalide"
  [[ "${EMU_LOG_TAIL}" =~ ^[0-9]+$ ]] || fail "taille d'extrait invalide"
  [[ "${EMU_LOG_WIDTH}" =~ ^[0-9]+$ ]] || fail "largeur d'extrait invalide"
  [ "$EMU_E2E_TIMEOUT_SEC" -ge 1 ] || fail "timeout invalide"
  [ "$EMU_E2E_POLL_SEC" -ge 0 ] || fail "intervalle de sondage invalide"
  if [ "$EMU_LOG_TAIL" -lt 1 ] || [ "$EMU_LOG_TAIL" -gt 200 ]; then
    fail "taille d'extrait hors bornes (1-200)"
  fi
  if [ "$EMU_LOG_WIDTH" -lt 40 ] || [ "$EMU_LOG_WIDTH" -gt 500 ]; then
    fail "largeur d'extrait hors bornes"
  fi
  [ -n "$OC_BRANCH" ] || fail "branche de travail manquante (OC_BRANCH)"
}

normalize_model() {
  local m="$1"
  m="${m#"${m%%[![:space:]]*}"}"
  m="${m%"${m##*[![:space:]]}"}"
  case "$m" in
    opencode/*) printf '%s\n' "$m" ;;
    *) printf 'opencode/%s\n' "$m" ;;
  esac
}

validate_model() {
  local raw="$1" m
  [ -n "$raw" ] || fail "modèle refusé (uniquement opencode/*-free)"
  case "$raw" in
    *freellm*|*FreeLLM*|*[Ff]ree[Ll][Ll][Mm]*)
      fail "modèle refusé (pas de FreeLLM) : $raw"
      ;;
  esac
  m=$(normalize_model "$raw")
  [[ "$m" =~ ^opencode/[a-z0-9][a-z0-9.-]*-free$ ]] \
    || fail "modèle refusé (uniquement opencode/*-free) : $raw"
  printf '%s\n' "$m"
}

gh_bin() {
  printf '%s\n' "${EMU_E2E_GH:-gh}"
}

read_token() {
  local f="${EMU_E2E_TOKEN_FILE:-}"
  if [ "$(id -u)" -eq 0 ] && [ -f "$CANON_TOKEN" ]; then
    f="$CANON_TOKEN"
  fi
  [ -n "$f" ] || f="$CANON_TOKEN"
  [ -r "$f" ] || fail "jeton GALASS_TOKEN inaccessible (fichier d'outil figé)"
  # une seule ligne, sans l'afficher
  IFS= read -r token < "$f" || true
  [ -n "${token:-}" ] || fail "jeton GALASS_TOKEN vide"
}

urlenc() {
  python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

branch_exists() {
  local repo="$1" ref="$2" enc gh
  gh=$(gh_bin)
  enc=$(urlenc "$ref")
  GH_TOKEN="$token" GH_PROMPT_DISABLED=1 "$gh" api --silent "repos/${EMU_OWNER}/${repo}/branches/${enc}"
}

resolve_one() {
  local repo="$1" ref
  if branch_exists "$repo" "$OC_BRANCH"; then
    printf '%s\n' "$OC_BRANCH"
  else
    printf '%s\n' "$FALLBACK_REF"
  fi
}

resolve_refs() {
  load_config
  read_token
  rider_ref=$(resolve_one "$RIDER_REPO")
  driver_ref=$(resolve_one "$DRIVER_REPO")
  # emu_ref : branche de galass-emu-actions-pub lui-même (le harnais e2e), pas
  # seulement Rider/Driver — revue : sans elle, `gh workflow run` tournait toujours
  # sur le harnais de main, même quand la branche de travail le modifiait.
  emu_ref=$(resolve_one "$EMU_REPO_NAME")
  echo "rider_ref=${rider_ref}"
  echo "driver_ref=${driver_ref}"
  echo "emu_ref=${emu_ref}"
  if [ "$rider_ref" = "$FALLBACK_REF" ] && [ "$OC_BRANCH" != "$FALLBACK_REF" ]; then
    echo "note : ${RIDER_REPO} n'a pas la branche ${OC_BRANCH} sur GitHub ; fallback ${FALLBACK_REF}."
  fi
  if [ "$driver_ref" = "$FALLBACK_REF" ] && [ "$OC_BRANCH" != "$FALLBACK_REF" ]; then
    echo "note : ${DRIVER_REPO} n'a pas la branche ${OC_BRANCH} sur GitHub ; fallback ${FALLBACK_REF}."
  fi
  if [ "$emu_ref" = "$FALLBACK_REF" ] && [ "$OC_BRANCH" != "$FALLBACK_REF" ]; then
    echo "note : ${EMU_REPO_NAME} n'a pas la branche ${OC_BRANCH} sur GitHub ; fallback ${FALLBACK_REF}."
  fi
}

prompt_block() {
  cat <<EOF
# Tests e2e via galass-emu-actions-pub (with_emulators)

Les émulateurs ne tournent pas sur ce runner. Pour lancer les tests e2e (vrai staging,
apps Rider et Driver), appelle seulement :

    /opt/fullrun-tools/emu-e2e.sh run

Cet outil déclenche le workflow \`artemis-staging-e2e.yml\` sur
\`LordThiouk/galass-emu-actions-pub\` (les secrets e2e restent dans ce dépôt), attend
la fin (délai borné), puis affiche le verdict et, en cas d'échec, un court extrait
des logs (pas le journal complet). Tu peux corriger le code, commiter, puis relancer
la commande en boucle.

- \`rider_ref\` / \`driver_ref\` : la branche de travail \`\$OC_BRANCH\` si elle existe
  sur le dépôt, sinon \`main\`. Tu ne choisis pas ces refs toi-même.
- Si le script retombe sur \`main\`, la branche de travail n'est pas encore sur GitHub :
  attends le push wip, puis relance.
- Modèle côté emu : uniquement \`opencode/*-free\` (défaut
  \`opencode/deepseek-v4.1-flash-free\`). Le CLI opencode (pas une clé API)
  pilote les émulateurs sur le dépôt emu. Pas de FreeLLM, pas d'appel HTTP
  direct à un modèle. Les modèles FullRun restent \`opencode/*-free\`.
- Tu n'as aucun jeton : n'utilise pas \`gh\` toi-même, n'invente pas de secret,
  n'écris aucun secret. Passe seulement par le script figé ci-dessus
  (pas une copie dans le workspace).
EOF
}

append_prompt() {
  local p
  [ -n "${OC_WORK:-}" ] || fail "OC_WORK manquant"
  p="${OC_WORK}/prompt.md"
  [ -f "$p" ] || fail "prompt introuvable : $p"
  { printf '\n'; prompt_block; printf '\n'; } >> "$p"
  echo "bloc e2e (emu-e2e) ajouté au prompt"
}

iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

iso_minus() {
  local sec="$1"
  date -u -d "-${sec} seconds" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || python3 -c 'import datetime,sys; s=int(sys.argv[1]); print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(seconds=s)).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$sec"
}

redact_stream() {
  # Masque le jeton s'il apparaît, coupe les lignes trop longues, garde un tail court.
  local tok="$1" tailn="$2" width="$3"
  python3 -c '
import sys
tok, tailn, width = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
lines = sys.stdin.read().splitlines()
out = []
for line in lines:
    if tok:
        line = line.replace(tok, "***")
    if len(line) > width:
        line = line[:width] + "…"
    out.append(line)
if len(out) > tailn:
    out = out[-tailn:]
sys.stdout.write("\n".join(out))
if out:
    sys.stdout.write("\n")
' "$tok" "$tailn" "$width"
}

gh_cmd() {
  local gh
  gh=$(gh_bin)
  GH_TOKEN="$token" GH_PROMPT_DISABLED=1 "$gh" "$@"
}

find_new_run() {
  # ref : filtre obligatoire par branche (revue). Sans lui, un run plus récent
  # mais déclenché sur une autre branche (ex. main, par un autre job) passerait
  # avant le bon run — même dans la fenêtre "since".
  local since="$1" ref="$2" json
  json=$(gh_cmd run list -R "$EMU_REPO" --workflow="$EMU_WORKFLOW" \
    --event=workflow_dispatch --limit 10 \
    --json databaseId,createdAt,status,conclusion,url,headBranch) || return 1
  python3 -c '
import json,sys
since, ref = sys.argv[1], sys.argv[2]
rows=json.loads(sys.argv[3])
cands=[r for r in rows if (r.get("createdAt") or "") >= since and (r.get("headBranch") or "") == ref]
if not cands:
    sys.exit(2)
cands.sort(key=lambda r: r.get("createdAt") or "", reverse=True)
print(cands[0]["databaseId"])
' "$since" "$ref" "$json"
}

view_run() {
  gh_cmd run view "$1" -R "$EMU_REPO" --json status,conclusion,url,displayTitle,headBranch
}

run_e2e() {
  local since run_id deadline status conclusion url view s_status s_conclusion s_url
  load_config
  EMU_E2E_MODEL=$(validate_model "$EMU_E2E_MODEL")
  if [ "${GITHUB_ACTIONS:-}" != "true" ] && [ -z "${EMU_E2E_GH:-}" ]; then
    fail "refus : lancer seulement depuis le FullRun (ou un test avec EMU_E2E_GH)"
  fi
  read_token
  rider_ref=$(resolve_one "$RIDER_REPO")
  driver_ref=$(resolve_one "$DRIVER_REPO")
  # emu_ref : branche du harnais lui-même. Sans --ref, `gh workflow run` exécute
  # TOUJOURS la version du workflow sur la branche par défaut (main) du dépôt
  # emu — jamais celle de la branche de travail, même si rider_ref/driver_ref
  # pointent dessus (revue : l.361, chaque e2e tournait sur le harnais de main).
  emu_ref=$(resolve_one "$EMU_REPO_NAME")
  echo "déclenchement : $EMU_REPO $EMU_WORKFLOW"
  echo "rider_ref=${rider_ref} driver_ref=${driver_ref} emu_ref=${emu_ref} model=${EMU_E2E_MODEL}"
  if [ "$rider_ref" = "$FALLBACK_REF" ] && [ "$OC_BRANCH" != "$FALLBACK_REF" ]; then
    echo "note : ${RIDER_REPO} n'a pas la branche ${OC_BRANCH} sur GitHub ; fallback ${FALLBACK_REF}."
  fi
  if [ "$driver_ref" = "$FALLBACK_REF" ] && [ "$OC_BRANCH" != "$FALLBACK_REF" ]; then
    echo "note : ${DRIVER_REPO} n'a pas la branche ${OC_BRANCH} sur GitHub ; fallback ${FALLBACK_REF}."
  fi
  if [ "$emu_ref" = "$FALLBACK_REF" ] && [ "$OC_BRANCH" != "$FALLBACK_REF" ]; then
    echo "note : ${EMU_REPO_NAME} n'a pas la branche ${OC_BRANCH} sur GitHub ; fallback ${FALLBACK_REF}."
  fi

  since=$(iso_minus 15)
  if ! gh_cmd workflow run "$EMU_WORKFLOW" -R "$EMU_REPO" --ref "$emu_ref" \
      -f "rider_ref=${rider_ref}" -f "driver_ref=${driver_ref}" \
      -f "model=${EMU_E2E_MODEL}"; then
    fail "échec du déclenchement : le jeton GALASS_TOKEN a-t-il le droit actions:write sur ${EMU_REPO} ?"
  fi

  deadline=$(( $(date +%s) + EMU_E2E_TIMEOUT_SEC ))
  run_id=""
  while [ "$(date +%s)" -lt "$deadline" ]; do
    # find_new_run filtre désormais par branche (emu_ref) : un run plus récent
    # mais sur une autre branche (ex. un autre job sur main) ne doit jamais être
    # pris pour celui qu'on vient de déclencher.
    if run_id=$(find_new_run "$since" "$emu_ref" 2>/dev/null); then
      [ -n "$run_id" ] && break
    fi
    run_id=""
    [ "$EMU_E2E_POLL_SEC" -gt 0 ] && sleep "$EMU_E2E_POLL_SEC"
    [ "$EMU_E2E_POLL_SEC" -eq 0 ] && sleep 1
  done
  [ -n "$run_id" ] || fail "aucun run e2e trouvé avant le délai sur la branche ${emu_ref} (déclenchement peut-être refusé ou mauvais ref)"
  echo "run=${run_id} https://github.com/${EMU_REPO}/actions/runs/${run_id}"

  # Garde-fou supplémentaire (revue) : même après le filtre de find_new_run, on
  # revérifie le head_branch du run RETENU avant d'en attendre le verdict.
  # Jamais de silence sur un mauvais ref (ex. API en retard, run réutilisé).
  view0=$(view_run "$run_id") || fail "impossible de lire le run ${run_id}"
  head_branch=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("headBranch") or "")' "$view0")
  [ "$head_branch" = "$emu_ref" ] \
    || fail "mauvais ref : run ${run_id} sur head_branch=${head_branch:-?} (attendu ${emu_ref})"

  status=""
  conclusion=""
  url=""
  while [ "$(date +%s)" -lt "$deadline" ]; do
    view=$(view_run "$run_id") || fail "impossible de lire le run ${run_id}"
    eval "$(python3 -c '
import json,sys,shlex
d=json.loads(sys.argv[1])
for k in ("status","conclusion","url"):
    print("s_%s=%s" % (k, shlex.quote(str(d.get(k) or ""))))
' "$view")"
    status="$s_status"
    conclusion="$s_conclusion"
    url="$s_url"
    case "$status" in
      completed|cancelled) break ;;
    esac
    [ "$EMU_E2E_POLL_SEC" -gt 0 ] && sleep "$EMU_E2E_POLL_SEC"
    [ "$EMU_E2E_POLL_SEC" -eq 0 ] && sleep 1
  done

  if [ "$status" != "completed" ] && [ "$status" != "cancelled" ]; then
    echo "verdict=timeout status=${status:-?} run=${run_id}" >&2
    echo "timeout : le run ${run_id} n'a pas fini en ${EMU_E2E_TIMEOUT_SEC}s" >&2
    exit 124
  fi

  echo "verdict=${conclusion:-$status} status=${status} run=${run_id}"
  [ -n "$url" ] && echo "url=${url}"

  if [ "$conclusion" = "success" ]; then
    echo "e2e : succès"
    return 0
  fi

  echo "e2e : échec (${conclusion:-$status})"
  echo "extrait des logs (tail, pas le journal complet) :"
  if ! gh_cmd run view "$run_id" -R "$EMU_REPO" --log-failed 2>/dev/null \
      | redact_stream "$token" "$EMU_LOG_TAIL" "$EMU_LOG_WIDTH"; then
    echo "(extrait indisponible)"
  fi
  return 1
}

cmd="${1:-}"
case "$cmd" in
  run|resolve-refs) maybe_sudo "$@" ;;
esac

case "$cmd" in
  run) run_e2e ;;
  resolve-refs) resolve_refs ;;
  prompt-block) prompt_block ;;
  append-prompt) append_prompt ;;
  *) fail "commande inconnue : ${cmd:-<vide>}" ;;
esac
