#!/usr/bin/env bash
# start-demo.sh — Arranca el demo web de Nimble.
# Equivalente al Start-Demo.ps1 del repo Windows.
#
# USO:
#   ./start-demo.sh [PUERTO]      # default 8080
#
# REQUISITOS:
#   - Ollama corriendo con nimble:latest descargado
#   - Python 3 instalado
#
# DETENER:
#   Ctrl+C en la terminal

set -e

PORT="${1:-8080}"

echo "=== Nimble Decision Layer — Demo Web ==="
echo

# Verificar Ollama
if ! command -v ollama >/dev/null 2>&1; then
  echo "❌ Ollama no está instalado. Instálalo desde https://ollama.com/download"
  exit 1
fi

# Verificar servidor
if ! curl -s -m 2 http://localhost:11434/api/version >/dev/null; then
  echo "❌ Ollama no responde en localhost:11434."
  echo "   Arranca con: ollama serve"
  echo "   O abre la app de Ollama."
  exit 1
fi

# Verificar modelo
if ! ollama list | grep -q "nimble"; then
  echo "⚠️  nimble no está descargado. Ejecutando: ollama pull nimble:latest"
  ollama pull nimble:latest
fi

# Verificar que existe el directorio
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/app/index.html" ]; then
  echo "❌ No se encuentra index.html en $SCRIPT_DIR"
  exit 1
fi

# Verificar/decargar decisions.json
if [ ! -f "$SCRIPT_DIR/decisions.json" ]; then
  echo "📥 Descargando decisions.json del repo oficial..."
  curl -sL "https://raw.githubusercontent.com/RicardoBertran/ollama-nimble-decision-layer/main/app/decisions.json" \
    -o "$SCRIPT_DIR/decisions.json"
fi

# Ajustar CORS si el puerto es distinto a 8080
EXPECTED_ORIGIN="http://localhost:$PORT"
echo "🔍 Verificando CORS en Ollama para $EXPECTED_ORIGIN..."
CORS_TEST=$(curl -sI -m 2 -X OPTIONS http://localhost:11434/v1/systemone \
  -H "Origin: $EXPECTED_ORIGIN" \
  -H "Access-Control-Request-Method: POST" 2>/dev/null | \
  grep -i "access-control-allow-origin:" | tr -d '\r' || true)

if ! echo "$CORS_TEST" | grep -q "$EXPECTED_ORIGIN"; then
  echo "⚠️  CORS no configurado para $EXPECTED_ORIGIN."
  echo "   Si abres el demo en otro puerto, añade este origin a Ollama:"
  echo "   OLLAMA_ORIGINS=\"$EXPECTED_ORIGIN\" ollama serve"
  echo
fi

# Servir
echo "✅ Sirviendo demo en: $EXPECTED_ORIGIN"
echo "   Abre esa URL en tu navegador."
echo "   Ctrl+C para detener."
echo

cd "$SCRIPT_DIR"
python3 -m http.server "$PORT" --bind 127.0.0.1