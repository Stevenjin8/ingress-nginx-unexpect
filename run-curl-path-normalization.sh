#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${INGRESS_ADDR:-172.19.100.200}}"
if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://$TARGET"
fi

echo "Running path-normalization curl demos against: ${TARGET}"

echo
echo "=== Baseline exact path (/status/200) ==="
echo "+ curl -vsS -HHost:normalize.example.com ${TARGET}/status/200"
curl -vsS -H "Host:normalize.example.com" "${TARGET}/status/200"

echo
echo "=== Double slash preserved with --path-as-is (/status//200) ==="
echo "+ curl -vsS --path-as-is -HHost:normalize.example.com ${TARGET}/status//200"
curl -vsS --path-as-is -H "Host:normalize.example.com" "${TARGET}/status//200"

echo
echo "=== Dot-segment preserved with --path-as-is (/status/../status/200) ==="
echo "+ curl -vsS --path-as-is -HHost:normalize.example.com ${TARGET}/status/../status/200"
curl -vsS --path-as-is -H "Host:normalize.example.com" "${TARGET}/status/../status/200"

echo
echo "=== Follow normalization redirect from double slash ==="
echo "+ curl -vsS -L --path-as-is -HHost:normalize.example.com ${TARGET}/status//200"
curl -vsS -L --path-as-is -H "Host:normalize.example.com" "${TARGET}/status//200"

echo
echo "=== Encoded dot-segment is not normalized (/status/%2E%2E/status/200) ==="
echo "+ curl -vsS --path-as-is -HHost:normalize.example.com ${TARGET}/status/%2E%2E/status/200"
curl -vsS --path-as-is -H "Host:normalize.example.com" "${TARGET}/status/%2E%2E/status/200"
