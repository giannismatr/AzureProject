#!/usr/bin/env bash
set -euo pipefail

# Usage: FUNC_URL=https://<your-func>.azurewebsites.net FUNC_KEY=<key> ./scripts/test.sh

FUNC_URL="${FUNC_URL:?Set FUNC_URL to your Function App base URL}"
FUNC_KEY="${FUNC_KEY:?Set FUNC_KEY to your Function App host key}"
BASE="$FUNC_URL/api"

echo "==> Testing Zero Trust demo endpoints"
echo ""

echo "[1] Health check"
curl -sf "$BASE/health?code=$FUNC_KEY" | python3 -m json.tool
echo ""

echo "[2] List blobs (expects 403 if container does not exist yet)"
curl -sf "$BASE/blobs?container=demo&code=$FUNC_KEY" | python3 -m json.tool || echo "    Got expected error"
echo ""

echo "[3] Upload a blob via Managed Identity"
curl -sf -X POST \
  "$BASE/blobs/hello.txt?container=demo&code=$FUNC_KEY" \
  -H "Content-Type: text/plain" \
  -d "Hello from Zero Trust demo!" | python3 -m json.tool
echo ""

echo "[4] List blobs (should now show hello.txt)"
curl -sf "$BASE/blobs?container=demo&code=$FUNC_KEY" | python3 -m json.tool
echo ""

echo "All tests done."
