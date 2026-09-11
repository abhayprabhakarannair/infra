#!/usr/bin/env bash
# Reconcile a declared subset of Prowlarr configuration without removing
# objects that are not declared here. Intended for a systemd oneshot service.
set -euo pipefail

readonly program_name=${0##*/}

fatal() {
  printf '%s: %s\n' "$program_name" "$*" >&2
  exit 1
}

log() {
  printf '%s: %s\n' "$program_name" "$*" >&2
}

usage() {
  cat <<EOF
Usage: $program_name --state PATH

Reconcile declared Prowlarr tags, indexers, download clients, applications,
and application profiles. The state file must be JSON (JSON is valid YAML 1.2).

Required environment:
  PROWLARR_API_KEY or PROWLARR_API_KEY_FILE

Optional environment:
  PROWLARR_URL                    Prowlarr URL (default: http://127.0.0.1:9696)
  PROWLARR_READY_TIMEOUT_SECONDS  Readiness deadline (default: 120)
  PROWLARR_RETRY_INTERVAL_SECONDS Retry interval (default: 2)
  PROWLARR_HTTP_TIMEOUT_SECONDS   Per-request deadline (default: 20)
  CURL_BIN                        curl executable (default: curl)
EOF
}

state_file=""
while (($# > 0)); do
  case "$1" in
    --state)
      (($# >= 2)) || fatal "--state requires a path"
      state_file=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fatal "unknown argument: $1"
      ;;
  esac
done

[[ -n "$state_file" ]] || fatal "--state is required"
[[ -r "$state_file" ]] || fatal "state file is not readable: $state_file"

curl_bin=${CURL_BIN:-curl}
command -v "$curl_bin" >/dev/null 2>&1 || fatal "curl executable not found: $curl_bin"
command -v jq >/dev/null 2>&1 || fatal "jq is required"

require_non_negative_integer() {
  local name=$1 value=$2
  case "$value" in
    ''|*[!0-9]*) fatal "$name must be a non-negative integer, got: $value" ;;
  esac
}

ready_timeout=${PROWLARR_READY_TIMEOUT_SECONDS:-120}
retry_interval=${PROWLARR_RETRY_INTERVAL_SECONDS:-2}
http_timeout=${PROWLARR_HTTP_TIMEOUT_SECONDS:-20}
require_non_negative_integer PROWLARR_READY_TIMEOUT_SECONDS "$ready_timeout"
require_non_negative_integer PROWLARR_RETRY_INTERVAL_SECONDS "$retry_interval"
require_non_negative_integer PROWLARR_HTTP_TIMEOUT_SECONDS "$http_timeout"
((retry_interval > 0)) || fatal "PROWLARR_RETRY_INTERVAL_SECONDS must be greater than zero"
((http_timeout > 0)) || fatal "PROWLARR_HTTP_TIMEOUT_SECONDS must be greater than zero"

prowlarr_url=${PROWLARR_URL:-http://127.0.0.1:9696}
prowlarr_url=${prowlarr_url%/}
[[ "$prowlarr_url" =~ ^https?://[^/?#]+(/[^?#]*)?$ ]] || fatal "PROWLARR_URL must be an http(s) URL without a query or fragment"

if [[ -n ${PROWLARR_API_KEY:-} && -n ${PROWLARR_API_KEY_FILE:-} ]]; then
  fatal "set exactly one of PROWLARR_API_KEY or PROWLARR_API_KEY_FILE"
fi

if [[ -n ${PROWLARR_API_KEY_FILE:-} ]]; then
  [[ -r "$PROWLARR_API_KEY_FILE" ]] || fatal "PROWLARR_API_KEY_FILE is not readable"
  prowlarr_api_key=$(<"$PROWLARR_API_KEY_FILE")
else
  prowlarr_api_key=${PROWLARR_API_KEY:-}
fi

[[ -n "$prowlarr_api_key" ]] || fatal "PROWLARR_API_KEY or PROWLARR_API_KEY_FILE is required"
[[ "$prowlarr_api_key" != *$'\n'* && "$prowlarr_api_key" != *$'\r'* ]] || fatal "Prowlarr API key must be a single line"

runtime_dir=$(mktemp -d)
cleanup() {
  rm -rf "$runtime_dir"
}
trap cleanup EXIT

# Keep the API key out of curl's process arguments. curl accepts a header file
# through --header @PATH; the file is private and removed on exit.
api_key_header_file="$runtime_dir/api-key.header"
umask 077
printf 'X-Api-Key: %s\n' "$prowlarr_api_key" >"$api_key_header_file"

# Substitute only whole-string ${ENV:NAME} values. This allows an encrypted
# state file to refer to a separate systemd credential without placing a
# provider key in Nix or an unencrypted fixture.
if ! state_json=$(jq -ce '
  def substitute_environment:
    if type == "string" and test("^\\$\\{ENV:[A-Z][A-Z0-9_]*\\}$") then
      capture("^\\$\\{ENV:(?<name>[A-Z][A-Z0-9_]*)\\}$").name as $name
      | env[$name] // error("environment variable " + $name + " is required")
    elif type == "array" then map(substitute_environment)
    elif type == "object" then with_entries(.value |= substitute_environment)
    else .
    end;

  def require_array($key):
    if has($key) and (.[$key] | type) != "array" then
      error($key + " must be an array")
    else .
    end;

  def require_named_objects($key; $identity):
    (.[$key] // [])
    | if all(.[]; type == "object" and (.[$identity] | type) == "string" and (.[$identity] | length) > 0) then
        .
      else
        error($key + " entries must be objects with a non-empty " + $identity)
      end
    | if ([.[][$identity]] | unique | length) == length then
        .
      else
        error($key + " contains duplicate " + $identity + " values")
      end;

  def validate_fields:
    if has("fields") then
      if (.fields | type) != "array" then
        error("fields must be an array")
      elif (all(.fields[]; type == "object" and (.name | type) == "string" and (.name | length) > 0) | not) then
        error("fields entries must have a non-empty name")
      elif ([.fields[].name] | unique | length) != (.fields | length) then
        error("fields contains duplicate name values")
      else .
      end
    else .
    end;

  substitute_environment
  | if type != "object" then error("state must be an object") else . end
  | if ((keys - ["tags", "indexers", "downloadClients", "applications", "appProfiles"]) | length) != 0 then
      error("unknown top-level state key")
    else .
    end
  | require_array("tags")
  | require_array("indexers")
  | require_array("downloadClients")
  | require_array("applications")
  | require_array("appProfiles")
  | .tags = require_named_objects("tags"; "label")
  | .indexers = require_named_objects("indexers"; "name")
  | .downloadClients = require_named_objects("downloadClients"; "name")
  | .applications = require_named_objects("applications"; "name")
  | .appProfiles = require_named_objects("appProfiles"; "name")
  | .indexers |= map(validate_fields)
  | .downloadClients |= map(validate_fields)
  | .applications |= map(validate_fields)
' "$state_file"); then
  fatal "desired state is invalid: $state_file"
fi

api_request() {
  local method=$1 endpoint=$2 body=${3:-}
  local -a args=(
    --silent
    --show-error
    --fail-with-body
    --connect-timeout 5
    --max-time "$http_timeout"
    --header "@$api_key_header_file"
    --header "Accept: application/json"
    --request "$method"
  )

  if [[ -n "$body" ]]; then
    args+=(--header "Content-Type: application/json" --data-binary @-)
    # Keep provider credentials out of argv and systemd's journal.
    printf '%s' "$body" | "$curl_bin" "${args[@]}" "$prowlarr_url$endpoint"
  else
    "$curl_bin" "${args[@]}" "$prowlarr_url$endpoint"
  fi
}

get_array() {
  local endpoint=$1 response
  response=$(api_request GET "$endpoint") || fatal "GET $endpoint failed"
  jq -ce 'if type == "array" then . else error("expected an array") end' <<<"$response" \
    || fatal "GET $endpoint returned invalid JSON"
}

wait_for_prowlarr() {
  local started elapsed=0 remaining sleep_for
  started=$(date +%s)
  while ! api_request GET /api/v1/system/status >/dev/null 2>&1; do
    elapsed=$(( $(date +%s) - started ))
    if ((elapsed >= ready_timeout)); then
      fatal "Prowlarr did not become ready within ${ready_timeout}s at $prowlarr_url"
    fi
    remaining=$((ready_timeout - elapsed))
    sleep_for=$retry_interval
    ((sleep_for > remaining)) && sleep_for=$remaining
    sleep "$sleep_for"
  done
}

# Does actual contain every declared object key/value? Arrays are compared as a
# whole except for Prowlarr provider fields, where the API adds metadata to
# each named field. Unknown API fields are ignored.
declared_matches() {
  local actual=$1 declared=$2
  local actual_file="$runtime_dir/actual.json" declared_file="$runtime_dir/declared.json"
  printf '%s' "$actual" >"$actual_file"
  printf '%s' "$declared" >"$declared_file"
  jq -ne --slurpfile actual "$actual_file" --slurpfile declared "$declared_file" '
    def declared_equal($actual; $declared):
      if ($declared | type) == "object" then
        [ $declared | to_entries[] |
          . as $entry |
          if $entry.key == "fields" and ($entry.value | type) == "array" then
            if ($actual | type) != "object" or ($actual.fields | type) != "array" then
              false
            else
              [ $entry.value[] as $field |
                ($actual.fields | map(select(.name == $field.name))) as $matches |
                ($matches | length) == 1
                and declared_equal($matches[0]; $field)
              ] | all
            end
          else
            ($actual | type) == "object"
            and ($actual | has($entry.key))
            and declared_equal($actual[$entry.key]; $entry.value)
          end
        ] | all
      elif ($declared | type) == "array" then $actual == $declared
      else $actual == $declared
      end;
    declared_equal($actual[0]; $declared[0])
  ' >/dev/null
}

find_existing() {
  local collection=$1 identity_key=$2 identity_value=$3 implementation=${4:-}
  jq -c --arg key "$identity_key" --arg value "$identity_value" --arg implementation "$implementation" '
    [ .[]
      | select(.[$key] == $value)
      | select($implementation == "" or .implementation == $implementation)
    ]
    | if length == 0 then null
      elif length == 1 then .[0]
      else error("multiple existing objects match the declared identity")
      end
  ' <<<"$collection"
}

reconcile_object() {
  local kind=$1 endpoint=$2 collection=$3 identity_key=$4 declared=$5
  local identity implementation existing desired payload
  identity=$(jq -er --arg key "$identity_key" '.[$key]' <<<"$declared")
  implementation=$(jq -r '.implementation // ""' <<<"$declared")
  desired=$(jq -ce 'del(.id)' <<<"$declared")
  existing=$(find_existing "$collection" "$identity_key" "$identity" "$implementation") \
    || fatal "cannot identify declared $kind '$identity'"

  if [[ "$existing" == "null" ]]; then
    api_request POST "$endpoint" "$desired" >/dev/null \
      || fatal "creating $kind '$identity' failed"
    log "created $kind '$identity'"
    return
  fi

  if declared_matches "$existing" "$desired"; then
    log "unchanged $kind '$identity'"
    return
  fi

  local existing_file="$runtime_dir/existing.json" desired_file="$runtime_dir/desired.json"
  printf '%s' "$existing" >"$existing_file"
  printf '%s' "$desired" >"$desired_file"
  payload=$(jq -nce --slurpfile existing "$existing_file" --slurpfile desired "$desired_file" '
    def merge_fields($actual; $declared):
      reduce $declared[] as $field
        (($actual // []);
          if any(.[]; .name == $field.name) then
            map(if .name == $field.name then . * $field else . end)
          else
            . + [$field]
          end);

    def merge_declared($actual; $declared):
      reduce ($declared | to_entries[]) as $entry
        ($actual;
          if $entry.key == "fields" and ($entry.value | type) == "array" then
            .fields = merge_fields(.fields; $entry.value)
          else
            .[$entry.key] = $entry.value
          end);

    merge_declared($existing[0]; $desired[0])
  ')
  api_request PUT "$endpoint/$(jq -er '.id' <<<"$existing")" "$payload" >/dev/null \
    || fatal "updating $kind '$identity' failed"
  log "updated $kind '$identity'"
}

reconcile_tags() {
  local collection declared
  collection=$(get_array /api/v1/tag)
  while IFS= read -r declared; do
    reconcile_object tag /api/v1/tag "$collection" label "$declared"
    # Keep the local identity map current so later tag labels include newly
    # created tags and duplicate labels are caught by the API read.
    collection=$(get_array /api/v1/tag)
  done < <(jq -c '.tags[]?' <<<"$state_json")
}

resolve_tag_labels() {
  local declared=$1 tags=$2
  local tags_file="$runtime_dir/tags.json"
  printf '%s' "$tags" >"$tags_file"
  jq -ce --slurpfile tags "$tags_file" '
    def tag_ids($labels):
      [ $labels[] as $label |
        ($tags[0] | map(select(.label == $label))) as $matches |
        if ($matches | length) == 1 then $matches[0].id
        elif ($matches | length) == 0 then error("declared tag label is missing: " + $label)
        else error("multiple Prowlarr tags have label: " + $label)
        end
      ];
    if has("tagLabels") then
      if has("tags") then error("use either tags or tagLabels, not both")
      elif (.tagLabels | type) != "array" or (all(.tagLabels[]; type == "string" and length > 0) | not) then
        error("tagLabels must be an array of non-empty strings")
      else .tags = tag_ids(.tagLabels) | del(.tagLabels)
      end
    else .
    end
  ' <<<"$declared"
}

resolve_app_profile_name() {
  local declared=$1 profiles=$2
  local profiles_file="$runtime_dir/app-profiles.json"
  printf '%s' "$profiles" >"$profiles_file"
  jq -ce --slurpfile profiles "$profiles_file" '
    if has("appProfileName") then
      if has("appProfileId") then error("use either appProfileName or appProfileId, not both")
      else
        (.appProfileName) as $name
        | ($profiles[0] | map(select(.name == $name))) as $matches
        | if ($matches | length) == 1 then
            .appProfileId = $matches[0].id | del(.appProfileName)
          elif ($matches | length) == 0 then
            error("declared app profile is missing: " + $name)
          else
            error("multiple Prowlarr app profiles have name: " + $name)
          end
      end
    else .
    end
  ' <<<"$declared"
}

reconcile_collection() {
  local kind=$1 state_key=$2 endpoint=$3 resolve_tags=$4
  local collection tags declared resolved
  collection=$(get_array "$endpoint")
  tags=$(get_array /api/v1/tag)
  while IFS= read -r declared; do
    resolved=$declared
    if [[ "$resolve_tags" == true ]]; then
      resolved=$(resolve_tag_labels "$resolved" "$tags") \
        || fatal "invalid tag labels for declared $kind"
    fi
    reconcile_object "$kind" "$endpoint" "$collection" name "$resolved"
    collection=$(get_array "$endpoint")
  done < <(jq -c --arg key "$state_key" '.[$key][]?' <<<"$state_json")
}

wait_for_prowlarr
log "Prowlarr is ready; reconciling declared state"
reconcile_tags
reconcile_collection "application profile" appProfiles /api/v1/appprofile false
app_profiles=$(get_array /api/v1/appprofile)

while IFS= read -r declared; do
  resolved=$(resolve_tag_labels "$declared" "$(get_array /api/v1/tag)") \
    || fatal "invalid tag labels for declared indexer"
  resolved=$(resolve_app_profile_name "$resolved" "$app_profiles") \
    || fatal "invalid app profile reference for declared indexer"
  # Reuse the generic reconciler with a one-object collection so the same
  # non-destructive update behavior applies after resolving references.
  indexers=$(get_array /api/v1/indexer)
  reconcile_object indexer /api/v1/indexer "$indexers" name "$resolved"
done < <(jq -c '.indexers[]?' <<<"$state_json")

reconcile_collection "download client" downloadClients /api/v1/downloadclient true
reconcile_collection application applications /api/v1/applications true
log "reconciliation complete"
