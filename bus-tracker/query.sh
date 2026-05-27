#!/usr/bin/env bash
# Query curlbus API for bus arrivals at a stop.
# Usage: query.sh <stop_code> [line1,line2,line3]
# Output: JSON grouped by line, always including all requested lines.

set -euo pipefail

STOP="${1:?stop code required}"
FILTER="${2:-}"

RAW=$(curl -sf -m 10 "https://curlbus.app/${STOP}" -H 'Accept: application/json' 2>/dev/null) || {
  echo '{"lines":[],"stopName":"","error":"fetch failed"}'
  exit 0
}

python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta
from collections import OrderedDict

data = json.loads(sys.stdin.read())
tz = timezone(timedelta(hours=3))
now = datetime.now(tz)

requested = [l.strip() for l in '${FILTER}'.split(',') if l.strip()] if '${FILTER}' else []

stop_name = ''
si = data.get('stop_info', {})
if si:
    names = si.get('name', {})
    stop_name = names.get('HE', names.get('EN', ''))

# Group arrivals by line
by_line = {}
for visit in data.get('visits', {}).get('${STOP}', []):
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
        dn = si2.get('destination', {}).get('name', {})
        dest = dn.get('HE', dn.get('EN', ''))
        hs = si2.get('headsign', {})
        if isinstance(hs, dict):
            dest = hs.get('HE', hs.get('EN', dest))
        elif isinstance(hs, str):
            dest = hs or dest

    has_location = bool(visit.get('location', {}).get('lat'))

    if line not in by_line:
        by_line[line] = {'destination': dest, 'arrivals': []}

    by_line[line]['arrivals'].append({
        'eta': mins,
        'etaTime': eta_dt.strftime('%H:%M'),
        'realtime': has_location
    })

# Sort arrivals within each line and limit to 3
for line_data in by_line.values():
    line_data['arrivals'].sort(key=lambda a: a['eta'])
    line_data['arrivals'] = line_data['arrivals'][:3]

# Build output in requested order, always include all lines
lines = []
order = requested if requested else sorted(by_line.keys())
for line in order:
    info = by_line.get(line, {})
    lines.append({
        'line': line,
        'destination': info.get('destination', ''),
        'active': line in by_line,
        'arrivals': info.get('arrivals', [])
    })

print(json.dumps({'lines': lines, 'stopName': stop_name}))
" <<< "$RAW"
