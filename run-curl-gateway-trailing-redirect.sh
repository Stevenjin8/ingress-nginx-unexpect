#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${GATEWAY_ADDR:-172.19.100.202}}"
if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://$TARGET"
fi

echo "Running gateway-trailing curl demos against: ${TARGET}"

echo
echo "=== Prefix path /bytes/ (request /bytes) ==="
echo "+ curl -vsS -HHost:gw-trailing.example.com ${TARGET}/bytes"
curl -vsS -H "Host:gw-trailing.example.com" "${TARGET}/bytes"

echo
echo "=== Prefix path /bytes/ (request /bytes/) ==="
echo "+ curl -vsS -HHost:gw-trailing.example.com ${TARGET}/bytes/"
curl -vsS -H "Host:gw-trailing.example.com" "${TARGET}/bytes/"

echo
echo "=== Exact /ip/ (request /ip) ==="
echo "+ curl -vsS -HHost:gw-trailing.example.com ${TARGET}/ip"
curl -vsS -H "Host:gw-trailing.example.com" "${TARGET}/ip"

echo
echo "=== Exact /ip/ (request /ip/) ==="
echo "+ curl -vsS -HHost:gw-trailing.example.com ${TARGET}/ip/"
curl -vsS -H "Host:gw-trailing.example.com" "${TARGET}/ip/"
