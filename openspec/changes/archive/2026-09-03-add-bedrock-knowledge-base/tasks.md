## 1. Módulo bedrock-kb — S3 Vectors

- [x] 1.1 `terraform/modules/bedrock-kb/variables.tf`: `name_prefix` (string); `documents_bucket_arn` (string); `documents_bucket_name` (string); `embedding_dimension` (number, default `1024`); `region` (string, default `"us-east-1"`); `tags` (map, default `{}`). Eliminar el `.gitkeep`
- [x] 1.2 `terraform/modules/bedrock-kb/main.tf` (encabezado `required_providers` aws `~> 6.0`; `data "aws_caller_identity" "current"`): `aws_s3vectors_vector_bucket.this` (`vector_bucket_name = "${var.name_prefix}-vectors"`); `aws_s3vectors_index.this` (`index_name = "${var.name_prefix}-kb-index"`, `vector_bucket_name = ...this.vector_bucket_name`, `data_type = "float32"`, `dimension = var.embedding_dimension`, `distance_metric = "cosine"`, `metadata_configuration { non_filterable_metadata_keys = ["AMAZON_BEDROCK_TEXT", "AMAZON_BEDROCK_METADATA"] }`)
- [x] 1.3 `terraform fmt`; verificar que el bloque compila con `validate` (tras cablear en el stack, tarea 4.x)

## 2. Módulo bedrock-kb — rol IAM de la KB

- [x] 2.1 `terraform/modules/bedrock-kb/main.tf`: `aws_iam_role.kb` con `assume_role_policy` — principal `Service = "bedrock.amazonaws.com"`, `Condition.StringEquals["aws:SourceAccount"] = data.aws_caller_identity.current.account_id`, `Condition.ArnLike["aws:SourceArn"] = "arn:aws:bedrock:${var.region}:${account_id}:knowledge-base/*"`
- [x] 2.2 `aws_iam_role_policy.kb` (documento con statements separados, **sin `Action: "*"` ni `Resource: "*"`**):
  - `bedrock:InvokeModel` → `arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0`
  - `s3:ListBucket` → `var.documents_bucket_arn` con `Condition.StringLike["s3:prefix"] = ["raw/*"]`
  - `s3:GetObject` → `"${var.documents_bucket_arn}/raw/*"`
  - `s3vectors:GetIndex`, `QueryVectors`, `PutVectors`, `GetVectors`, `DeleteVectors`, `ListVectors` → ARN del vector bucket y del índice (`aws_s3vectors_vector_bucket.this.arn`, `aws_s3vectors_index.this.index_arn`)
- [x] 2.3 `terraform fmt`; revisar a ojo que no haya comodines de acción/recurso

## 3. Módulo bedrock-kb — Knowledge Base + data source + outputs

- [x] 3.1 `aws_bedrockagent_knowledge_base.this`: `name = "${var.name_prefix}-kb"`, `role_arn = aws_iam_role.kb.arn`; `knowledge_base_configuration { type = "VECTOR" vector_knowledge_base_configuration { embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0" embedding_model_configuration { bedrock_embedding_model_configuration { dimensions = var.embedding_dimension embedding_data_type = "FLOAT32" } } } }`; `storage_configuration { type = "S3_VECTORS" s3_vectors_configuration { index_arn = aws_s3vectors_index.this.index_arn } }`
- [x] 3.2 `aws_bedrockagent_data_source.this`: `knowledge_base_id = aws_bedrockagent_knowledge_base.this.id`, `name = "${var.name_prefix}-kb-s3"`, `data_deletion_policy = "DELETE"`; `data_source_configuration { type = "S3" s3_configuration { bucket_arn = var.documents_bucket_arn inclusion_prefixes = ["raw/"] } }`; `vector_ingestion_configuration { chunking_configuration { chunking_strategy = "FIXED_SIZE" fixed_size_chunking_configuration { max_tokens = 512 overlap_percentage = 20 } } }`
- [x] 3.3 `terraform/modules/bedrock-kb/outputs.tf`: `knowledge_base_id`, `knowledge_base_arn`, `data_source_id`, `vector_index_arn`, `vector_bucket_name`
- [x] 3.4 `terraform/modules/bedrock-kb/README.md` (qué crea; nota de `dimension` inmutable y del requisito de model access de Titan)
- [x] 3.5 `terraform fmt` del módulo

## 4. Cablear en environments/dev

- [x] 4.1 `terraform/environments/dev/main.tf`: `module "bedrock_kb"` con `name_prefix = local.name_prefix`, `documents_bucket_arn = module.s3_documents.bucket_arn`, `documents_bucket_name = module.s3_documents.bucket_name`, `tags = var.tags`
- [x] 4.2 `terraform/modules/s3-documents/outputs.tf`: confirmar que expone `bucket_arn` (ya lo hace); si no, añadirlo
- [x] 4.3 `terraform/environments/dev/outputs.tf`: añadir `knowledge_base_id`, `data_source_id`, `vector_bucket_name` desde `module.bedrock_kb`
- [x] 4.4 `terraform -chdir=terraform/environments/dev init` (instala el módulo nuevo) + `validate` → Success + `fmt -check`

## 5. Plan (requiere aprobación de Miguel)

- [x] 5.1 Verificar model access de Titan: `aws bedrock list-foundation-models --query "modelSummaries[?modelId=='amazon.titan-embed-text-v2:0'].modelId"` devuelve el id; si el `apply` luego falla con `AccessDeniedException`, habilitar "Titan Text Embeddings V2" en la consola de Bedrock (Model access) y reintentar
- [x] 5.2 `terraform -chdir=terraform/environments/dev plan` → debe añadir ~6 recursos (`aws_s3vectors_vector_bucket`, `aws_s3vectors_index`, `aws_iam_role`, `aws_iam_role_policy`, `aws_bedrockagent_knowledge_base`, `aws_bedrockagent_data_source`), 0 destroy, 0 change en `module.s3_documents`. Mostrar a Miguel. **PARA hasta OK explícito**

## 6. Apply + verificación

- [x] 6.1 Con aprobación: `AWS_PROFILE=personal terraform -chdir=terraform/environments/dev apply` (lo corre Miguel); confirmar recursos creados, 0 destroy
- [x] 6.2 Verificar la KB: `aws bedrock-agent get-knowledge-base --knowledge-base-id <id> --query 'knowledgeBase.{status:status,storage:storageConfiguration.type}'` → `status = ACTIVE`, `storage = S3_VECTORS`
- [x] 6.3 Verificar el data source: `aws bedrock-agent get-data-source --knowledge-base-id <id> --data-source-id <ds>` → chunking `FIXED_SIZE` 512/20, `inclusionPrefixes = ["raw/"]`, `dataDeletionPolicy = DELETE`
- [x] 6.4 Verificar el índice: `aws s3vectors get-index --vector-bucket-name rag-serverless-demo-vectors --index-name rag-serverless-demo-kb-index` → `dimension = 1024`, `distanceMetric = cosine`, `AMAZON_BEDROCK_TEXT`/`AMAZON_BEDROCK_METADATA` no filtrables
- [x] 6.5 Verificar el rol: `aws iam get-role-policy --role-name rag-serverless-demo-kb-role --policy-name <name>` → sin `"*"` en Action ni Resource; trust con `aws:SourceAccount` y `aws:SourceArn`

## 7. Tooling y docs

- [x] 7.1 `scripts/sync-knowledge-base.sh`: script que lee `knowledge_base_id` y `data_source_id` de `terraform output` y corre `aws bedrock-agent start-ingestion-job`; `chmod +x`; nota de que se usa en la Fase 6
- [x] 7.2 `docs/runbook.md`: sección "Fase 3" (verificar model access de Titan, `make deploy`, verificaciones de la KB, nota de que la ingesta va en la Fase 6)
- [x] 7.3 `docs/architecture.md`: Fase 3b marcada hecha; anotar `dimension = 1024` inmutable y el requisito de model access

## 8. Cierre

- [x] 8.1 `openspec validate add-bedrock-knowledge-base --strict` pasa
- [x] 8.2 `git status`: entran el módulo `bedrock-kb`, los cambios del stack, `scripts/sync-knowledge-base.sh`, docs; NO entra `.terraform/` ni state
- [x] 8.3 Commit único "Fase 3b: Bedrock Knowledge Base + S3 Vectors" con `Co-Authored-By`
- [x] 8.4 Archivar con `/openspec-archive-change add-bedrock-knowledge-base` (sync: MODIFIED + ADDED en `document-ingestion`, nueva `semantic-retrieval`)
