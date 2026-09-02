## Why

Terraform necesita un lugar compartido y con bloqueo para su state antes de
crear cualquier otro recurso: el stack principal (`terraform/environments/dev/`)
va a usar backend `s3`, y ese backend requiere un bucket y una tabla de lock
que todavía no existen. Esta es la Fase 1 y es la base de la que dependen todas
las demás.

## What Changes

- Crear la raíz Terraform `terraform/bootstrap/` con `.tf` reales:
  - provider AWS fijado a `us-east-1`, con `required_version` y
    `required_providers` (AWS `~> 5.x`).
  - `random_id` (8 bytes) para el sufijo único del nombre del bucket.
  - Bucket S3 `rag-serverless-demo-tfstate-<hex>` con: versionado activado,
    `aws_s3_bucket_public_access_block` (los 4 flags en `true`), cifrado en
    reposo con SSE-S3 (`aws_s3_bucket_server_side_encryption_configuration`),
    y `aws_s3_bucket_ownership_controls` en `BucketOwnerEnforced`.
  - Tabla DynamoDB `rag-serverless-demo-tflock` con `billing_mode`
    `PAY_PER_REQUEST` y clave primaria `LockID` (tipo `S`).
  - `outputs.tf`: nombre del bucket, ARN del bucket, nombre de la tabla, región.
- El bootstrap usa **state local**. Tras el `apply`, se commitea
  `terraform/bootstrap/terraform.tfstate` (sin secretos: solo nombres, ARNs y
  el sufijo aleatorio). Ver `design.md` para el porqué y la alternativa.
- Crear `terraform/environments/dev/backend.tf` con el bloque `backend "s3"`
  apuntando al bucket y la tabla (`key = "dev/terraform.tfstate"`,
  `encrypt = true`, `dynamodb_table = ...`). El stack aún no tiene recursos;
  `terraform init` del stack se corre cuando la Fase 2 agregue el primer módulo.
- Crear `terraform/environments/dev/providers.tf` (provider AWS `us-east-1`) y
  `terraform/environments/dev/versions.tf` (`required_version`,
  `required_providers`).
- Implementar el target `bootstrap` del `Makefile` (`terraform -chdir=... init`
  + `apply`) reemplazando el stub.
- Añadir `terraform/bootstrap/.terraform.lock.hcl` al control de versiones
  (se versiona; ya está permitido por `.gitignore`).
- Documentar el procedimiento en `docs/runbook.md` (sección "Fase 1 /
  bootstrap": cómo se corre, qué crea, cómo se destruye — y que normalmente
  NO se destruye).

Sin API Gateway, sin recursos de aplicación. Un solo `terraform apply`, en
`terraform/bootstrap/`, tras mostrar el plan y con aprobación de Miguel.

## Capabilities

### New Capabilities

- `infra-reproducibility`: la infraestructura del proyecto se levanta y se
  vuelve a levantar desde cero de forma determinista con Terraform. Esta fase
  introduce los requisitos del **backend de estado**: creación del remote state
  (bucket S3 versionado + privado) y del locking (DynamoDB), reproducibilidad
  del propio bootstrap, y separación de ciclo de vida entre el bootstrap y el
  stack principal. Fases posteriores añadirán requisitos a esta misma
  capability (destroy/apply del stack completo, cronometraje).

### Modified Capabilities

Ninguna (no hay specs previas).

## Impact

- **Nuevos archivos**: `terraform/bootstrap/{versions,providers,main,outputs}.tf`,
  `terraform/bootstrap/.terraform.lock.hcl`, `terraform/bootstrap/terraform.tfstate`
  (tras apply), `terraform/environments/dev/{versions,providers,backend}.tf`,
  `docs/runbook.md`.
- **Modificados**: `Makefile` (target `bootstrap`).
- **AWS**: se crean 1 bucket S3 y 1 tabla DynamoDB en `us-east-1`. Costo
  ~cero (S3 con unos KB de state; DynamoDB PAY_PER_REQUEST con tráfico mínimo).
- **Dependencias**: requiere credenciales AWS con permiso para crear el bucket
  y la tabla (paso manual de Miguel; el bootstrap no gestiona IAM de usuarios).
- **Confidencialidad**: nombres genéricos (`rag-serverless-demo-*`), sin
  referencia a ninguna empresa real.
