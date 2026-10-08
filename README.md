# Ollama Nimble Decision Layer — Windows/Linux/macOS

Capa de decisiones local con Ollama + Nimble 9B. Clasifica un texto
(ticket, mensaje, email) en N decisiones binarias con valores de
probabilidad 0-1.

**Adaptación multiplataforma** del proyecto
[ollama-nimble-decision-layer](https://github.com/RicardoBertran/ollama-nimble-decision-layer)
de Ricardo Bertran (MIT, 2026). Este fork añade equivalentes en bash para
Linux/macOS/WSL, manteniendo los scripts PowerShell originales para
Windows.

## Diferencias con el original

| Aspecto | Original (Windows) | Este fork (Windows/Linux/macOS) |
|---------|-------------------|---------------------------------|
| Sistema | Windows 10/11 + PowerShell | Windows + PowerShell, Linux/macOS/WSL + bash |
| Selección GPU | NVIDIA con `nvidia-smi` | Drivers del sistema (Metal/CUDA/ROCm/Vulkan) automáticos |
| Scripts | `*.ps1` | `*.ps1` (originales) + `*.sh` (nuevos) |
| Servidor web demo | PowerShell + puerto | PowerShell o Python 3 `http.server` |
| Persistencia scripts | Idéntica | Idéntica |

Los scripts PowerShell originales se preservan en `scripts/*.ps1` por
compatibilidad y referencia. Los `*.sh` son los que se usan en este fork.

## Estructura

```
nimble-demo/
├── README.md                  ← este fichero
├── LICENSE                    ← MIT del proyecto original
│
├── app/                       ← frontend (idéntico al original)
│   ├── index.html
│   ├── styles.css
│   ├── app.js
│   └── decisions.json         ← ticket de ejemplo + 10 preguntas
│
├── docs/
│   └── integration.md         ← guía de integración con agentes
│
├── examples/
│   ├── request.json           ← petición mínima
│   └── response.json          ← respuesta completa de referencia
│
└── scripts/
    ├── start-ollama.sh        ← arranca Ollama con config óptima
    ├── get-model.sh           ← descarga nimble:latest
    ├── test-decision.sh       ← test E2E con salida formateada
    ├── start-demo.sh          ← sirve el demo web en localhost:8080
    │
    ├── Start-Ollama.ps1       ← originales Windows (referencia)
    ├── Get-Model.ps1
    ├── Start-Demo.ps1
    ├── Test-Decision.ps1
    └── Common.ps1
```

## Inicio rápido

> **Si estás en Windows**: usa los scripts `*.ps1` originales. Este fork
> solo añade equivalentes bash para Linux/macOS/WSL.
>
> Si estás en Linux/macOS/WSL, sigue los pasos de abajo.

### 1. Arrancar Ollama (si no lo está)

```bash
# Arranca con CORS configurado para localhost:8080 y keep-alive 30m
./scripts/start-ollama.sh

# Opciones:
./scripts/start-ollama.sh --keep-alive 1h
./scripts/start-ollama.sh --demo-port 8081
./scripts/start-ollama.sh --origin http://192.168.1.100:8080
```

### 2. Descargar el modelo

```bash
./scripts/get-model.sh
# = ollama pull nimble:latest
```

### 3. Probar con el ticket de ejemplo

```bash
./scripts/test-decision.sh
# 4.37s | 10430 input → 11 output tokens
# problema_tecnico     0.9923  SÍ
# problema_facturacion 0.9989  SÍ
# solicita_reembolso   0.9992  SÍ
# ...
```

Opciones:

```bash
./scripts/test-decision.sh -r 3    # 3 peticiones (compara cold/warm)
./scripts/test-decision.sh -m nimble:7b  # versión específica
./scripts/test-decision.sh -t 0.4  # umbral personalizado
```

### 4. Lanzar el demo web

```bash
./scripts/start-demo.sh
# → abre http://localhost:8080
```

## Qué hace cada script

| Script bash | Equivalente PowerShell | Función |
|-------------|------------------------|---------|
| `start-ollama.sh` | `Start-Ollama.ps1` | Arranca `ollama serve` con CORS, keep-alive y `OLLAMA_NO_CLOUD=1` |
| `get-model.sh` | `Get-Model.ps1` | `ollama pull nimble:latest` con verificación de versión |
| `test-decision.sh` | `Test-Decision.ps1` | E2E test con formato de tabla, valida respuestas noul |
| `start-demo.sh` | `Start-Demo.ps1` | Sirve `app/` en `http://localhost:8080` con `python3 -m http.server` |

## Uso directo de la API

```bash
# Una pregunta
curl -X POST http://localhost:11434/v1/systemone \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nimble:latest",
    "state": "Hola, quiero un reembolso por favor",
    "questions": {
      "solicita_reembolso": {
        "type": "noul",
        "instructions": "¿El cliente solicita explícitamente un reembolso?",
        "criteria": {
          "true": "Pide devolver dinero o reembolsar un cargo.",
          "false": "No solicita devolver dinero."
        }
      }
    }
  }'
```

Respuesta:

```json
{
  "model": "nimble:latest",
  "answers": {
    "solicita_reembolso": {"type": "noul", "noul": 0.97}
  },
  "usage": {"input_tokens": 150, "output_tokens": 1}
}
```

`noul >= 0.5` → SÍ. `noul < 0.5` → NO.

## Integración con agentes y chatbots

Ver [`docs/integration.md`](docs/integration.md) para:

- Routing (seleccionar agente o cola según clasificación)
- Tool selection (decidir qué herramienta invocar)
- Memoria (decidir si guardar preferencia)
- Escalado (cuándo pasar a humano)
- Moderación (detección de abuso/spam)
- `choice` questions (decisiones multi-opción)
- Ejemplos en PowerShell, curl (bash) y Python

Ejemplo de routing con `choice`:

```bash
curl -X POST http://localhost:11434/v1/systemone \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nimble:latest",
    "state": "Me han cobrado dos veces y necesito un reembolso.",
    "questions": {
      "destino": {
        "type": "choice",
        "instructions": "Selecciona el equipo principal para este ticket.",
        "criteria": {
          "facturacion": "Pagos, cargos, facturas y reembolsos.",
          "soporte_tecnico": "Errores y fallos de funcionamiento.",
          "sin_coincidencia": "Información insuficiente o ninguna categoría adecuada."
        }
      }
    }
  }'
```

## Desde Python

```python
import requests

def clasificar(texto: str, preguntas: dict, modelo: str = "nimble:latest",
               umbral: float = 0.5) -> dict:
    r = requests.post(
        "http://localhost:11434/v1/systemone",
        json={"model": modelo, "state": texto, "questions": preguntas},
        timeout=120,
    )
    r.raise_for_status()
    data = r.json()
    return {
        k: {"valor": v["noul"], "decision": "SÍ" if v["noul"] >= umbral else "NO"}
        for k, v in data["answers"].items()
    }
```

## Formato de las preguntas

Cada pregunta es un objeto con 4 campos:

```json
{
  "clave_unica": {
    "type": "noul",
    "instructions": "¿Pregunta en lenguaje natural?",
    "criteria": {
      "true": "Qué condiciones indican SÍ",
      "false": "Qué condiciones indican NO"
    }
  }
}
```

Tipos admitidos:
- `noul` — sí/no como probabilidad (0.0-1.0)
- `choice` — selección entre opciones con `probabilities` y `confidence`
- `score` — puntuación numérica (consultar docs Ollama)

Límites: 64 preguntas, body 64 KiB sin imágenes.

## Casos de uso

| Uso | Tipo de preguntas | Acción posterior |
|-----|-------------------|------------------|
| **Routing** | ¿técnico/facturación/acceso? | Seleccionar agente o cola |
| **Tool selection** | ¿necesita consultar pedido? | Llamar a la API de pedidos |
| **Memoria** | ¿contiene preferencia duradera? | Guardar en memoria del usuario |
| **Escalado** | ¿pide persona humana? | Pasar a revisión humana |
| **Moderación** | ¿contiene abuso o spam? | Bloquear o marcar |
| **Clasificación** | ¿qué etiqueta encaja? | Añadir tag al ticket |

**Importante**: las probabilidades NO sustituyen permisos, validación ni
autenticación. Un "SÍ" en "solicita reembolso" indica la intención del
cliente, no autoriza devolver dinero.

## Comparativa con chat normal

| Aspecto | `/v1/chat/completions` | `/v1/systemone` |
|---------|------------------------|-----------------|
| Output | Texto libre (50-500 tokens) | 1 número por pregunta |
| Latencia | 5-30 segundos | 1-5 segundos |
| Coste | Alto (muchos tokens) | Mínimo |
| Estructura | Requiere parsing | JSON nativo |
| Uso típico | Generación | Clasificación |

## Solución de problemas

### `curl: (7) Failed to connect to localhost:11434`

Ollama no está corriendo.

```bash
# Arranca Ollama
./scripts/start-ollama.sh
# O si ya está fuera de este script:
ollama serve &
```

### `HTTP 404: model not found`

`nimble:latest` no descargado.

```bash
./scripts/get-model.sh
```

### `HTTP 400: invalid questions`

Falta `type`, `criteria` u otro campo obligatorio. Ver
[Formato de las preguntas](#formato-de-las-preguntas).

### El navegador da `Failed to fetch` o error CORS

Ollama no autoriza el origin. Solución: arrancar Ollama con la variable
`OLLAMA_ORIGINS`:

```bash
OLLAMA_ORIGINS="http://localhost:8080,http://192.168.1.100:8080" ollama serve
# O usar el script:
./scripts/start-ollama.sh --origin http://192.168.1.100:8080
```

### Primera petición muy lenta

Normal: el modelo se carga en RAM. Las siguientes son más rápidas.
Para mantener caliente: `keep_alive: "30m"` en el payload (ya incluido
en `test-decision.sh` y la demo web).

## Atribución

Este proyecto es una adaptación del original
[ollama-nimble-decision-layer](https://github.com/RicardoBertran/ollama-nimble-decision-layer)
de **Ricardo Bertran** y contribuidores, licenciado bajo MIT.

Frontend HTML/CSS/JS, scripts PowerShell, `decisions.json` y `integration.md`
son del proyecto original (sin modificaciones). Los scripts `*.sh` y este
README son de este fork.

## Licencia

MIT (mismo que el proyecto original). Ver [LICENSE](LICENSE).
