#!/usr/bin/env bash
set -euo pipefail

readonly test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly repo_dir=$(cd -- "$test_dir/../../.." && pwd)
readonly reconciler="$repo_dir/scripts/arr/prowlarr-reconcile.sh"
readonly temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected=$1 actual=$2 message=$3
  [[ "$expected" == "$actual" ]] || fail "$message (expected $expected, got $actual)"
}

cat >"$temp_dir/mock-curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

method=GET
data=""
url=""
while (($# > 0)); do
  case "$1" in
    --request|-X)
      method=$2
      shift 2
      ;;
    --data-binary|-d|--data|--data-raw)
      if [[ $2 == @- ]]; then
        data=$(cat)
      else
        data=$2
      fi
      shift 2
      ;;
    --header|-H|--connect-timeout|--max-time)
      shift 2
      ;;
    --silent|--show-error|--fail-with-body)
      shift
      ;;
    *)
      url=$1
      shift
      ;;
  esac
done

path=${url#http://127.0.0.1:9696}
path=${path%%\?*}
printf '%s %s\n' "$method" "$path" >>"$MOCK_LOG"

if [[ $path == /api/v1/system/status ]]; then
  ready_count_file="$MOCK_DB.ready-count"
  ready_count=0
  [[ -r $ready_count_file ]] && ready_count=$(<"$ready_count_file")
  if ((ready_count < ${MOCK_READY_FAILURES:-0})); then
    printf '%s' $((ready_count + 1)) >"$ready_count_file"
    exit 22
  fi
  printf '%s\n' '{}'
  exit 0
fi

case "$path" in
  /api/v1/tag) key=tags ;;
  /api/v1/indexer) key=indexers ;;
  /api/v1/downloadclient) key=downloadClients ;;
  /api/v1/applications) key=applications ;;
  /api/v1/appprofile) key=appProfiles ;;
  /api/v1/tag/*) key=tags ;;
  /api/v1/indexer/*) key=indexers ;;
  /api/v1/downloadclient/*) key=downloadClients ;;
  /api/v1/applications/*) key=applications ;;
  /api/v1/appprofile/*) key=appProfiles ;;
  *) exit 22 ;;
esac

case "$method" in
  GET)
    jq -c --arg key "$key" '.[$key]' "$MOCK_DB"
    ;;
  POST)
    next_id=$(jq --arg key "$key" '[.[$key][]?.id] | max // 0 | . + 1' "$MOCK_DB")
    response=$(jq -c --argjson id "$next_id" '. + {id: $id}' <<<"$data")
    tmp=$(mktemp "${MOCK_DB}.XXXXXX")
    jq --arg key "$key" --argjson object "$response" '.[$key] += [$object]' "$MOCK_DB" >"$tmp"
    mv "$tmp" "$MOCK_DB"
    printf '%s\n' "$response"
    ;;
  PUT)
    id=${path##*/}
    tmp=$(mktemp "${MOCK_DB}.XXXXXX")
    jq --arg key "$key" --arg id "$id" --argjson object "$data" '
      .[$key] |= map(if (.id | tostring) == $id then $object else . end)
    ' "$MOCK_DB" >"$tmp"
    mv "$tmp" "$MOCK_DB"
    printf '%s\n' "$data"
    ;;
  *) exit 22 ;;
esac
EOF
chmod +x "$temp_dir/mock-curl"

cat >"$temp_dir/state.json" <<'EOF'
{
  "tags": [{"label": "movies"}],
  "indexers": [{
    "name": "Example Newznab",
    "implementation": "Newznab",
    "enable": true,
    "priority": 25,
    "appProfileName": "Movies",
    "tagLabels": ["movies"],
    "fields": [{"name": "apiKey", "value": "${ENV:INDEXER_API_KEY}"}]
  }],
  "downloadClients": [{
    "name": "qBittorrent",
    "implementation": "QBittorrent",
    "enable": true,
    "tagLabels": ["movies"]
  }],
  "applications": [{
    "name": "Radarr",
    "implementation": "Radarr",
    "syncLevel": "fullSync",
    "tagLabels": ["movies"]
  }],
  "appProfiles": [{
    "name": "Movies",
    "enableRss": true,
    "enableAutomaticSearch": true,
    "enableInteractiveSearch": true,
    "minimumSeeders": 1
  }]
}
EOF

cat >"$temp_dir/db.json" <<'EOF'
{
  "tags": [{"id": 1, "label": "unmanaged"}],
  "indexers": [{"id": 2, "name": "Example Newznab", "implementation": "Newznab", "enable": false, "priority": 25, "tags": [], "fields": [{"name": "apiKey", "value": "old", "order": 1, "label": "API key", "type": "textbox", "privacy": "password"}], "runtimeOnly": "keep"}],
  "downloadClients": [{"id": 3, "name": "qBittorrent", "implementation": "QBittorrent", "enable": true, "tags": []}],
  "applications": [{"id": 4, "name": "Radarr", "implementation": "Radarr", "syncLevel": "addOnly", "tags": []}],
  "appProfiles": [{"id": 5, "name": "Movies", "enableRss": false, "enableAutomaticSearch": false, "enableInteractiveSearch": false, "minimumSeeders": 0}]
}
EOF

: >"$temp_dir/log"
MOCK_DB="$temp_dir/db.json" \
MOCK_LOG="$temp_dir/log" \
MOCK_READY_FAILURES=1 \
CURL_BIN="$temp_dir/mock-curl" \
PROWLARR_API_KEY=test-api-key \
PROWLARR_READY_TIMEOUT_SECONDS=5 \
PROWLARR_RETRY_INTERVAL_SECONDS=1 \
PROWLARR_HTTP_TIMEOUT_SECONDS=5 \
INDEXER_API_KEY=from-environment \
"$reconciler" --state "$temp_dir/state.json" >/dev/null

assert_eq 1 "$(jq '[.tags[] | select(.label == "unmanaged")] | length' "$temp_dir/db.json")" "unmanaged tag was not preserved"
assert_eq 1 "$(jq '[.tags[] | select(.label == "movies")] | length' "$temp_dir/db.json")" "declared tag was not created"
assert_eq true "$(jq -r '.indexers[0].enable' "$temp_dir/db.json")" "indexer was not updated"
assert_eq from-environment "$(jq -r '.indexers[0].fields[0].value' "$temp_dir/db.json")" "environment placeholder was not resolved"
assert_eq password "$(jq -r '.indexers[0].fields[0].privacy' "$temp_dir/db.json")" "provider field metadata was lost"
assert_eq fullSync "$(jq -r '.applications[0].syncLevel' "$temp_dir/db.json")" "application sync setting was not updated"
assert_eq 2 "$(jq '.indexers[0].tags[0]' "$temp_dir/db.json")" "tag label was not converted to Prowlarr tag ID"
assert_eq 5 "$(jq '.indexers[0].appProfileId' "$temp_dir/db.json")" "app profile name was not resolved to an ID"
assert_eq keep "$(jq -r '.indexers[0].runtimeOnly' "$temp_dir/db.json")" "unknown API field was lost during update"

: >"$temp_dir/log"
MOCK_DB="$temp_dir/db.json" \
MOCK_LOG="$temp_dir/log" \
CURL_BIN="$temp_dir/mock-curl" \
PROWLARR_API_KEY=test-api-key \
PROWLARR_READY_TIMEOUT_SECONDS=5 \
PROWLARR_RETRY_INTERVAL_SECONDS=1 \
PROWLARR_HTTP_TIMEOUT_SECONDS=5 \
INDEXER_API_KEY=from-environment \
"$reconciler" --state "$temp_dir/state.json" >/dev/null

assert_eq 0 "$(grep -Ec '^(POST|PUT) ' "$temp_dir/log" || true)" "second reconciliation changed an already-converged state"

if CURL_BIN="$temp_dir/mock-curl" "$reconciler" --state "$temp_dir/state.json" >/dev/null 2>&1; then
  fail "reconciler accepted a missing API key"
fi

jq '.indexers[0].fields = [{"name": "duplicate"}, {"name": "duplicate"}]' \
  "$temp_dir/state.json" >"$temp_dir/invalid-fields.json"
if PROWLARR_API_KEY=test-api-key CURL_BIN="$temp_dir/mock-curl" \
  "$reconciler" --state "$temp_dir/invalid-fields.json" >/dev/null 2>&1; then
  fail "reconciler accepted duplicate provider field names"
fi

printf 'PASS: prowlarr reconciler tests\n'
