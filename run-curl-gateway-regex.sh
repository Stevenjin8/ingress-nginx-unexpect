#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${GATEWAY_ADDR:-172.19.100.202}}"
if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://$TARGET"
fi

echo "Running gateway-regex curl demos against: ${TARGET}"

echo
echo "=== Exact /UU does not match /uuid ==="
echo "+ curl -vsS -HHost:gw-regex.example.com ${TARGET}/uuid"
curl -vsS -H "Host:gw-regex.example.com" "${TARGET}/uuid"

echo
echo "=== Regex rule matches /status/200 ==="
echo "+ curl -vsS -HHost:gw-regex.example.com ${TARGET}/status/200"
curl -vsS -H "Host:gw-regex.example.com" "${TARGET}/status/200"

echo
echo "=== Exact /HEADE does not match /headers ==="
echo "+ curl -vsS -HHost:gw-regex.example.com ${TARGET}/headers"
curl -vsS -H "Host:gw-regex.example.com" "${TARGET}/headers"
