## 1. Módulo agent-lambda — variables y empaquetado

- [x] 1.1 `terraform/modules/agent-lambda/variables.tf`: `name_prefix` (string); `knowledge_base_id` (string); `knowledge_base_arn` (string); `model_id` (string, default `amazon.nova-lite-v1:0`); `top_k` (number, default 5); `min_score` (number, default 0.4); `region` (string, default `us-east-1`); `log_retention_days` (number, default 14); `tags` (map, default `{}`). Eliminar el `.gitkeep`
- [x] 1.2 `terraform/modules/agent-lambda/main.tf` (encabezado `required_providers` aws `~> 6.0` + `archive ~> 2.0`): `data "archive_file" "agent"` (`type = "zip"`, `source_dir = "${path.module}/../../../lambda/src"`, `output_path = "${path.module}/../../../lambda/dist/agent.zip"`)
- [x] 1.3 `terraform fmt`

## 2. Módulo agent-lambda — log group y rol IAM

- [x] 2.1 `aws_cloudwatch_log_group.this`: `name = "/aws/lambda/${var.name_prefix}-agent"`, `retention_in_days = var.log_retention_days`, tags
- [x] 2.2 `aws_iam_role.exec` con trust a `lambda.amazonaws.com`
- [x] 2.3 `aws_iam_role_policy.exec` (documento, statements separados, **sin `"*"` en Action ni Resource**):
  - `logs:CreateLogStream`, `logs:PutLogEvents` → `"${aws_cloudwatch_log_group.this.arn}:*"`
  - `bedrock:InvokeModel` → `arn:aws:bedrock:${var.region}::foundation-model/${var.model_id}`
  - `bedrock:Retrieve` → `var.knowledge_base_arn`
- [x] 2.4 `terraform fmt`; revisar a ojo que no haya comodines

## 3. Módulo agent-lambda — función y outputs

- [x] 3.1 `aws_lambda_function.agent`: `function_name = "${var.name_prefix}-agent"`, `role = aws_iam_role.exec.arn`, `runtime = "python3.13"`, `handler = "agent.handler.lambda_handler"`, `filename = data.archive_file.agent.output_path`, `source_code_hash = data.archive_file.agent.output_base64sha256`, `timeout = 30`, `memory_size = 256`, `environment { variables = { KNOWLEDGE_BASE_ID = var.knowledge_base_id, MODEL_ID = var.model_id, TOP_K = tostring(var.top_k), MIN_SCORE = tostring(var.min_score) } }`, `depends_on = [aws_iam_role_policy.exec, aws_cloudwatch_log_group.this]`, tags
- [x] 3.2 `terraform/modules/agent-lambda/outputs.tf`: `function_name`, `function_arn`, `role_arn`, `log_group_name`
- [x] 3.3 `terraform/modules/agent-lambda/README.md` (qué crea; nota de que `InvokeModel` está acotado a `var.model_id` y del runtime)
- [x] 3.4 `terraform fmt` del módulo

## 4. Cablear en environments/dev

- [x] 4.1 `terraform/environments/dev/variables.tf`: añadir `model_id` (string, default `amazon.nova-lite-v1:0`)
- [x] 4.2 `terraform/environments/dev/main.tf`: `module "agent_lambda"` con `name_prefix`, `knowledge_base_id = module.bedrock_kb.knowledge_base_id`, `knowledge_base_arn = module.bedrock_kb.knowledge_base_arn`, `model_id = var.model_id`, `tags`
- [x] 4.3 `terraform/environments/dev/outputs.tf`: añadir `agent_function_name`, `agent_function_arn` desde `module.agent_lambda`
- [x] 4.4 `terraform -chdir=terraform/environments/dev init` (módulo + provider `archive`) + `validate` → Success + `fmt -check`

## 5. Plan (requiere aprobación de Miguel)

- [x] 5.1 Verificar model access del modelo de generación: `aws bedrock list-foundation-models --query "modelSummaries[?modelId=='amazon.nova-lite-v1:0'].[modelId,modelLifecycle.status]" --output text`
- [x] 5.2 `terraform -chdir=terraform/environments/dev plan` → añade ~4 recursos (`aws_cloudwatch_log_group`, `aws_iam_role`, `aws_iam_role_policy`, `aws_lambda_function`), 0 destroy, 0 change en los módulos existentes. Mostrar a Miguel. **PARA hasta OK explícito**

## 6. Apply + verificación

- [x] 6.1 Con aprobación: `AWS_PROFILE=personal terraform -chdir=terraform/environments/dev apply` (lo corre Miguel); confirmar recursos creados, 0 destroy
- [x] 6.2 `aws lambda get-function --function-name rag-serverless-demo-agent --query 'Configuration.{runtime:Runtime,handler:Handler,pkg:PackageType,timeout:Timeout,mem:MemorySize}'` → `PackageType = Zip`, runtime `python3.13`, handler `agent.handler.lambda_handler`
- [x] 6.3 `aws lambda get-function-configuration --function-name rag-serverless-demo-agent --query 'Environment.Variables'` → `KNOWLEDGE_BASE_ID` y `MODEL_ID` presentes
- [x] 6.4 `aws iam get-role-policy --role-name rag-serverless-demo-agent-exec --policy-name <name>` → 3 statements acotados, sin `"*"` en Action ni Resource
- [x] 6.5 `make invoke`: la Lambda ejecuta y llega a `Retrieve`; AWS devolvió `ThrottlingException` (no `AccessDenied` → el permiso funciona), y el handler respondió `{"error": ..., "statusCode": 502}` limpio, sin stack trace. Prueba con respuesta real: Fase 6 (posible throttle a vigilar)

## 7. Tooling y docs

- [x] 7.1 `scripts/package-lambda.sh` (build local del zip a `lambda/dist/agent.zip`, `mkdir -p` incluido) y `scripts/invoke-lambda.sh` (`aws lambda invoke` con `lambda/tests/events/sample-question.json`, imprime la respuesta); `chmod +x` a ambos
- [x] 7.2 `Makefile`: `package` → `scripts/package-lambda.sh`; `invoke` → `scripts/invoke-lambda.sh`; `make -n package` / `make -n invoke` muestran los comandos
- [x] 7.3 `docs/runbook.md`: sección "Fase 5" (model access del modelo de generación, `make deploy`, `make invoke` de humo, dónde ver logs: `/aws/lambda/rag-serverless-demo-agent`)
- [x] 7.4 `docs/architecture.md`: Fase 5 marcada hecha; nota del runtime `python3.13`, `timeout 30`, `memory 256`, y del rol de ejecución

## 8. Cierre

- [x] 8.1 `openspec validate deploy-agent-lambda --strict` pasa
- [x] 8.2 `git status`: entran el módulo `agent-lambda`, los cambios del stack, `scripts/*.sh`, `Makefile`, docs; NO entra `.terraform/`, state, ni `lambda/dist/`
- [x] 8.3 Commit único "Fase 5: modulo agent-lambda + despliegue" con `Co-Authored-By`
- [x] 8.4 Archivar con `/openspec-archive-change deploy-agent-lambda` (sync: ADDED en `infra-reproducibility`)
