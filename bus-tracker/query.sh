#!/usr/bin/env bash
# Query bus arrivals for two linked stops with connection analysis.
# Uses the official MOT bus.gov.il API for real-time data.
# Usage: query.sh <stop1> <lines1> <stop2> <lines2>
# Output: JSON with both stops + transfer connections.

set -euo pipefail

STOP1="${1:?stop1 required}"
LINES1="${2:-}"
STOP2="${3:-}"
LINES2="${4:-}"

API="https://bus.gov.il/WebApi/api/passengerinfo/GetRealtimeBusLineListByBustop"

# Fetch stops in parallel
TMP1=$(mktemp)
TMP2=$(mktemp)
trap 'rm -f "$TMP1" "$TMP2"' EXIT

curl -sf -m 10 "${API}/${STOP1}/he/false" > "$TMP1" 2>/dev/null &
PID1=$!

if [ -n "$STOP2" ]; then
  curl -sf -m 10 "${API}/${STOP2}/he/false" > "$TMP2" 2>/dev/null &
  PID2=$!
else
  echo '[]' > "$TMP2"
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
            data = json.load(f)
            return data if isinstance(data, list) else []
    except:
        return []

def get_stop_name(data):
    if data:
        return data[0].get('BusstopHebrewName', '')
    return ''

def parse_entries(data, filter_lines):
    requested = set(filter_lines.split(',')) if filter_lines else set()
    by_line = {}

    for entry in data:
        line = str(entry.get('Shilut', ''))
        if requested and line not in requested:
            continue

        arrivals_mins = entry.get('MinutesToArrivalList', [])
        realtime = entry.get('ResponseSuccesed', False)

        dest = entry.get('Description', '')
        # Extract destination part after ' - '
        if ' - ' in dest:
            dest = dest.split(' - ', 1)[1]

        arrivals = []
        for mins in arrivals_mins[:3]:
            eta_dt = now + timedelta(minutes=mins)
            arrivals.append({
                'eta': mins,
                'etaTime': eta_dt.strftime('%H:%M'),
                'realtime': realtime,
                'vehicleRef': ''
            })

        by_line[line] = {
            'destination': dest,
            'arrivals': arrivals
        }

    return by_line

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

by_line1 = parse_entries(data1, lines1_filter)
by_line2 = parse_entries(data2, lines2_filter) if '${STOP2}' else {}

order1 = [l.strip() for l in lines1_filter.split(',') if l.strip()] if lines1_filter else []
order2 = [l.strip() for l in lines2_filter.split(',') if l.strip()] if lines2_filter else []

# Connection analysis: find shared lines between stops
connections = []
direct_lines = set(order1) if order1 else set(by_line1.keys())
if by_line1 and by_line2:
    for line, ld1 in by_line1.items():
        if not ld1['arrivals']:
            continue
        # Estimate travel time: if same line serves both stops, use ETA difference
        if line in by_line2 and by_line2[line]['arrivals']:
            board_eta = ld1['arrivals'][0]['eta']
            arrive_eta = by_line2[line]['arrivals'][0]['eta']
            travel = arrive_eta - board_eta
            if travel > 0:
                arrival_at_stop2 = board_eta + travel
                catchable = []
                for cline, cld in by_line2.items():
                    if cline in direct_lines:
                        continue
                    for arr in cld['arrivals']:
                        if arr['eta'] >= arrival_at_stop2 + 1:
                            catchable.append({
                                'line': cline,
                                'eta': arr['eta'],
                                'etaTime': arr['etaTime'],
                                'wait': arr['eta'] - arrival_at_stop2
                            })
                            break
                catchable.sort(key=lambda c: c['eta'])
                connections.append({
                    'boardLine': line,
                    'boardEta': board_eta,
                    'boardTime': ld1['arrivals'][0]['etaTime'],
                    'travelMins': travel,
                    'arriveStop2': arrival_at_stop2,
                    'catchable': catchable
                })

connections.sort(key=lambda c: c['boardEta'])

result = {
    'stop1': {
        'code': '${STOP1}',
        'name': get_stop_name(data1),
        'lines': build_lines(by_line1, order1)
    },
    'stop2': {
        'code': '${STOP2}',
        'name': get_stop_name(data2),
        'lines': build_lines(by_line2, order2)
    } if '${STOP2}' else None,
    'connections': connections
}

print(json.dumps(result))
"
