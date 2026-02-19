#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${GATEWAY_ADDR:-172.19.100.202}}"
if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://$TARGET"
fi

echo "Running gateway-path-normalization curl demos against: ${TARGET}"

echo
echo "=== Baseline exact path (/status/200) ==="
echo "+ curl -vsS -HHost:gw-normalize.example.com ${TARGET}/status/200"
curl -vsS -H "Host:gw-normalize.example.com" "${TARGET}/status/200"

echo
echo "=== Double slash with --path-as-is (/status//200) ==="
echo "+ curl -vsS --path-as-is -HHost:gw-normalize.example.com ${TARGET}/status//200"
curl -vsS --path-as-is -H "Host:gw-normalize.example.com" "${TARGET}/status//200"

echo
echo "=== Dot-segment with --path-as-is (/status/../status/200) ==="
echo "+ curl -vsS --path-as-is -HHost:gw-normalize.example.com ${TARGET}/status/../status/200"
curl -vsS --path-as-is -H "Host:gw-normalize.example.com" "${TARGET}/status/../status/200"

echo
echo "=== Encoded dot-segment with --path-as-is (/status/%2E%2E/status/200) ==="
echo "+ curl -vsS --path-as-is -HHost:gw-normalize.example.com ${TARGET}/status/%2E%2E/status/200"
curl -vsS --path-as-is -H "Host:gw-normalize.example.com" "${TARGET}/status/%2E%2E/status/200"
