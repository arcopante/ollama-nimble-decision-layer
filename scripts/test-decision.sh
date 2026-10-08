#!/usr/bin/env bash
# test-decision.sh — Envía el ticket de ejemplo y las 10 preguntas a Ollama.
# Equivalente al Test-Decision.ps1 del repo original.
#
# USO:
#   ./test-decision.sh                    # 1 petición, modelo nimble:latest
#   ./test-decision.sh -m nimble:7b       # modelo distinto
#   ./test-decision.sh -r 3               # 3 peticiones (compara cold/warm)
#   ./test-decision.sh -t 0.4             # umbral 0.4
#
# SALIDA:
#   Para cada petición: tiempo, decisiones Sí/No según umbral.

set -e

MODEL="nimble:latest"
REPEAT=1
THRESHOLD=0.5
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DECISIONS_FILE="$PROJECT_DIR/decisions.json"
if [ ! -f "$DECISIONS_FILE" ] && [ -f "$PROJECT_DIR/app/decisions.json" ]; then
  DECISIONS_FILE="$PROJECT_DIR/app/decisions.json"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model)     MODEL="$2"; shift 2 ;;
    -r|--repeat)    REPEAT="$2"; shift 2 ;;
    -t|--threshold) THRESHOLD="$2"; shift 2 ;;
    -h|--help)
      echo "Uso: $0 [-m modelo] [-r repeticiones] [-t umbral]"
      exit 0 ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
done

# Verificar dependencias
if ! command -v curl >/dev/null 2>&1; then
  echo "❌ curl no instalado."; exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 no instalado."; exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq no instalado. La salida será menos formateada pero funciona."
  HAS_JQ=0
else
  HAS_JQ=1
fi

# Verificar servidor
if ! curl -s -m 2 http://localhost:11434/api/version >/dev/null 2>&1; then
  echo "❌ Ollama no responde en localhost:11434."
  echo "   Arranca primero: ./start-ollama.sh"
  exit 1
fi

# Verificar decisions.json
if [ ! -f "$DECISIONS_FILE" ]; then
  echo "❌ No se encuentra $DECISIONS_FILE"
  exit 1
fi

echo "=== Test del endpoint /v1/systemone ==="
echo "Modelo:     $MODEL"
echo "Repeticiones: $REPEAT"
echo "Umbral:     $THRESHOLD"
echo

# Construir payload con python (más fiable que jq para JSON complejo)
PAYLOAD=$(python3 -c "
import json, sys
with open('$DECISIONS_FILE') as f:
    config = json.load(f)
payload = {
    'model': '$MODEL',
    'state': config['ticket'],
    'questions': config['questions'],
    'keep_alive': '30m'
}
print(json.dumps(payload))
")

for ((i=1; i<=REPEAT; i++)); do
  echo "--- Petición $i de $REPEAT ---"

  START=$(python3 -c "import time; print(time.time())")
  RESPONSE=$(curl -s -m 300 -X POST http://localhost:11434/v1/systemone \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "$PAYLOAD")
  END=$(python3 -c "import time; print(time.time())")

  ELAPSED=$(python3 -c "print(f'{$END - $START:.2f}')")

  if [ -z "$RESPONSE" ]; then
    echo "❌ Sin respuesta"
    continue
  fi

  # Validar y mostrar
  echo "$RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f'❌ JSON inválido: {e}')
    sys.exit(1)

answers = data.get('answers', {})
if not answers:
    print(f'❌ Sin answers: {data}')
    sys.exit(1)

usage = data.get('usage', {})
print(f'Tiempo: {$ELAPSED}s | Input: {usage.get(\"input_tokens\",0)} tokens | Output: {usage.get(\"output_tokens\",0)} tokens')
print()
print(f'{\"Pregunta\":<32} {\"Valor\":>8}  {\"Decisión\":>8}')
print('-' * 60)
for key, ans in answers.items():
    if ans.get('type') != 'noul':
        print(f'❌ {key}: tipo inesperado {ans.get(\"type\")}')
        sys.exit(1)
    noul = ans.get('noul')
    if not isinstance(noul, (int, float)) or noul < 0 or noul > 1:
        print(f'❌ {key}: valor inválido {noul}')
        sys.exit(1)
    decision = 'SÍ' if noul >= $THRESHOLD else 'NO'
    print(f'{key:<32} {noul:>7.4f}  {decision:>8}')
"
  echo
done

echo "=== Test completado ==="