#!/usr/bin/env bash
# Invoca la función Lambda del agente con un evento de ejemplo y muestra la
# respuesta. Uso:  AWS_PROFILE=personal scripts/invoke-lambda.sh ["pregunta"]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="$ROOT/terraform/environments/dev"
EVENT_FILE="$ROOT/lambda/tests/events/sample-question.json"

FN="$(terraform -chdir="$DEV" output -raw agent_function_name)"

# Permite pasar una pregunta como argumento; si no, usa el evento de ejemplo.
if [ $# -ge 1 ]; then
  PAYLOAD="$(printf '{"question": %s}' "$(printf '%s' "$1" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')")"
else
  PAYLOAD="$(cat "$EVENT_FILE")"
fi

OUT="$(mktemp)"
aws lambda invoke \
  --function-name "$FN" \
  --cli-binary-format raw-in-base64-out \
  --payload "$PAYLOAD" \
  "$OUT" >/dev/null

python3 -m json.tool < "$OUT"
rm -f "$OUT"
