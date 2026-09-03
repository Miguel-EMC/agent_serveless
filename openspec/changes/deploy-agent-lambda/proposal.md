## Why

El código del agente ya existe (Fase 4). Falta empaquetarlo y desplegarlo como
función Lambda, con un rol de ejecución de mínimo privilegio y las variables de
entorno que apuntan a la Knowledge Base. Es la Fase 5. Tras esto el Lambda se
puede invocar directo (consola o AWS CLI); API Gateway solo se menciona como
paso de producción, no se implementa.

## What Changes

- **Módulo `terraform/modules/agent-lambda/`**:
  - Empaquetado con `data "archive_file"`: comprime `lambda/src/` a
    `lambda/dist/agent.zip` (`.zip` estándar, sin capas, sin Docker). El
    `source_code_hash` cuelga del hash del zip para que un cambio de código
    redepliegue.
  - `aws_cloudwatch_log_group` `/aws/lambda/${name_prefix}-agent` con
    `retention_in_days = 14` (creado explícito para poder acotar los permisos
    de logs).
  - `aws_iam_role` de ejecución + `aws_iam_role_policy` de **mínimo privilegio**
    (sin `Action`/`Resource` `"*"`):
    - `logs:CreateLogStream`, `logs:PutLogEvents` sobre el ARN del log group.
    - `bedrock:InvokeModel` sobre `arn:aws:bedrock:${region}::foundation-model/${model_id}`.
    - `bedrock:Retrieve` sobre el ARN de la Knowledge Base.
  - `aws_lambda_function`: `runtime = "python3.13"`, `handler =
    "agent.handler.lambda_handler"`, `filename` + `source_code_hash` del zip,
    `timeout = 30`, `memory_size = 256`, `environment.variables` =
    `{ KNOWLEDGE_BASE_ID, MODEL_ID, TOP_K, MIN_SCORE }`.
  - Outputs: `function_name`, `function_arn`, `role_arn`, `log_group_name`.
- **`terraform/environments/dev/`**: `module "agent_lambda"` con
  `knowledge_base_id` y `knowledge_base_arn` de `module.bedrock_kb`,
  `model_id = var.model_id` (nueva variable, default `amazon.nova-lite-v1:0`);
  nuevos outputs `agent_function_name`, `agent_function_arn`.
- **`scripts/package-lambda.sh`**: build local del zip (para inspección / uso
  fuera de Terraform); el `apply` no lo necesita porque `archive_file` lo hace.
- **`scripts/invoke-lambda.sh`**: `aws lambda invoke` con
  `lambda/tests/events/sample-question.json` y muestra la respuesta.
- **`Makefile`**: targets `package` (→ `scripts/package-lambda.sh`) e `invoke`
  (→ `scripts/invoke-lambda.sh`) dejan de ser stubs.
- **`.gitignore`**: `lambda/dist/` ya está ignorado (Fase 0.5); se confirma.
- **`docs/runbook.md`**: sección "Fase 5" (verificar model access del modelo de
  generación, `make deploy`, `make invoke`, dónde ver los logs).
- **`docs/architecture.md`**: Fase 5 marcada hecha; nota del runtime y del rol.

## Capabilities

### Modified Capabilities

- `infra-reproducibility`: se **añade** un requisito — el agente se despliega
  como una función Lambda empaquetada en `.zip` estándar (sin Docker/ECR), con
  runtime Python fijo, y un rol de ejecución de mínimo privilegio cuyo acceso se
  limita a: escribir sus logs, `bedrock:InvokeModel` sobre el modelo
  configurado y `bedrock:Retrieve` sobre la Knowledge Base.

### New Capabilities

Ninguna. El comportamiento del agente ya está descrito en `answer-generation` y
`semantic-retrieval`; esta fase lo hace ejecutable, no cambia el contrato.

## Impact

- **Nuevos archivos**: `terraform/modules/agent-lambda/{main,variables,outputs,
  README}.tf|md`, `scripts/{package-lambda,invoke-lambda}.sh`.
- **Modificados**: `terraform/environments/dev/{main,variables,outputs}.tf`,
  `Makefile`, `docs/runbook.md`, `docs/architecture.md`, spec de
  `infra-reproducibility`.
- **AWS** (`us-east-1`, cuenta 034703319129): 1 función Lambda, 1 rol IAM + su
  policy, 1 log group. Costo: dentro del free tier de Lambda (1M req/mes); solo
  se paga Bedrock por token al invocar.
- **Requisito manual**: el modelo de generación (`amazon.nova-lite-v1:0` por
  defecto) debe tener model access habilitado. Se verifica en el runbook; si no,
  se habilita en consola o se cambia `var.model_id`.
- **Sin ingesta ni prueba e2e**: subir documentos, sincronizar la KB e invocar
  con una pregunta real es la Fase 6. Aquí se despliega y, como humo, se puede
  invocar (devolverá "no encontré información" porque la KB está vacía).
