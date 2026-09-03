#!/usr/bin/env bash
# Construye el .zip estándar del Lambda a lambda/dist/agent.zip.
# El `terraform apply` NO necesita esto (lo hace `data "archive_file"`); es para
# inspección o para desplegar a mano.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/lambda/src"
OUT="$ROOT/lambda/dist/agent.zip"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

# Empaqueta el contenido de lambda/src/ (queda `agent/` en la raíz del zip),
# excluyendo bytecode.
( cd "$SRC" && zip -r -X "$OUT" . -x '*/__pycache__/*' '*.pyc' >/dev/null )

echo "OK  $OUT"
unzip -l "$OUT"
