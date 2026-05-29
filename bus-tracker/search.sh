#!/usr/bin/env bash
# Search for bus stops near a location.
# Uses Nominatim for geocoding, then bus.gov.il for nearby stops.
# Usage: search.sh "location name" [radius_meters]
# Output: JSON array of {code, name}

set -euo pipefail

QUERY="${1:?search query required}"
RADIUS="${2:-500}"

TMP_GEO=$(mktemp)
TMP_STOPS=$(mktemp)
trap 'rm -f "$TMP_GEO" "$TMP_STOPS"' EXIT

ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")

curl -sf -m 10 \
  -H "User-Agent: NoctaliaBusTracker/1.0" \
  "https://nominatim.openstreetmap.org/search?q=${ENCODED}&format=json&limit=1&accept-language=he&countrycodes=il" \
  > "$TMP_GEO" 2>/dev/null

COORDS=$(python3 -c "
import json
with open('$TMP_GEO') as f:
    data = json.load(f)
if data:
    print(data[0]['lat'] + ',' + data[0]['lon'])
else:
    print('')
")

if [ -z "$COORDS" ]; then
  echo "[]"
  exit 0
fi

LAT="${COORDS%,*}"
LON="${COORDS#*,}"

curl -sf -m 10 \
  "https://bus.gov.il/WebApi/api/passengerinfo/GetBusstopListByRadius/1/${LAT}/${LON}/${RADIUS}/he/false" \
  > "$TMP_STOPS" 2>/dev/null

python3 -c "
import json

with open('$TMP_STOPS') as f:
    try:
        data = json.load(f)
    except:
        data = []

if not isinstance(data, list):
    data = []

def get_name(s):
    for k in ['BusstopHebrewName', 'Busstopnamehe', 'BusStopName', 'StopName', 'Name', 'name']:
        if k in s and s[k]:
            return str(s[k])
    return ''

def get_code(s):
    for k in ['StopCode', 'BusStopId', 'Makat', 'Id', 'StopId']:
        if k in s and s[k]:
            return str(s[k])
    return ''

results = []
seen = set()
for stop in data:
    code = get_code(stop)
    name = get_name(stop)
    if code and code not in seen:
        seen.add(code)
        results.append({'code': code, 'name': name})

print(json.dumps(results, ensure_ascii=False))
"
