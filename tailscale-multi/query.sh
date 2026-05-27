#!/usr/bin/env bash
# Auto-discover and query all tailscale instances.
# Finds tailscaled sockets under /run/, queries each, outputs JSON array.
# No arguments needed.

shopt -s nullglob

sockets=(/run/tailscale*/tailscaled.sock)

if [ ${#sockets[@]} -eq 0 ]; then
  printf '[]\n'
  exit 0
fi

printf '['
first=true
for sock in "${sockets[@]}"; do
  [ "$first" = true ] && first=false || printf ','
  status=$(timeout 3 tailscale --socket "$sock" status --json 2>/dev/null) || true
  [ -z "$status" ] && status='{}'
  # Use directory name as fallback label, strip "tailscale-dyn-" prefix
  label=$(basename "$(dirname "$sock")")
  label="${label#tailscale-dyn-}"
  printf '{"name":"%s","socket":"%s","data":%s}' "$label" "$sock" "$status"
done
printf ']\n'
