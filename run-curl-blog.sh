#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${INGRESS_ADDR:-172.19.100.200}}"
if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://$TARGET"
fi

echo "Running blog.md curl demos against: ${TARGET}"

echo
echo '=== Regex matching is prefix and case insensitive ==='
echo "+ curl -isS -HHost:regex-match.example.com ${TARGET}/uuid"
curl -isS -H "Host:regex-match.example.com" "${TARGET}/uuid"

echo
echo '=== Regex applies across ingresses for same host ==='
echo "+ curl -isS -HHost:regex-match.example.com ${TARGET}/headers"
curl -isS -H "Host:regex-match.example.com" "${TARGET}/headers"

echo
echo '=== Rewrite target implies regex ==='
echo "+ curl -isS -HHost:rewrite-target.example.com ${TARGET}/ABCdef"
curl -isS -H "Host:rewrite-target.example.com" "${TARGET}/ABCdef"

echo
echo '=== Second headers call from blog ==='
echo "+ curl -isS -HHost:regex-match.example.com ${TARGET}/headers"
curl -isS -H "Host:regex-match.example.com" "${TARGET}/headers"

echo
echo '=== Missing trailing slash redirects ==='
echo "+ curl -isS -HHost:trailing-slash.example.com ${TARGET}/header"
curl -isS -H "Host:trailing-slash.example.com" "${TARGET}/header"

echo
echo '=== Path normalization baseline ==='
echo "+ curl -sS -HHost:path-normalization.example.com ${TARGET}/uuid"
curl -sS -H "Host:path-normalization.example.com" "${TARGET}/uuid"

echo
echo '=== Path normalization dot segments ==='
echo "+ curl -sS -HHost:path-normalization.example.com ${TARGET}/ip/abc/../../uuid"
curl -sS -H "Host:path-normalization.example.com" "${TARGET}/ip/abc/../../uuid"

echo
echo '=== Path normalization multiple slashes ==='
echo "+ curl -sSi -HHost:path-normalization.example.com ${TARGET}////uuid"
curl -sSi -H "Host:path-normalization.example.com" "${TARGET}////uuid"
