# Módulo `s3-documents`

Crea el bucket S3 privado para los documentos fuente del caso de uso ficticio:
versionado, block public access (4 flags), cifrado SSE-S3, ownership
`BucketOwnerEnforced`. Fija los prefijos `raw/` (documentos originales) y
`processed/` (reservado) con objetos `.keep` vacíos.

| Input | Descripción |
|-------|-------------|
| `name_prefix` | Prefijo del nombre. El bucket queda `<name_prefix>-docs-<hex>`. |
| `tags` | Tags (opcional). |

| Output | Descripción |
|--------|-------------|
| `bucket_name` | Nombre del bucket. |
| `bucket_arn` | ARN del bucket. |
