#!/usr/bin/env bash
# Query bus arrivals for two linked stops with connection analysis.
# Usage: query.sh <stop1> <lines1> <stop2> <lines2>
# Output: JSON with both stops + transfer connections.

set -euo pipefail

STOP1="${1:?stop1 required}"
LINES1="${2:-}"
STOP2="${3:-}"
LINES2="${4:-}"

# Fetch stops in parallel
TMP1=$(mktemp)
TMP2=$(mktemp)
trap 'rm -f "$TMP1" "$TMP2"' EXIT

curl -sf -m 10 "https://curlbus.app/${STOP1}" -H 'Accept: application/json' > "$TMP1" 2>/dev/null &
PID1=$!

if [ -n "$STOP2" ]; then
  curl -sf -m 10 "https://curlbus.app/${STOP2}" -H 'Accept: application/json' > "$TMP2" 2>/dev/null &
  PID2=$!
else
  echo '{}' > "$TMP2"
  PID2=""
fi

wait "$PID1" 2>/dev/null || true
[ -n "$PID2" ] && wait "$PID2" 2>/dev/null || true

python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta

tz_il = timezone(timedelta(hours=3))
now = datetime.now(tz_il)

def load_file(path):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return {}

def get_stop_name(data, stop):
    si = data.get('stop_info', {})
    if si:
        names = si.get('name', {})
        return names.get('HE', names.get('EN', ''))
    return ''

def parse_visits(data, stop, filter_lines):
    requested = set(filter_lines.split(',')) if filter_lines else set()
    by_line = {}
    vehicles = {}  # vehicle_ref -> {line, eta_min, eta_dt}

    for visit in data.get('visits', {}).get(stop, []):
        line = visit.get('line_name', '')
        if requested and line not in requested:
            continue
        eta_str = visit.get('eta', '')
        if not eta_str:
            continue
        eta_dt = datetime.fromisoformat(eta_str)
        mins = max(0, int((eta_dt - now).total_seconds() / 60))
        has_loc = bool(visit.get('location', {}).get('lat'))
        vref = visit.get('vehicle_ref', '')

        dest = ''
        si = visit.get('static_info', {}).get('route', {})
        if si:
            hs = si.get('headsign', {})
            if isinstance(hs, dict):
                dest = hs.get('HE', hs.get('EN', ''))
            elif isinstance(hs, str):
                dest = hs

        if line not in by_line:
            by_line[line] = {'destination': dest, 'arrivals': []}
        by_line[line]['arrivals'].append({
            'eta': mins, 'etaTime': eta_dt.strftime('%H:%M'),
            'realtime': has_loc, 'vehicleRef': vref
        })

        if vref:
            vehicles[vref] = {'line': line, 'eta': mins, 'etaTime': eta_dt.strftime('%H:%M')}

    # Sort and limit
    for ld in by_line.values():
        ld['arrivals'].sort(key=lambda a: a['eta'])
        ld['arrivals'] = ld['arrivals'][:3]

    return by_line, vehicles

def build_lines(by_line, requested_order):
    order = requested_order if requested_order else sorted(by_line.keys())
    lines = []
    for line in order:
        info = by_line.get(line, {})
        lines.append({
            'line': line,
            'destination': info.get('destination', ''),
            'active': line in by_line,
            'arrivals': info.get('arrivals', [])
        })
    return lines

# Parse both stops
data1 = load_file('$TMP1')
data2 = load_file('$TMP2')

lines1_filter = '${LINES1}'
lines2_filter = '${LINES2}'

by_line1, vehicles1 = parse_visits(data1, '${STOP1}', lines1_filter)
by_line2, vehicles2 = parse_visits(data2, '${STOP2}', lines2_filter) if '${STOP2}' else ({}, {})

order1 = [l.strip() for l in lines1_filter.split(',') if l.strip()] if lines1_filter else []
order2 = [l.strip() for l in lines2_filter.split(',') if l.strip()] if lines2_filter else []

# Connection analysis: match vehicles across both stops
connections = []
if vehicles1 and vehicles2:
    for vref, v1 in vehicles1.items():
        if vref in vehicles2:
            v2 = vehicles2[vref]
            travel = v2['eta'] - v1['eta']
            if travel > 0:
                # Find catchable buses at stop 2 after arrival
                arrival_at_stop2 = v1['eta'] + travel
                catchable = []
                for line, ld in by_line2.items():
                    if line == v1['line']:
                        continue  # skip same line
                    for arr in ld['arrivals']:
                        if arr['eta'] >= arrival_at_stop2 + 1:  # 1 min buffer
                            catchable.append({
                                'line': line,
                                'eta': arr['eta'],
                                'etaTime': arr['etaTime'],
                                'wait': arr['eta'] - arrival_at_stop2
                            })
                            break

                catchable.sort(key=lambda c: c['eta'])
                connections.append({
                    'boardLine': v1['line'],
                    'boardEta': v1['eta'],
                    'boardTime': v1['etaTime'],
                    'travelMins': travel,
                    'arriveStop2': arrival_at_stop2,
                    'catchable': catchable
                })

connections.sort(key=lambda c: c['boardEta'])

result = {
    'stop1': {
        'code': '${STOP1}',
        'name': get_stop_name(data1, '${STOP1}'),
        'lines': build_lines(by_line1, order1)
    },
    'stop2': {
        'code': '${STOP2}',
        'name': get_stop_name(data2, '${STOP2}'),
        'lines': build_lines(by_line2, order2)
    } if '${STOP2}' else None,
    'connections': connections
}

print(json.dumps(result))
"
