# Módulo `agent-lambda`

Empaqueta y despliega el agente (código de la Fase 4) como función Lambda.

- **Empaquetado**: `data "archive_file"` comprime `lambda/src/` a
  `lambda/dist/agent.zip` (`.zip` estándar, sin capas ni contenedor).
  `source_code_hash` redepliega al cambiar el código.
- **Función**: runtime `python3.13`, handler `agent.handler.lambda_handler`,
  `timeout = 30`, `memory_size = 256`. Config por env vars
  (`KNOWLEDGE_BASE_ID`, `MODEL_ID`, `TOP_K`, `MIN_SCORE`).
- **Log group** explícito `/aws/lambda/<prefix>-agent` con retención.
- **Rol de ejecución** de mínimo privilegio (sin `Action`/`Resource` `"*"`):
  - `logs:CreateLogStream` + `logs:PutLogEvents` sobre el ARN del log group.
  - `bedrock:InvokeModel` sobre **`var.model_id`** exactamente. Si se cambia
    `MODEL_ID` hay que cambiar `var.model_id` (un solo sitio) o la invocación
    falla con AccessDenied.
  - `bedrock:Retrieve` sobre el ARN de la Knowledge Base.

| Input | Default | Descripción |
|-------|---------|-------------|
| `name_prefix` | — | Prefijo. |
| `knowledge_base_id` / `_arn` | — | La KB que consulta el agente. |
| `model_id` | `amazon.nova-lite-v1:0` | Modelo de generación; acota `InvokeModel`. |
| `top_k` / `min_score` | `5` / `0.4` | Parámetros de recuperación. |
| `region` | `us-east-1` | Para el ARN del modelo. |
| `log_retention_days` | `14` | Retención de logs. |
| `tags` | `{}` | Tags. |

| Output | Descripción |
|--------|-------------|
| `function_name` / `function_arn` | La función. |
| `role_arn` | Rol de ejecución. |
| `log_group_name` | Log group. |
