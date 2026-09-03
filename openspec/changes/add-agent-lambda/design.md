## Context

Ver `proposal.md` y los specs. La KB `rag-serverless-demo-kb` existe
(`knowledge_base_id` es un output del stack). El código vive en
`lambda/src/agent/` (hoy placeholders con docstrings). Runtime objetivo: Python
3.13 de Lambda, que trae `boto3`/`botocore` recientes (incluyen
`bedrock-runtime` y `bedrock-agent-runtime`).

## Goals / Non-Goals

**Goals:**

- Código legible, cada paso del RAG visible y por separado: retrieval → prompt
  → generación.
- Solo `boto3` y librería estándar. Sin LangChain / LlamaIndex / LangGraph.
- Testeable en local sin tocar AWS.

**Non-Goals:**

- No se empaqueta el `.zip` ni se crea el recurso Lambda (Fase 5).
- No hay API Gateway: la entrada es un evento de prueba `{"question": "..."}`.
- No hay memoria de conversación ni multi-turn; una pregunta, una respuesta.
- No se sube ni ingesta ningún documento (Fase 6).

## Decisions

### DD1 - `Retrieve`, no `RetrieveAndGenerate`

`bedrock-agent-runtime` ofrece dos operaciones:

- **`RetrieveAndGenerate`**: una sola llamada; la KB recupera, arma el prompt,
  llama a un modelo y devuelve la respuesta con citaciones. Menos código, pero
  el prompt y el modelo los controla el servicio.
- **`Retrieve`**: devuelve solo los fragmentos relevantes; el prompt y la
  llamada al modelo los hace el código.

Se elige **`Retrieve`**: el objetivo de la charla es que cada paso sea
explícito (recuperar, construir el prompt, invocar el modelo). Con
`RetrieveAndGenerate` esos dos pasos serían una caja negra.

### DD2 - Generación con la API `Converse`

`bedrock-runtime.converse(...)` en vez de `invoke_model`:

- **Por qué**: `Converse` normaliza el formato de mensajes entre familias de
  modelos (Nova, Claude, Llama…). Cambiar `MODEL_ID` no obliga a reescribir el
  payload. `invoke_model` tiene un JSON distinto por familia.
- `inferenceConfig`: `maxTokens = 512`, `temperature = 0.2` (respuestas
  cortas y deterministas para una demo).

### DD3 - Modelo por defecto: `amazon.nova-lite-v1:0`

Env var `MODEL_ID`, default `amazon.nova-lite-v1:0`.

- **Por qué**: es de Amazon (suele venir con model access habilitado, como
  Titan), barato y rápido, y suficiente para responder sobre políticas
  ficticias. Se puede cambiar a `anthropic.claude-3-5-haiku-*` u otro por env
  var sin tocar código (gracias a `Converse`).
- La verificación de model access se hace en la Fase 5 al desplegar.

### DD4 - Forma de la salida del handler

```json
{
  "answer": "texto de la respuesta",
  "sources": [{"document": "s3://.../raw/x.md", "score": 0.72}],
  "used_chunks": 3
}
```

En caso de error: `{"error": "mensaje corto", "statusCode": 4xx|5xx}`. Sin
`try/except` que trague todo: solo se capturan `botocore.exceptions.ClientError`
y `ValueError` de validación de entrada; cualquier otra excepción se deja
propagar (fallo real, se ve en CloudWatch).

### DD5 - Umbral de score y "no sé"

`MIN_SCORE` (default `0.4`). Tras `Retrieve`, se filtran los fragmentos por
score. Si la lista queda vacía, el handler devuelve
`{"answer": "No encontré información sobre eso en los documentos.",
"sources": [], "used_chunks": 0}` y **no** llama al modelo. Evita que el modelo
alucine cuando la KB no tiene nada relevante.

- El score de `Retrieve` con S3 Vectors + `cosine` está en `[0, 1]` (mayor =
  más parecido). `0.4` es un punto de partida conservador; es env var para
  ajustarlo en la demo sin redeploy de código.

### DD6 - Estructura de módulos

- `config.py`: lee las env vars una vez, expone `Settings` (dataclass) con
  defaults. Falla claro si `KNOWLEDGE_BASE_ID` no está.
- `retrieval.py`: `retrieve(question, settings) -> list[Chunk]`. `Chunk` es un
  `dataclass(text, source_uri, score)`.
- `prompt.py`: `SYSTEM` (constante) y `build_messages(question, chunks) ->
  list[dict]`. Numera los fragmentos `[1]`, `[2]`… para que el modelo pueda
  citar.
- `generation.py`: `generate(messages, settings) -> str`.
- `errors.py`: `AgentError(Exception)`, `NoRelevantContext(AgentError)`,
  `ModelError(AgentError)`.
- `handler.py`: orquesta; sin lógica de negocio propia más allá del pegamento.
- Clientes boto3 (`boto3.client("bedrock-agent-runtime")`,
  `"bedrock-runtime"`) se crean a nivel de módulo (se reutilizan entre
  invocaciones cálidas del Lambda).

### DD7 - Tests sin AWS

`pytest` con `monkeypatch` sobre los clientes boto3 de `retrieval` y
`generation`. `test_prompt.py` prueba funciones puras. Fixture
`retrieve_response.json` = respuesta real de `Retrieve` recortada. No se usa
`moto` (no cubre bien `bedrock-agent-runtime`).

## Risks / Trade-offs

- **[boto3 del runtime no tiene `retrieve`]** → Falso: `Retrieve` existe en
  boto3 desde nov-2023; el runtime de Python 3.13 lo tiene de sobra. Si acaso,
  la Fase 5 puede vendorizar un boto3 nuevo en el layer, pero no hará falta.
- **[`amazon.nova-lite-v1:0` sin model access]** → Se detecta en la Fase 5 con
  un `converse` de prueba; si falla, se habilita en consola o se cambia el env
  var a otro modelo.
- **[El score de S3 Vectors no está normalizado como se asume]** → `MIN_SCORE`
  es env var; si en la Fase 6 los scores vienen en otra escala, se ajusta sin
  tocar código.
- **[Prompt injection desde los documentos]** → Fuera de alcance para una demo
  con documentos ficticios propios; se anota como hardening futuro.

## Migration Plan

1. Escribir los 6 módulos + `config.py`.
2. Escribir los tests + la fixture.
3. `cd lambda && python -m pytest` → verde.
4. `python -c "import ast; ..."` sobre todos los `.py` (paran).
5. `docs/architecture.md`; commit; archivar (sync de specs).

Sin rollback de infra (no hay infra). `git revert` si hiciera falta.

## Open Questions

- ¿`top_k` por defecto 5 o 3? 5 da más contexto a cambio de un prompt más
  largo; para políticas cortas 5 está bien. Es env var; no afecta el diseño.
