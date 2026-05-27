#!/usr/bin/env bash
# Query curlbus API for bus arrivals at a stop.
# Usage: query.sh <stop_code> [line1,line2,line3]
# Output: JSON with filtered arrivals sorted by ETA.

set -euo pipefail

STOP="${1:?stop code required}"
FILTER="${2:-}"

RAW=$(curl -sf -m 10 "https://curlbus.app/${STOP}" -H 'Accept: application/json' 2>/dev/null) || {
  echo '{"arrivals":[],"stopName":"","error":"fetch failed"}'
  exit 0
}

python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta

data = json.loads(sys.stdin.read())
tz = timezone(timedelta(hours=3))
now = datetime.now(tz)

filter_lines = set('${FILTER}'.split(',')) if '${FILTER}' else set()

stop_name = ''
si = data.get('stop_info', {})
if si:
    names = si.get('name', {})
    stop_name = names.get('HE', names.get('EN', ''))

arrivals = []
for visit in data.get('visits', {}).get('${STOP}', []):
    line = visit.get('line_name', '')
    if filter_lines and line not in filter_lines:
        continue

    eta_str = visit.get('eta', '')
    if not eta_str:
        continue

    eta_dt = datetime.fromisoformat(eta_str)
    mins = max(0, int((eta_dt - now).total_seconds() / 60))

    dest = ''
    si2 = visit.get('static_info', {}).get('route', {})
    if si2:
        dn = si2.get('destination', {}).get('name', {})
        dest = dn.get('HE', dn.get('EN', ''))
        hs = si2.get('headsign', {})
        if isinstance(hs, dict):
            dest = hs.get('HE', hs.get('EN', dest))
        elif isinstance(hs, str):
            dest = hs or dest

    has_location = bool(visit.get('location', {}).get('lat'))

    arrivals.append({
        'line': line,
        'destination': dest,
        'eta': mins,
        'etaTime': eta_dt.strftime('%H:%M'),
        'realtime': has_location,
        'vehicleRef': visit.get('vehicle_ref', '')
    })

arrivals.sort(key=lambda a: a['eta'])
print(json.dumps({'arrivals': arrivals, 'stopName': stop_name}))
" <<< "$RAW"
