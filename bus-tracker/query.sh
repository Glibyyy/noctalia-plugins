#!/usr/bin/env bash
# Query bus arrivals for N linked stops with connection analysis.
# Uses the official MOT bus.gov.il API for real-time data.
# Usage: query.sh '<json>'
# Input JSON: {"stops": [{"code":"...", "lines":["..."]}, ...], "walkTime": 10}
# Output: JSON with all stops + transfer connections between consecutive pairs.

set -euo pipefail

INPUT="${1:?JSON input required}"

API="https://bus.gov.il/WebApi/api/passengerinfo/GetRealtimeBusLineListByBustop"

# Parse stop codes from input
STOP_CODES=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
for s in data.get('stops', []):
    print(s.get('code', ''))
" "$INPUT")

# Fetch all stops in parallel
TMPDIR_Q=$(mktemp -d)
trap 'rm -rf "$TMPDIR_Q"' EXIT

PIDS=()
IDX=0
while IFS= read -r code; do
  if [ -n "$code" ]; then
    curl -sf -m 10 "${API}/${code}/he/false" > "${TMPDIR_Q}/stop_${IDX}.json" 2>/dev/null &
    PIDS+=($!)
  else
    echo '[]' > "${TMPDIR_Q}/stop_${IDX}.json"
  fi
  IDX=$((IDX + 1))
done <<< "$STOP_CODES"

for pid in "${PIDS[@]}"; do
  wait "$pid" 2>/dev/null || true
done

python3 -c "
import json, sys, os
from datetime import datetime, timezone, timedelta

tz_il = timezone(timedelta(hours=3))
now = datetime.now(tz_il)

input_data = json.loads(sys.argv[1])
stops_config = input_data.get('stops', [])
walk_time = input_data.get('walkTime', 5)
tmpdir = sys.argv[2]

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
    requested = set(filter_lines) if filter_lines else set()
    by_line = {}

    for entry in data:
        line = str(entry.get('Shilut', ''))
        if requested and line not in requested:
            continue

        arrivals_mins = entry.get('MinutesToArrivalList', [])
        realtime = entry.get('ResponseSuccesed', False)

        dest = entry.get('Description', '')
        if ' - ' in dest:
            dest = dest.split(' - ', 1)[1]

        arrivals = []
        for mins in arrivals_mins[:3]:
            eta_dt = now + timedelta(minutes=mins)
            arrivals.append({
                'eta': mins,
                'etaTime': eta_dt.strftime('%H:%M'),
                'realtime': realtime,
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

# Parse all stops
all_stops = []
all_by_line = []

for i, sc in enumerate(stops_config):
    data = load_file(os.path.join(tmpdir, f'stop_{i}.json'))
    filter_lines = sc.get('lines', [])
    by_line = parse_entries(data, filter_lines)
    order = filter_lines if filter_lines else []

    all_stops.append({
        'code': sc.get('code', ''),
        'name': get_stop_name(data) or sc.get('name', ''),
        'lines': build_lines(by_line, order)
    })
    all_by_line.append(by_line)

# Connection analysis between consecutive stop pairs
connections = []

for pair_idx in range(len(all_by_line) - 1):
    by_line_a = all_by_line[pair_idx]
    by_line_b = all_by_line[pair_idx + 1]
    sc_a = stops_config[pair_idx]
    sc_b = stops_config[pair_idx + 1]

    direct_lines_a = set(sc_a.get('lines', [])) if sc_a.get('lines') else set(by_line_a.keys())

    for line, ld_a in by_line_a.items():
        if not ld_a['arrivals']:
            continue
        if line in by_line_b and by_line_b[line]['arrivals']:
            board_eta = ld_a['arrivals'][0]['eta']
            arrive_eta = by_line_b[line]['arrivals'][0]['eta']
            travel = arrive_eta - board_eta
            if travel > 0:
                arrival_at_b = board_eta + travel
                catchable = []
                for cline, cld in by_line_b.items():
                    if cline in direct_lines_a:
                        continue
                    for arr in cld['arrivals']:
                        if arr['eta'] >= arrival_at_b + walk_time:
                            catchable.append({
                                'line': cline,
                                'eta': arr['eta'],
                                'etaTime': arr['etaTime'],
                                'wait': arr['eta'] - arrival_at_b
                            })
                            break
                catchable.sort(key=lambda c: c['eta'])
                connections.append({
                    'fromStop': pair_idx,
                    'toStop': pair_idx + 1,
                    'boardLine': line,
                    'boardEta': board_eta,
                    'boardTime': ld_a['arrivals'][0]['etaTime'],
                    'travelMins': travel,
                    'arriveStop': arrival_at_b,
                    'catchable': catchable
                })

connections.sort(key=lambda c: c['boardEta'])

result = {
    'stops': all_stops,
    'connections': connections
}

print(json.dumps(result, ensure_ascii=False))
" "$INPUT" "$TMPDIR_Q"
