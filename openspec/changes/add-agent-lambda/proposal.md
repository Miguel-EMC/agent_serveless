## Why

Con la Knowledge Base ya en pie (Fase 3), toca el código que la usa: el agente
que, dada una pregunta, recupera contexto de la KB, arma un prompt y le pide al
modelo de Bedrock la respuesta final citando de qué documento salió. Es la Fase
4. Solo código Python (en `lambda/src/agent/`); el empaquetado y el despliegue
del Lambda son la Fase 5.

## What Changes

- **`lambda/src/agent/retrieval.py`**: `retrieve(question, kb_id, top_k)` usando
  el cliente `bedrock-agent-runtime`, operación **`Retrieve`** (no
  `RetrieveAndGenerate` — ver `design.md` DD1). Devuelve una lista de
  `{"text", "source_uri", "score"}` a partir de `retrievalResults`.
- **`lambda/src/agent/prompt.py`**: `build_system_prompt()` y
  `build_messages(question, chunks)` — construyen el `system` y los `messages`
  del formato Converse: contexto numerado + la pregunta, con instrucción de
  responder **solo** con el contexto y de citar los números de fragmento usados.
- **`lambda/src/agent/generation.py`**: `generate(system, messages, model_id)`
  usando el cliente `bedrock-runtime`, operación **`Converse`**
  (`inferenceConfig` con `maxTokens` y `temperature` bajos). Devuelve el texto.
- **`lambda/src/agent/errors.py`**: excepciones `AgentError`,
  `NoRelevantContext`, `ModelError` (con mensajes claros).
- **`lambda/src/agent/handler.py`**: `lambda_handler(event, context)` —
  1. saca `question` del evento (valida que exista y no esté vacía);
  2. `retrieve(...)`; si no hay resultados o todos por debajo de un umbral de
     score → responde "no encontré información en los documentos" (no inventa);
  3. `build_messages(...)` + `generate(...)`;
  4. devuelve `{"answer": str, "sources": [{"document": str, "score": float}],
     "used_chunks": int}`.
  Los errores de Bedrock (`ClientError`: throttling, acceso denegado, timeout)
  se capturan y se devuelven como `{"error": "..."}` con `statusCode` 4xx/5xx,
  sin filtrar trazas internas.
- **`lambda/src/agent/__init__.py`**: se mantiene vacío.
- **Config por variables de entorno** (las setea la Fase 5, aquí solo se leen):
  `KNOWLEDGE_BASE_ID`, `MODEL_ID` (default `amazon.nova-lite-v1:0`),
  `TOP_K` (default `5`), `MIN_SCORE` (default `0.4`), `AWS_REGION` (lo pone
  Lambda). Un `agent/config.py` centraliza la lectura con defaults.
- **`lambda/requirements.txt`**: se confirma vacío (boto3 + botocore vienen en
  el runtime de Lambda y ya incluyen `bedrock-runtime` y
  `bedrock-agent-runtime`). `lambda/requirements-dev.txt`: `pytest`.
- **`lambda/tests/`**:
  - `test_prompt.py`: `build_messages` produce el shape esperado, numera los
    fragmentos, incluye la pregunta.
  - `test_retrieval.py`: el parser convierte un `retrievalResults` de ejemplo
    (fixture JSON) en la lista `{"text","source_uri","score"}`.
  - `test_handler.py`: con `retrieve` y `generate` monkeypatcheados, el handler
    devuelve el shape correcto y maneja "sin resultados".
  - `lambda/tests/fixtures/retrieve_response.json`: respuesta de ejemplo de
    `Retrieve`.
- **`docs/architecture.md`**: marcar Fase 4 hecha; anotar el flujo del handler.

## Capabilities

### New Capabilities

- `answer-generation`: dada una pregunta y unos fragmentos de contexto, el
  agente arma un prompt acotado y genera una respuesta en lenguaje natural que
  se apoya solo en ese contexto y cita las fuentes usadas; si no hay contexto
  suficiente, lo dice en vez de inventar.

### Modified Capabilities

- `semantic-retrieval`: se **añade** el requisito de que el agente consulta la
  KB con la operación `Retrieve` (top-k configurable, umbral de score) y expone
  los fragmentos con su documento de origen para las fases siguientes.

## Impact

- **Nuevos archivos**: `lambda/src/agent/{config,retrieval,prompt,generation,
  errors,handler}.py` (reemplazan los placeholders), `lambda/tests/*.py`,
  `lambda/tests/fixtures/retrieve_response.json`.
- **Modificados**: `lambda/requirements-dev.txt`, `docs/architecture.md`.
- **Sin AWS**: este cambio no despliega nada. Los tests corren local con
  `pytest` y boto3 monkeypatcheado; no llaman a AWS.
- **Dependencia de la Fase 5**: el `MODEL_ID` por defecto
  (`amazon.nova-lite-v1:0`) debe tener model access habilitado (los modelos de
  Amazon suelen venir habilitados); se verifica en la Fase 5 al desplegar.
- **Confidencialidad**: el system prompt y los tests usan texto genérico; nada
  específico de ninguna empresa real.
