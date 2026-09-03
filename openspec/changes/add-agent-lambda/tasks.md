## 1. Configuración

- [x] 1.1 `lambda/src/agent/config.py`: dataclass `Settings` con `knowledge_base_id` (obligatorio), `model_id` (default `amazon.nova-lite-v1:0`), `top_k` (default 5), `min_score` (default 0.4), `region` (de `AWS_REGION`/`AWS_DEFAULT_REGION`, default `us-east-1`); función `load_settings()` que lee env vars y lanza `ValueError` claro si falta `KNOWLEDGE_BASE_ID`
- [x] 1.2 `python -m pytest lambda/tests/test_config.py` (o test inline): `load_settings` con env completo devuelve los valores; sin `KNOWLEDGE_BASE_ID` lanza `ValueError`

## 2. Recuperación

- [x] 2.1 `lambda/src/agent/retrieval.py`: cliente `boto3.client("bedrock-agent-runtime")` a nivel módulo; dataclass `Chunk(text, source_uri, score)`; `retrieve(question, settings) -> list[Chunk]` que llama `Retrieve` (`knowledgeBaseId`, `retrievalQuery={"text": question}`, `retrievalConfiguration={"vectorSearchConfiguration": {"numberOfResults": settings.top_k}}`), normaliza `retrievalResults` y filtra por `settings.min_score`
- [x] 2.2 `lambda/tests/fixtures/retrieve_response.json`: respuesta de ejemplo de `Retrieve` con 2-3 `retrievalResults` (con `content.text`, `location.s3Location.uri`, `score`)
- [x] 2.3 `lambda/tests/test_retrieval.py`: monkeypatchea el cliente para devolver la fixture; verifica que `retrieve` devuelve `Chunk`s con los campos correctos y que descarta los de score bajo

## 3. Prompt

- [x] 3.1 `lambda/src/agent/prompt.py`: constante `SYSTEM` (instruye: responder solo con el contexto, citar `[n]`, decir que no sabe si el contexto no alcanza); `build_messages(question, chunks) -> list[dict]` en formato Converse (un mensaje `user` con el contexto numerado `[1]..[n]` y la pregunta)
- [x] 3.2 `lambda/tests/test_prompt.py`: `build_messages` numera los fragmentos, incluye el texto de cada chunk y la pregunta; el resultado es una lista con un dict `{"role": "user", "content": [...]}`

## 4. Generación

- [x] 4.1 `lambda/src/agent/generation.py`: cliente `boto3.client("bedrock-runtime")` a nivel módulo; `generate(messages, settings) -> str` que llama `converse` (`modelId`, `system=[{"text": SYSTEM}]`, `messages`, `inferenceConfig={"maxTokens": 512, "temperature": 0.2}`) y extrae `output.message.content[0].text`; envuelve `ClientError` en `ModelError`
- [x] 4.2 `lambda/tests/test_generation.py`: monkeypatchea `converse` para devolver una respuesta de ejemplo; `generate` devuelve el texto. Un segundo caso: `converse` lanza `ClientError` → `generate` lanza `ModelError`

## 5. Errores y handler

- [x] 5.1 `lambda/src/agent/errors.py`: `AgentError(Exception)`, `NoRelevantContext(AgentError)`, `ModelError(AgentError)`
- [x] 5.2 `lambda/src/agent/handler.py`: `lambda_handler(event, context)` — valida `event["question"]` (str no vacío, si no `ValueError`→ `{"error":..., "statusCode":400}`); `retrieve`; si `chunks` vacío → `{"answer": "No encontré información...", "sources": [], "used_chunks": 0}`; si no, `build_messages` + `generate`; devuelve `{"answer", "sources": [{"document": source_uri, "score": round(score,3)}], "used_chunks": len(chunks)}`; captura `ClientError`/`ModelError` → `{"error":..., "statusCode":502}`
- [x] 5.3 `lambda/tests/test_handler.py`: monkeypatchea `retrieval.retrieve` y `generation.generate`; casos: (a) pregunta OK → shape con `answer`/`sources`/`used_chunks`; (b) sin chunks → mensaje de "no encontré" y no se llama a `generate`; (c) evento sin `question` → `{"error", "statusCode": 400}`

## 6. Dependencias y verificación

- [x] 6.1 Confirmar `lambda/requirements.txt` vacío (comentario explicando por qué); `lambda/requirements-dev.txt` con `pytest`
- [x] 6.2 `cd lambda && python -m pytest -q` → todos los tests verdes
- [x] 6.3 `python -c "import ast,glob;[ast.parse(open(f).read()) for f in glob.glob('lambda/src/agent/*.py')]"` (paran); eliminar cualquier `.gitkeep` sobrante en `lambda/src`

## 7. Docs y cierre

- [x] 7.1 `docs/architecture.md`: Fase 4 marcada hecha; anotar el flujo del handler (Retrieve → filtro por score → prompt numerado → Converse → respuesta + fuentes) y la decisión `Retrieve` vs `RetrieveAndGenerate`
- [x] 7.2 `openspec validate add-agent-lambda --strict` pasa
- [x] 7.3 `git status`: entran los `.py` de `agent/` y de `tests/`, la fixture, `requirements-dev.txt`, `docs`; NADA de infra
- [x] 7.4 Commit único "Fase 4: código Python del agente (Retrieve + prompt + Converse)" con `Co-Authored-By`
- [x] 7.5 Archivar con `/openspec-archive-change add-agent-lambda` (sync: nueva `answer-generation`, ADDED en `semantic-retrieval`)
