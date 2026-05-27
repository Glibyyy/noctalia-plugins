#!/usr/bin/env bash
# Query bus arrivals: live data from curlbus + GTFS schedule from Stride API.
# Usage: query.sh <stop_code> [line1,line2,line3]
# Output: JSON grouped by line with up to 3 upcoming times each.

set -euo pipefail

STOP="${1:?stop code required}"
FILTER="${2:-}"

# Fetch both APIs in parallel
LIVE_FILE=$(mktemp)
SCHED_FILE=$(mktemp)
trap 'rm -f "$LIVE_FILE" "$SCHED_FILE"' EXIT

curl -sf -m 10 "https://curlbus.app/${STOP}" -H 'Accept: application/json' > "$LIVE_FILE" 2>/dev/null &
PID_LIVE=$!

# Build Stride GTFS request for each line
NOW_UTC=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
TODAY=$(date +%Y-%m-%d)
TOMORROW=$(date -d "+1 day" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
END_UTC=$(date -u -d "+24 hours" +%Y-%m-%dT%H:%M:%S+00:00 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S+00:00)

SCHED_DATA="["
first_sched=true
IFS=',' read -ra LINES <<< "$FILTER"
for line in "${LINES[@]}"; do
  line=$(echo "$line" | tr -d ' ')
  [ -z "$line" ] && continue
  result=$(curl -sf -m 10 "https://open-bus-stride-api.hasadna.org.il/gtfs_ride_stops/list?gtfs_stop__code=${STOP}&gtfs_route__route_short_name=${line}&gtfs_stop__date_from=${TODAY}&gtfs_stop__date_to=${TOMORROW}&arrival_time_from=${NOW_UTC}&arrival_time_to=${END_UTC}&limit=3&order_by=arrival_time" 2>/dev/null) || result="[]"
  [ "$first_sched" = true ] && first_sched=false || SCHED_DATA+=","
  SCHED_DATA+="{\"line\":\"${line}\",\"data\":${result}}"
done
SCHED_DATA+="]"
echo "$SCHED_DATA" > "$SCHED_FILE"

wait "$PID_LIVE" 2>/dev/null || true

python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta

tz = timedelta(hours=3)
tz_il = timezone(tz)
now = datetime.now(tz_il)

# Load live data
try:
    with open('$LIVE_FILE') as f:
        live_data = json.load(f)
except:
    live_data = {}

# Load schedule data
try:
    with open('$SCHED_FILE') as f:
        sched_data = json.load(f)
except:
    sched_data = []

requested = [l.strip() for l in '${FILTER}'.split(',') if l.strip()] if '${FILTER}' else []

stop_name = ''
si = live_data.get('stop_info', {})
if si:
    names = si.get('name', {})
    stop_name = names.get('HE', names.get('EN', ''))
if not stop_name:
    for s in sched_data:
        for item in s.get('data', []):
            sn = item.get('gtfs_stop__name', '')
            if sn:
                stop_name = sn
                break
        if stop_name:
            break

# Gather live arrivals by line
live_by_line = {}
for visit in live_data.get('visits', {}).get('${STOP}', []):
    line = visit.get('line_name', '')
    if requested and line not in requested:
        continue
    eta_str = visit.get('eta', '')
    if not eta_str:
        continue
    eta_dt = datetime.fromisoformat(eta_str)
    mins = max(0, int((eta_dt - now).total_seconds() / 60))

    dest = ''
    si2 = visit.get('static_info', {}).get('route', {})
    if si2:
        hs = si2.get('headsign', {})
        if isinstance(hs, dict):
            dest = hs.get('HE', hs.get('EN', ''))
        elif isinstance(hs, str):
            dest = hs

    if line not in live_by_line:
        live_by_line[line] = {'destination': dest, 'arrivals': []}
    live_by_line[line]['arrivals'].append({
        'eta': mins,
        'etaTime': eta_dt.strftime('%H:%M'),
        'realtime': True
    })

# Gather scheduled arrivals by line
sched_by_line = {}
for entry in sched_data:
    line = entry.get('line', '')
    for item in entry.get('data', []):
        at = item.get('arrival_time', '')
        if not at:
            continue
        arr_dt = datetime.fromisoformat(at).astimezone(tz_il)
        mins = max(0, int((arr_dt - now).total_seconds() / 60))
        dest = item.get('gtfs_route__route_long_name', '')
        if line not in sched_by_line:
            sched_by_line[line] = {'destination': dest, 'arrivals': []}
        sched_by_line[line]['arrivals'].append({
            'eta': mins,
            'etaTime': arr_dt.strftime('%H:%M'),
            'realtime': False
        })

# Merge: prefer live, fill remaining slots with schedule
lines_out = []
order = requested if requested else sorted(set(list(live_by_line.keys()) + list(sched_by_line.keys())))
for line in order:
    live = live_by_line.get(line, {})
    sched = sched_by_line.get(line, {})
    dest = live.get('destination', '') or sched.get('destination', '')

    live_arrs = sorted(live.get('arrivals', []), key=lambda a: a['eta'])
    sched_arrs = sorted(sched.get('arrivals', []), key=lambda a: a['eta'])

    # Take live arrivals first, then fill with schedule up to 3
    merged = live_arrs[:3]
    live_times = set(a['etaTime'] for a in merged)
    for sa in sched_arrs:
        if len(merged) >= 3:
            break
        if sa['etaTime'] not in live_times:
            merged.append(sa)

    merged.sort(key=lambda a: a['eta'])
    lines_out.append({
        'line': line,
        'destination': dest,
        'active': len(merged) > 0,
        'arrivals': merged[:3]
    })

print(json.dumps({'lines': lines_out, 'stopName': stop_name}))
"
