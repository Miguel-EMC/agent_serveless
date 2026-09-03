## Why

Con el vector store ya decidido (S3 Vectors, Fase 3a), toca crear el corazón del
RAG: un **Amazon Bedrock Knowledge Base** que ingesta los documentos del bucket
`raw/`, los trocea, los convierte a embeddings con Titan y los guarda en un
índice de S3 Vectors. Es la Fase 3.

## What Changes

- **Módulo `terraform/modules/bedrock-kb/`** con:
  - `aws_s3vectors_vector_bucket` `${prefix}-vectors` (cifrado por defecto AES256).
  - `aws_s3vectors_index` `${prefix}-kb-index`: `data_type = "float32"`,
    `dimension = 1024` (Titan Text Embeddings v2), `distance_metric = "cosine"`,
    `metadata_configuration { non_filterable_metadata_keys =
    ["AMAZON_BEDROCK_TEXT", "AMAZON_BEDROCK_METADATA"] }` (obligatorio para KB).
  - `aws_iam_role` de la KB + `aws_iam_role_policy` de **mínimo privilegio**:
    - trust a `bedrock.amazonaws.com` con condiciones `aws:SourceAccount` +
      `aws:SourceArn` (guarda contra confused deputy).
    - `bedrock:InvokeModel` solo sobre el ARN de Titan Embeddings v2.
    - `s3:GetObject` + `s3:ListBucket` solo sobre el bucket de documentos
      (`.../` y `.../raw/*`).
    - `s3vectors:GetIndex`, `s3vectors:QueryVectors`, `s3vectors:PutVectors`,
      `s3vectors:GetVectors`, `s3vectors:DeleteVectors`, `s3vectors:ListVectors`
      solo sobre el ARN del bucket/índice de vectores.
  - `aws_bedrockagent_knowledge_base`:
    `knowledge_base_configuration { type = "VECTOR",
    vector_knowledge_base_configuration { embedding_model_arn = <Titan v2>,
    embedding_model_configuration { bedrock_embedding_model_configuration {
    dimensions = 1024, embedding_data_type = "FLOAT32" } } } }` y
    `storage_configuration { type = "S3_VECTORS", s3_vectors_configuration {
    index_arn = ... } }`.
  - `aws_bedrockagent_data_source`: `data_source_configuration { type = "S3",
    s3_configuration { bucket_arn = <docs>, inclusion_prefixes = ["raw/"] } }`,
    `vector_ingestion_configuration { chunking_configuration { chunking_strategy
    = "FIXED_SIZE", fixed_size_chunking_configuration { max_tokens = 512,
    overlap_percentage = 20 } } }`, `data_deletion_policy = "DELETE"`.
  - Outputs: `knowledge_base_id`, `knowledge_base_arn`, `data_source_id`,
    `vector_index_arn`, `vector_bucket_name`.
- **`terraform/environments/dev/`**: `module "bedrock_kb"` (pasando el ARN y
  nombre del bucket de documentos de `module.s3_documents`); nuevos outputs
  `knowledge_base_id`, `data_source_id`.
- **`scripts/sync-knowledge-base.sh`**: helper que dispara
  `aws bedrock-agent start-ingestion-job` con el KB id y el data source id
  (se usa en la Fase 6, cuando haya documentos).
- **`Makefile`**: el target `invoke` sigue siendo stub; sin cambios aquí.
- **`docs/runbook.md`**: sección "Fase 3" (apply, verificación de la KB,
  nota de que la ingesta se corre en la Fase 6).
- **`docs/architecture.md`**: marcar Fase 3b hecha; anotar `dimension = 1024`
  (inmutable) y el requisito de model access de Titan.

## Capabilities

### New Capabilities

- `semantic-retrieval`: existe una base de conocimiento consultable que, dada
  una pregunta, puede devolver los fragmentos de documento más relevantes con
  atribución a su fuente. Esta fase aporta la **infraestructura** (la KB, su
  índice de vectores, su data source y su rol). La llamada `Retrieve` desde la
  Lambda es la Fase 4.

### Modified Capabilities

- `document-ingestion`: se **concreta** el requisito `Vector store gestionado
  para los embeddings` (ahora nombra S3 Vectors: bucket + índice, `cosine`,
  `dimension` = dimensión del modelo de embeddings, claves de metadatos no
  filtrables de Bedrock) y se **añade** un requisito de **configuración de
  ingesta** (chunking fijo 512 tokens / 20% overlap, embeddings con Titan Text
  Embeddings v2, fuente = prefijo `raw/` del bucket de documentos).

## Impact

- **Nuevos archivos**: `terraform/modules/bedrock-kb/{main,variables,outputs,
  README}.tf|md`, `scripts/sync-knowledge-base.sh`.
- **Modificados**: `terraform/environments/dev/{main,outputs}.tf`,
  `docs/runbook.md`, `docs/architecture.md`, dos specs.
- **AWS** (`us-east-1`, cuenta 034703319129): 1 bucket de S3 Vectors, 1 índice,
  1 rol IAM + su policy, 1 Knowledge Base, 1 data source. Costo: S3 Vectors
  pay-as-you-go (centavos para la demo); la KB en sí no cuesta, solo las
  llamadas de embeddings/consulta que se cobran por token.
- **Requisito manual**: el acceso al modelo **Titan Text Embeddings v2** debe
  estar habilitado en Bedrock para la cuenta (los modelos de Amazon suelen
  venir habilitados por defecto; se verifica en el runbook).
- **Sin ingesta todavía**: no hay documentos en `raw/`. El `start-ingestion-job`
  se ejecuta en la Fase 6 con los documentos ficticios.
- **`dimension = 1024` es inmutable**: cambiarla luego obliga a recrear el
  índice (y re-ingestar). Se elige 1024 (calidad por defecto de Titan v2); 256
  sería más barato en storage — se documenta como palanca.
