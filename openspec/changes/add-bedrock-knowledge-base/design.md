## Context

Ver `proposal.md` - Why y los specs. Estado: el stack `dev` tiene solo
`module.s3_documents` (bucket `rag-serverless-demo-docs-483f7fb2`). Provider AWS
`~> 6.0` (v6.62.0). Sintaxis de S3 Vectors + Bedrock KB confirmada contra la
doc del provider (`aws_s3vectors_vector_bucket`, `aws_s3vectors_index`,
`aws_bedrockagent_knowledge_base` con `storage_configuration { type =
"S3_VECTORS" }`, `aws_bedrockagent_data_source`).

Restricciones inmutables de S3 Vectors: `dimension`, `distance_metric` y las
claves de metadatos no filtrables no se pueden cambiar tras crear el índice.

## Goals / Non-Goals

**Goals:**

- Módulo `bedrock-kb` reutilizable que crea el vector store S3 Vectors, la KB,
  su data source y su rol IAM de mínimo privilegio.
- `terraform apply` del stack `dev` que deja la KB en estado consultable.
- Rol de la KB sin `Action: "*"`, con trust acotado a Bedrock+cuenta.

**Non-Goals:**

- No se suben documentos ni se corre `start-ingestion-job` (Fase 6).
- No se hace la llamada `Retrieve`/`RetrieveAndGenerate` (Fase 4).
- No se crea la Lambda ni su rol (Fase 5).
- No se habilita el acceso al modelo Titan por Terraform (no hay recurso
  fiable; se verifica a mano — ver DD5).

## Decisions

### DD1 - `dimension = 1024` (Titan Text Embeddings v2, por defecto)

El índice y `embedding_model_configuration.bedrock_embedding_model_configuration.
dimensions` se fijan ambos a **1024**.

- **Por qué**: es la dimensión por defecto de Titan v2 y la de mejor calidad.
- **Alternativa - 256**: ~4x menos storage en S3 Vectors y consultas más
  rápidas, con una pérdida de recall moderada. Como el índice es inmutable, se
  documenta como palanca de costo pero no se usa: para una demo con pocos
  documentos el ahorro es irrelevante y la calidad importa más en vivo.
- Variable `embedding_dimension` (default 1024) para no tener el número
  hardcodeado en dos sitios.

### DD2 - Claves de metadatos no filtrables obligatorias

`aws_s3vectors_index.metadata_configuration.non_filterable_metadata_keys =
["AMAZON_BEDROCK_TEXT", "AMAZON_BEDROCK_METADATA"]`.

- **Por qué**: Bedrock KB escribe el texto del chunk y su metadata bajo esas
  claves; si son filtrables, la creación de la KB o la ingesta fallan. Es un
  requisito documentado de la integración, no una opción.

### DD3 - Rol IAM de la KB: trust acotado + permisos enumerados

- **Trust**: `Service = "bedrock.amazonaws.com"`, con
  `Condition.StringEquals["aws:SourceAccount"] = <account_id>` y
  `Condition.ArnLike["aws:SourceArn"] =
  "arn:aws:bedrock:us-east-1:<account>:knowledge-base/*"` (no se puede
  referenciar el ARN exacto de la KB por dependencia circular; se acota al
  patrón de KBs de la cuenta/región).
- **Permisos** (documento de política, un statement por recurso):
  - `bedrock:InvokeModel` → `arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0`
  - `s3:ListBucket` → ARN del bucket de documentos, con
    `Condition.StringLike["s3:prefix"] = ["raw/*"]`
  - `s3:GetObject` → `<docs-bucket-arn>/raw/*`
  - `s3vectors:GetIndex`, `QueryVectors`, `PutVectors`, `GetVectors`,
    `DeleteVectors`, `ListVectors` → ARN del vector bucket y del índice
- **Sin** `Action: "*"`, **sin** `Resource: "*"`.
- **Alternativa - usar una AWS managed policy**: no hay una acotada a este caso;
  las genéricas de Bedrock son demasiado amplias. Rechazada.

### DD4 - Data source: S3 `raw/`, FIXED_SIZE 512/20%, `data_deletion_policy = DELETE`

```
data_source_configuration {
  type = "S3"
  s3_configuration {
    bucket_arn         = <docs bucket arn>
    inclusion_prefixes = ["raw/"]
  }
}
vector_ingestion_configuration {
  chunking_configuration {
    chunking_strategy = "FIXED_SIZE"
    fixed_size_chunking_configuration {
      max_tokens         = 512
      overlap_percentage = 20
    }
  }
}
data_deletion_policy = "DELETE"
```

- **`DELETE`**: al destruir el data source, se borran los vectores ingestados.
  Es lo correcto para la demo (destroy/re-apply limpio de la Fase 7).
  `RETAIN` dejaría vectores huérfanos en el índice.
- `inclusion_prefixes = ["raw/"]`: `processed/` queda fuera de la ingesta.

### DD5 - Model access de Titan: verificación manual

No hay un recurso de Terraform fiable para "habilitar acceso al modelo" en
Bedrock. Los modelos de Amazon (Titan, Nova) suelen venir habilitados por
defecto en cuentas nuevas. El runbook incluye la verificación:
`aws bedrock list-foundation-models` + intentar un `invoke-model` de prueba, o
mirar "Model access" en la consola. Si Titan v2 no estuviera habilitado, el
`apply` de la KB falla con `AccessDeniedException` y hay que habilitarlo en la
consola (1 clic) y reintentar.

### DD6 - Un módulo `bedrock-kb` con todo dentro

El vector store, la KB, el data source y el rol IAM viven juntos en
`terraform/modules/bedrock-kb/`. Coherente con D2 del repo ("el rol vive en el
módulo del servicio al que sirve"). El módulo recibe el ARN y el nombre del
bucket de documentos como variables.

### DD7 - Nombres

- Vector bucket: `${prefix}-vectors` (S3 Vectors bucket names: 3-63 chars,
  minúsculas, `-`; global por región/cuenta, no global mundial → sin `random_id`).
- Índice: `${prefix}-kb-index`.
- KB: `${prefix}-kb`. Data source: `${prefix}-kb-s3`.
- Rol: `${prefix}-kb-role`.

## Risks / Trade-offs

- **[Titan v2 sin model access]** → `apply` falla claro; se habilita en consola
  y se reintenta. Documentado en DD5 / runbook.
- **[S3 Vectors no disponible en `us-east-1`]** → Está GA y disponible en
  us-east-1; si el `plan` fallara por región, se para. (Verificado: GA
  2-dic-2025, us-east-1 entre las regiones de lanzamiento.)
- **[`aws:SourceArn` con comodín es más laxo de lo ideal]** → Se acota a
  `knowledge-base/*` de la cuenta/región; no se puede el ARN exacto por
  dependencia circular. Aceptable; el `aws:SourceAccount` ya limita a la cuenta.
- **[La KB queda vacía hasta la Fase 6]** → Por diseño. El escenario "Retrieve
  devuelve fragmentos" del spec `semantic-retrieval` se valida en la Fase 6,
  no aquí; aquí solo se valida "la KB está disponible".
- **[Dimensión inmutable elegida mal]** → 1024 es la opción segura por defecto;
  si en el futuro se quiere 256, se recrea índice + KB + se re-ingesta (barato
  en la demo).

## Migration Plan

1. Escribir el módulo `bedrock-kb` y cablearlo en `environments/dev`.
2. `terraform -chdir=terraform/environments/dev init` (nuevo módulo) + `validate`.
3. `plan` → debe añadir: vector bucket, índice, rol + policy, KB, data source
   (~5-6 recursos), 0 destroy. **PARA** para Miguel.
4. Verificar model access de Titan (DD5).
5. Con OK: `apply` (lo corre Miguel). La KB puede tardar 1-2 min en quedar
   `ACTIVE`.
6. Verificaciones (`tasks.md`); `scripts/sync-knowledge-base.sh`; docs; commit;
   archivar (sync de specs).

Rollback: `terraform destroy` del módulo (o `git revert` + apply). Como el data
source es `DELETE` y no hay ingesta, el destroy es limpio.

## Open Questions

- ¿Se fija `embedding_data_type = "FLOAT32"` explícito o se deja el default?
  Se fija explícito para que coincida con `data_type = "float32"` del índice;
  sin impacto de diseño.
