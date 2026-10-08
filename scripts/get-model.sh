#!/usr/bin/env bash
# get-model.sh — Descarga Nimble 9B en Ollama.
# Equivalente al Get-Model.ps1 del repo original.
#
# USO:
#   ./get-model.sh                    # descarga nimble:latest
#   ./get-model.sh nimble:7b          # versión específica

set -e

MODEL="${1:-nimble:latest}"

echo "=== Descarga del modelo $MODEL ==="
echo

# Verificar Ollama instalado
if ! command -v ollama >/dev/null 2>&1; then
  echo "❌ Ollama no instalado."
  exit 1
fi

# Verificar servidor
if ! curl -s -m 2 http://localhost:11434/api/version >/dev/null 2>&1; then
  echo "❌ Ollama no responde en localhost:11434."
  echo "   Arranca primero: ./start-ollama.sh (en otra terminal)"
  exit 1
fi

# Verificar versión mínima (0.35.1 para /v1/systemone)
OLLAMA_VERSION=$(curl -s http://localhost:11434/api/version 2>/dev/null | \
  python3 -c "import json,sys; print(json.load(sys.stdin).get('version','0.0.0'))" 2>/dev/null || \
  echo "0.0.0")

MIN_VERSION="0.35.1"
if [ "$(printf '%s\n' "$MIN_VERSION" "$OLLAMA_VERSION" | sort -V | head -1)" != "$MIN_VERSION" ]; then
  echo "⚠️  Ollama $OLLAMA_VERSION < $MIN_VERSION (mínimo para /v1/systemone)"
  echo "   brew upgrade ollama"
  echo
fi

echo "Versión del servidor: $OLLAMA_VERSION"
echo

# Comprobar si ya está descargado
if ollama list 2>/dev/null | awk '{print $1}' | grep -q "^${MODEL%%:*}$"; then
  if ollama list 2>/dev/null | grep -q "^$MODEL"; then
    echo "✅ $MODEL ya está descargado."
    echo
    ollama list
    exit 0
  fi
fi

# Descargar
echo "Descargando $MODEL (puede tardar varios minutos)..."
echo
ollama pull "$MODEL"

echo
echo "=== Modelos instalados ==="
ollama list