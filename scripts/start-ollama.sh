#!/usr/bin/env bash
# start-ollama.sh — Arranca Ollama con la configuración óptima para Nimble.
# Equivalente al Start-Ollama.ps1 del repo original (PowerShell).
# Adaptación multiplataforma. Sin selección de GPU (drivers del sistema).
#
# USO:
#   ./start-ollama.sh                    # puerto 11434, keep-alive 30m
#   ./start-ollama.sh --keep-alive 1h    # modelo permanece 1h en RAM
#   ./start-ollama.sh --demo-port 8081   # configura CORS para otro puerto demo
#
# REQUISITOS:
#   - Ollama instalado (brew install ollama)
#   - macOS, Linux o WSL

set -e

KEEP_ALIVE="30m"
DEMO_PORT=8080
EXTRA_ORIGINS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-alive)  KEEP_ALIVE="$2"; shift 2 ;;
    --demo-port)   DEMO_PORT="$2"; shift 2 ;;
    --origin)      EXTRA_ORIGINS="$EXTRA_ORIGINS,$2"; shift 2 ;;
    -h|--help)
      echo "Uso: $0 [--keep-alive 30m] [--demo-port 8080] [--origin http://localhost:XXXX]"
      exit 0
      ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
done

echo "=== Arranque de Ollama para Nimble ==="
echo

# Verificar binario
if ! command -v ollama >/dev/null 2>&1; then
  echo "❌ Ollama no instalado."
  echo "   Instala con: brew install ollama"
  echo "   O descarga desde: https://ollama.com/download"
  exit 1
fi

# Verificar versión (mínimo 0.35.1)
OLLAMA_VERSION=$(ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
MIN_VERSION="0.35.1"

if [ "$(printf '%s\n' "$MIN_VERSION" "$OLLAMA_VERSION" | sort -V | head -1)" != "$MIN_VERSION" ]; then
  echo "⚠️  Versión $OLLAMA_VERSION < $MIN_VERSION. Recomendado actualizar."
  echo "   brew upgrade ollama"
fi

echo "Versión Ollama: $OLLAMA_VERSION"

# Verificar puerto libre
if lsof -i :11434 >/dev/null 2>&1; then
  echo
  echo "⚠️  El puerto 11434 ya está ocupado."
  echo "   Si es otra instancia de Ollama, ciérrala primero:"
  echo "   pkill ollama"
  echo "   O desde la app: Salir de Ollama."
  echo
  read -p "¿Continuar igualmente? (s/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    exit 1
  fi
fi

# Configurar entorno
export OLLAMA_HOST="127.0.0.1:11434"
export OLLAMA_ORIGINS="http://localhost:$DEMO_PORT,http://127.0.0.1:$DEMO_PORT$EXTRA_ORIGINS"
export OLLAMA_KEEP_ALIVE="$KEEP_ALIVE"
export OLLAMA_NO_CLOUD=1

# Detección básica de plataforma (informativa, Ollama decide el backend)
case "$(uname -s)" in
  Darwin)   echo "Plataforma: macOS" ;;
  Linux)    echo "Plataforma: Linux"  ;;
  MINGW*|MSYS*|CYGWIN*) echo "Plataforma: Windows (WSL/Git Bash)" ;;
  *)        echo "Plataforma: $(uname -s)" ;;
esac

echo
echo "Configuración:"
echo "  OLLAMA_HOST=$OLLAMA_HOST"
echo "  OLLAMA_ORIGINS=$OLLAMA_ORIGINS"
echo "  OLLAMA_KEEP_ALIVE=$OLLAMA_KEEP_ALIVE"
echo "  OLLAMA_NO_CLOUD=$OLLAMA_NO_CLOUD"
echo
echo "Iniciando Ollama. Ctrl+C para detener."
echo

# Lanzar
exec ollama serve