# Módulo `bedrock-kb`

Crea el vector store y la Knowledge Base del RAG:

- **S3 Vectors**: `aws_s3vectors_vector_bucket` + `aws_s3vectors_index`
  (`cosine`, `float32`, `dimension = var.embedding_dimension`). Las claves
  `AMAZON_BEDROCK_TEXT` y `AMAZON_BEDROCK_METADATA` van como **no filtrables**
  (requisito de Bedrock).
- **Rol IAM** de la KB, de mínimo privilegio (sin `Action`/`Resource` `"*"`):
  `bedrock:InvokeModel` sobre Titan v2, lectura del bucket de documentos en
  `raw/`, y las acciones de `s3vectors` sobre el índice. Trust acotado a
  `bedrock.amazonaws.com` con `aws:SourceAccount` + `aws:SourceArn`.
- **`aws_bedrockagent_knowledge_base`**: embeddings con Titan Text Embeddings v2,
  storage = el índice de S3 Vectors.
- **`aws_bedrockagent_data_source`**: fuente S3 (`raw/`), chunking fijo
  512 tokens / 20% overlap, `data_deletion_policy = DELETE`.

## Notas

- **`dimension` es INMUTABLE** en el índice. Cambiarla obliga a recrear índice +
  KB + re-ingestar. Default 1024 (Titan v2). 256 = más barato en storage.
- **Model access**: el modelo *Titan Text Embeddings v2* debe estar habilitado
  en Bedrock para la cuenta. Los modelos de Amazon suelen venir habilitados por
  defecto; si el `apply` falla con `AccessDeniedException`, habilitarlo en la
  consola (Model access) y reintentar.
- La **ingesta** (`start-ingestion-job`) no la corre este módulo: se hace en la
  Fase 6 con `scripts/sync-knowledge-base.sh` cuando hay documentos en `raw/`.

| Input | Default | Descripción |
|-------|---------|-------------|
| `name_prefix` | — | Prefijo de los recursos. |
| `documents_bucket_arn` / `_name` | — | Bucket de documentos fuente. |
| `embedding_dimension` | `1024` | Dimensión (índice + modelo). Inmutable en el índice. |
| `region` | `us-east-1` | Para los ARN de modelo y la condición de trust. |
| `tags` | `{}` | Tags. |

| Output | Descripción |
|--------|-------------|
| `knowledge_base_id` / `_arn` | La KB. |
| `data_source_id` | El data source S3. |
| `vector_index_arn` / `vector_bucket_name` | El índice de S3 Vectors. |
| `role_arn` | Rol IAM de la KB. |
