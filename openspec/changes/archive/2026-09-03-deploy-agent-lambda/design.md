## Context

Ver `proposal.md` y el spec. El código vive en `lambda/src/agent/` (Fase 4). La
KB `rag-serverless-demo-kb` existe; `module.bedrock_kb` expone
`knowledge_base_id` y `knowledge_base_arn`. Provider AWS `~> 6.0`. El stack
`dev` ya cablea `s3_documents` y `bedrock_kb`.

## Goals / Non-Goals

**Goals:**

- Función Lambda desplegada y invocable, con rol de mínimo privilegio.
- Empaquetado `.zip` estándar hecho por Terraform (`archive_file`), sin pasos
  manuales.
- Redeploy automático cuando cambia el código (`source_code_hash`).

**Non-Goals:**

- Sin API Gateway (se invoca directo).
- Sin capas Lambda, sin contenedor, sin ECR.
- Sin VPC: la Lambda no necesita la VPC (S3 Vectors y Bedrock son APIs
  públicas de AWS; no hay RDS).
- Sin ingesta ni prueba con pregunta real (Fase 6).

## Decisions

### DD1 - Empaquetado con `data "archive_file"`

```
data "archive_file" "agent" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/src"
  output_path = "${path.module}/../../../lambda/dist/agent.zip"
}
```

- El zip contiene `agent/` en la raíz → handler `agent.handler.lambda_handler`.
- `source_code_hash = data.archive_file.agent.output_base64sha256` → cualquier
  cambio en `lambda/src/` redepliega en el próximo `apply`.
- **Alternativa - `scripts/package-lambda.sh` + `filename` fijo**: obliga a
  correr el script antes de cada `apply` y a acordarse. `archive_file` lo hace
  Terraform. El script se deja igualmente para inspección/uso manual.
- `lambda/dist/` está gitignored (Fase 0.5).

### DD2 - Runtime `python3.13`

Última versión estable de Python en Lambda. `boto3`/`botocore` del runtime son
recientes e incluyen `bedrock-runtime` y `bedrock-agent-runtime`. `requirements.txt`
vacío → el zip solo lleva `agent/`.

### DD3 - Log group explícito + permisos de logs acotados

`aws_cloudwatch_log_group.this` `/aws/lambda/${name_prefix}-agent`,
`retention_in_days = 14`. Se crea explícito (no se deja que Lambda lo cree)
para poder dar `logs:CreateLogStream` + `logs:PutLogEvents` **solo** sobre su
ARN (`${log_group_arn}:*`), sin `logs:CreateLogGroup` sobre `*`.

- **Alternativa - managed policy `AWSLambdaBasicExecutionRole`**: concede logs
  sobre `Resource: "*"`. Rechazada por el principio de mínimo privilegio.

### DD4 - Permisos de Bedrock acotados

- `bedrock:InvokeModel` → `arn:aws:bedrock:${var.region}::foundation-model/${var.model_id}`
  (los foundation models son ARNs sin cuenta). Si se cambia `MODEL_ID` por env
  var sin actualizar `var.model_id`, la invocación al modelo nuevo falla con
  AccessDenied — es el trade-off de acotar; se documenta.
- `bedrock:Retrieve` → el ARN de la Knowledge Base (`var.knowledge_base_arn`).
  `Retrieve` es la acción de `bedrock-agent-runtime`; en IAM el prefijo del
  servicio es `bedrock`.
- **Sin** `bedrock:RetrieveAndGenerate` (no se usa), **sin** `s3vectors:*` (la
  Lambda no habla con S3 Vectors directo; lo hace la KB con su propio rol).

### DD5 - `timeout = 30`, `memory_size = 256`

- `Retrieve` + `Converse` con Nova Lite tardan típicamente 2-6 s; 30 s deja
  margen para cold start + reintentos internos de boto3.
- 256 MB: el código es mínimo (solo boto3); no necesita más. Menos memoria =
  menos costo, pero por debajo de 128 no baja y 256 da algo de CPU para el cold
  start del import de boto3.

### DD6 - Variable `model_id` en el stack

`terraform/environments/dev/variables.tf` gana `model_id` (default
`amazon.nova-lite-v1:0`). Se pasa al módulo, que lo usa para (a) la env var
`MODEL_ID` de la función y (b) el ARN del statement `InvokeModel`. Un solo sitio
para cambiar el modelo.

### DD7 - Invocación de humo

Tras el `apply`, `make invoke` manda `{"question": "..."}`. Con la KB vacía
(sin ingesta), la respuesta esperada es
`{"answer": "No encontré información...", "sources": [], "used_chunks": 0}` —
suficiente para confirmar que el pipeline (permisos, env vars, Retrieve) está
bien. La prueba con respuesta real es la Fase 6.

## Risks / Trade-offs

- **[`amazon.nova-lite-v1:0` sin model access]** → El `make invoke` de humo
  igual funciona (no llega a `generate` si la KB está vacía). Falla recién en la
  Fase 6 con una pregunta respondible; se detecta ahí y se habilita el modelo o
  se cambia `var.model_id`.
- **[`archive_file` incluye `.pyc`/`__pycache__` si existen]** → Se corre desde
  un `lambda/src` limpio; `.gitignore` ya excluye `__pycache__`. Si molesta, se
  añade `excludes` al `archive_file`.
- **[Acotar `InvokeModel` al modelo exacto rompe si se cambia el env var]** →
  Documentado en DD4; el arreglo es cambiar `var.model_id` (un sitio).
- **[Python 3.13 deja de ser el "latest" en el futuro]** → Es una versión
  soportada; se sube cuando toque en un cambio propio.

## Migration Plan

1. Escribir el módulo `agent-lambda` y cablearlo en `environments/dev`.
2. `terraform -chdir=terraform/environments/dev init` (módulo nuevo +
   provider `archive` de hashicorp) + `validate`.
3. `plan` → añade log group, rol + policy, función (~4 recursos), 0 destroy.
   **PARA** para Miguel.
4. Verificar model access del modelo de generación.
5. Con OK: `apply` (lo corre Miguel).
6. `make invoke` de humo; verificaciones (`tasks.md`); docs; commit; archivar.

Rollback: `terraform destroy` del módulo o `git revert` + apply.

## Open Questions

- ¿`retention_in_days` 14 o 7? 14 da margen para depurar la demo sin coste
  relevante. Env-independiente; no afecta el diseño.
