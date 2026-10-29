#!/usr/bin/env bash
#
# Detect (and optionally repair) wildcard deny entries that lost a regex anchor.
#
# `pihole --wild <domain>` is meant to store `(\.|^)domain\.tld$`. Passing more
# than one domain in a SINGLE argument silently produces fragments instead:
# CreateDomainList() in /opt/pihole/list.sh wraps the whole argument once --
#
#     dom="(\\.|^)${dom//\./\\.}$"
#
# -- and AddDomain() then splits that string on spaces when building the API
# payload (`jq ... $domains | split(" ")`). The anchoring therefore happens
# before the split, so the first token keeps `(\.|^)` and loses `$`, the last
# keeps `$` and loses the prefix, and any token between them gets neither.
#
# The fragments are valid regexes, so Pi-hole accepts them without complaint,
# but they are substring matches. `wildtest-a\.example` (no `$`) blackholes
# wildtest-a.example.attacker.net; `wildtest-b\.example$` (no prefix)
# blackholes notwildtest-b.example. The failure direction is over-blocking.
#
# This is present on Pi-hole master as of 2026-10-28, identical to Core v6.4,
# so updating the image does not fix it. Our own `make import-wildcards` calls
# `pihole --wild` once per domain and cannot trigger it; this check exists so
# that a future caller which gets it wrong is caught rather than silently
# over-blocking.
#
# Usage: check-wildcard-anchoring.sh [--fix] [--container NAME]

set -euo pipefail

CONTAINER="pihole"
FIX=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)       FIX=true; shift ;;
        --container) CONTAINER="$2"; shift 2 ;;
        -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
        *)           echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

ftl_sql() {
    docker exec "$CONTAINER" pihole-FTL sqlite3 /etc/pihole/gravity.db "$1"
}

# type=3 is "regex deny" in Pi-hole's domainlist table. Fields are tab-joined:
# the regexes themselves contain `|` (from the `(\.|^)` prefix), so a pipe
# delimiter would split mid-pattern.
mapfile -t entries < <(ftl_sql "select id||char(9)||domain from domainlist where type=3;")

malformed=()
for row in "${entries[@]}"; do
    [[ -z "$row" ]] && continue
    id="${row%%$'\t'*}"
    rx="${row#*$'\t'}"

    body="$rx"
    had_prefix=false
    had_suffix=false
    if [[ "$body" == '(\.|^)'* ]]; then body="${body#'(\.|^)'}"; had_prefix=true; fi
    if [[ "$body" == *'$' ]];      then body="${body%'$'}";      had_suffix=true; fi

    # Only judge entries whose remainder is a plain escaped domain. Anything
    # with other metacharacters is a hand-written regex, not a mangled
    # wildcard, and is none of this check's business.
    if [[ ! "$body" =~ ^([a-zA-Z0-9_-]+\\\.)*[a-zA-Z0-9_-]+$ ]]; then
        continue
    fi

    if ! { $had_prefix && $had_suffix; }; then
        malformed+=("${id}"$'\t'"${rx}"$'\t'"${body}")
    fi
done

if [[ ${#malformed[@]} -eq 0 ]]; then
    echo "OK: all ${#entries[@]} wildcard deny entries are correctly anchored."
    exit 0
fi

echo "Found ${#malformed[@]} wildcard deny entr(ies) missing an anchor:" >&2
for m in "${malformed[@]}"; do
    IFS=$'\t' read -r id rx body <<<"$m"
    printf '  id=%-4s %-46s -> should be (\\.|^)%s$\n' "$id" "$rx" "$body" >&2
done

if ! $FIX; then
    echo >&2
    echo "These are substring matches and will over-block. Re-run with --fix to repair." >&2
    exit 1
fi

echo
for m in "${malformed[@]}"; do
    IFS=$'\t' read -r id rx body <<<"$m"
    fixed='(\.|^)'"${body}"'$'
    # Collapse onto an existing correct entry if one already covers this domain.
    existing=$(ftl_sql "select count(*) from domainlist where type=3 and domain='${fixed}';")
    if [[ "$existing" != "0" ]]; then
        ftl_sql "delete from domainlist where id=${id};"
        echo "  removed id=${id} (${rx}) -- ${fixed} already present"
    else
        ftl_sql "update domainlist set domain='${fixed}' where id=${id};"
        echo "  repaired id=${id}: ${rx} -> ${fixed}"
    fi
done

# FTL caches both the compiled regex set and prior DNS verdicts. `pihole
# reloaddns` reloads the regexes but leaves already-answered names holding
# their old verdict, so a repaired entry appears not to have taken effect;
# reload-lists plus a cache flush is what actually makes it observable.
docker exec "$CONTAINER" pihole restartdns reload-lists >/dev/null 2>&1
docker exec "$CONTAINER" pihole flush >/dev/null 2>&1 || true
echo
echo "Repaired ${#malformed[@]} entr(ies) and reloaded FTL."
