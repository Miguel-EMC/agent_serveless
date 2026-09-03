## Why

El agente RAG necesita dos almacenes antes de poder ingestar nada: un lugar para
los documentos fuente (S3) y una base vectorial (PostgreSQL + pgvector). Esta es
la Fase 2. Al cablear estos módulos en `environments/dev/` se corre además el
**primer `terraform init` del stack** contra el backend `s3` creado en la Fase 1.

## What Changes

- **Módulo `terraform/modules/s3-documents/`**:
  - Bucket S3 privado para los documentos del caso de uso ficticio: versionado
    activado, `public_access_block` (4 flags), cifrado SSE-S3, ownership
    `BucketOwnerEnforced`.
  - Estructura de prefijos sugerida: `raw/` (documentos originales) y
    `processed/` (reservado para futuro). Se crean objetos `.keep` vacíos para
    fijar los prefijos.
  - Outputs: nombre y ARN del bucket.

- **Módulo `terraform/modules/rds-pgvector/`**:
  - Instancia `aws_db_instance` PostgreSQL, `db.t3.micro`, 20 GB `gp3`,
    `engine_version` 16.x, `multi_az = false`, `storage_encrypted = true`,
    `deletion_protection = false` (demo), `skip_final_snapshot = true`,
    `auto_minor_version_upgrade = true`, `backup_retention_period = 1`.
  - `aws_db_subnet_group` construido con subredes de la **VPC default** de la
    cuenta (data sources) — ver `design.md` DD1.
  - `aws_security_group` para la instancia: **sin reglas de ingress abiertas al
    mundo**. Ingress al puerto 5432 desde (a) el security group de la Lambda
    (se referencia por `var.agent_security_group_id`, que llega vacío en esta
    fase y se conecta en la Fase 5) y (b) un `var.admin_cidr` opcional para el
    setup único de pgvector y para inspección — ver `design.md` DD2.
  - Credenciales: master username fijo (`ragadmin`) y
    `manage_master_user_password = true` — RDS genera la contraseña y la
    gestiona en un secreto de **AWS Secrets Manager**; la contraseña nunca
    entra al state de Terraform. Ver `design.md` DD4.
  - `parameter_group` propio con `rds.force_ssl = 1` (conexiones TLS
    obligatorias).
  - Outputs: endpoint (host), puerto, nombre de la BD, ARN del secreto
    gestionado por RDS, id del security group de la instancia.

- **La extensión `pgvector` NO se instala desde Terraform.** Se ejecuta
  `CREATE EXTENSION IF NOT EXISTS vector;` una sola vez con `psql`, documentado
  en `docs/runbook.md` (Fase 2). Alternativas evaluadas en `design.md` DD3.

- **`terraform/environments/dev/main.tf`**: instancia los dos módulos
  (`module "s3_documents"`, `module "rds_pgvector"`), pasando `admin_cidr` desde
  una variable. `terraform/environments/dev/variables.tf` y
  `terraform.tfvars` (no secreto: `admin_cidr`, tags) + `terraform.tfvars.example`.

- **Primer `terraform init` + `apply` del stack `dev`** contra el backend `s3`.
  Lo ejecuta Miguel con `AWS_PROFILE=personal`, tras ver el plan.

- `Makefile`: implementar el target `deploy` (`terraform -chdir=terraform/environments/dev init` + `apply`).

- `docs/runbook.md`: sección "Fase 2" (init del stack, apply, setup de pgvector
  con `psql`, verificación `\dx`).

## Capabilities

### New Capabilities

- `document-ingestion`: cubre la preparación y disponibilidad del material que
  la Knowledge Base va a ingestar. Esta fase añade los requisitos de
  **infraestructura de almacenamiento**: un bucket S3 privado y versionado para
  los documentos fuente, y una base PostgreSQL con la extensión `pgvector`
  disponible como vector store, con credenciales solo en Secrets Manager y
  acceso de red restringido. La Fase 3 añadirá a esta capability los requisitos
  de chunking/embeddings.

### Modified Capabilities

- `infra-reproducibility`: se añade un requisito — el stack `dev` se aplica y
  se re-aplica desde cero usando el backend `s3` de la Fase 1 (antes el
  requisito "El stack principal usa el remote backend" describía el `init`;
  ahora se complementa con "apply reproducible del stack").

## Impact

- **Nuevos archivos**: `terraform/modules/s3-documents/*.tf`,
  `terraform/modules/rds-pgvector/*.tf`,
  `terraform/environments/dev/{main,variables,outputs}.tf`,
  `terraform/environments/dev/terraform.tfvars(.example)`.
- **Modificados**: `Makefile` (target `deploy`), `docs/runbook.md`,
  `openspec/specs/infra-reproducibility/spec.md` (delta).
- **AWS** (en `us-east-1`, cuenta 034703319129): 1 bucket S3; 1 instancia RDS
  `db.t3.micro` (free tier: 750 h/mes los primeros 12 meses; 20 GB gp3 dentro
  de los 20 GB free tier); 1 secreto en Secrets Manager (~$0.40/mes); 1 DB
  subnet group; 1 security group. Sin NAT, sin VPC nueva.
- **State del stack**: pasa a vivir en
  `s3://rag-serverless-demo-tfstate-777a8ea1/dev/terraform.tfstate` con locking
  en `rag-serverless-demo-tflock`.
- **Confidencialidad**: documentos ficticios; nombres genéricos; ningún dato
  real. Los 2-3 documentos de ejemplo se generan en la Fase 6, no aquí.
- **Dependencia manual**: para el `CREATE EXTENSION` hace falta `psql` y que
  `admin_cidr` incluya la IP de Miguel durante el setup.
