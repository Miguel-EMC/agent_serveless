## Why

La Fase 2 levantó un RDS PostgreSQL `db.t3.micro` + pgvector como vector store,
partiendo de la arquitectura original. Al investigar la Fase 3 se confirmó que
el **Bedrock Knowledge Base gestionado no puede usar un RDS estándar** como
vector store: su integración con PostgreSQL exige la **RDS Data API**, que solo
existe en Aurora. Miguel decidió usar **Amazon S3 Vectors** como vector store
del KB gestionado (más serverless, escala a cero, ~90% más barato que
OpenSearch, Terraform de punta a punta).

Este cambio **retira** la infraestructura de RDS que quedó sin uso, antes de
construir el KB en `add-bedrock-knowledge-base`. El bucket de documentos de la
Fase 2 se conserva.

## What Changes

- `terraform destroy` selectivo de los recursos de `rds-pgvector` en el stack
  `dev` (instancia RDS, parameter group, subnet group, security group + reglas;
  el secreto lo elimina RDS al borrar la instancia).
- Borrar el módulo `terraform/modules/rds-pgvector/` completo.
- `terraform/environments/dev/`: quitar `module "rds_pgvector"`, la variable
  `admin_cidr`, y los outputs `db_host` / `db_port` / `db_name` /
  `db_secret_arn` / `db_security_group_id`. El stack queda solo con
  `module "s3_documents"` hasta la Fase 3b.
- Subir el pin del provider AWS de `~> 5.0` a `~> 6.0` en las 4 raíces/módulos
  (`bootstrap`, `s3-documents`, `environments/dev`; el módulo `rds-pgvector` se
  borra). `terraform init -upgrade` en `bootstrap` y `dev`; commitear los
  `.terraform.lock.hcl` actualizados.
- `Makefile`: el target `destroy` ya existe y sirve; sin cambios.
- `docs/runbook.md`: marcar la sección de setup de pgvector de la Fase 2 como
  obsoleta y explicar el cambio de decisión.
- `docs/architecture.md`: actualizar el diagrama y la lista de módulos
  (`rds-pgvector` fuera; el vector store pasa a S3 Vectors, a implementar en 3b);
  actualizar la tabla de mapeo (Fase 3 = 3a + 3b).
- `openspec/config.yaml`: actualizar el `context` — el vector store ya no es
  "RDS PostgreSQL + pgvector"; es "Amazon S3 Vectors como vector store del
  Bedrock KB gestionado".

## Capabilities

### Modified Capabilities

- `document-ingestion`: se **eliminan** los requisitos ligados a una base de
  datos relacional (`Base vectorial PostgreSQL con pgvector`, `Credenciales de
  la base de datos gestionadas en Secrets Manager`, `Acceso de red restringido
  a la base de datos`) y se **reemplazan** por un requisito neutro de vector
  store gestionado, que `add-bedrock-knowledge-base` detallará. Se conserva
  `Bucket privado y versionado para documentos fuente`.
- `infra-reproducibility`: se **modifica** el requisito `El stack de aplicación
  se aplica desde cero de forma reproducible` — el escenario ya no enumera
  "base vectorial, secreto, grupos de seguridad y subredes"; el stack `dev`
  ahora es el bucket de documentos (y, tras 3b, el vector store + la KB).

### New Capabilities

Ninguna.

## Impact

- **Borrados**: `terraform/modules/rds-pgvector/` (5 archivos);
  `terraform/environments/dev/variables.tf` (queda solo `tags`); outputs de RDS.
- **Modificados**: `terraform/environments/dev/{main,outputs,versions}.tf`,
  `terraform/bootstrap/versions.tf`, `terraform/modules/s3-documents/main.tf`
  (pin del provider), los `.terraform.lock.hcl`, `docs/runbook.md`,
  `docs/architecture.md`, `openspec/config.yaml`, dos specs.
- **AWS**: se destruyen la instancia RDS `rag-serverless-demo-pgvector`, su
  secreto gestionado, el parameter group, el subnet group y el security group.
  Deja de sumar horas de free tier. El bucket
  `rag-serverless-demo-docs-483f7fb2` y el backend de la Fase 1 quedan intactos.
- **Provider v6**: cambio mayor del provider AWS. Los recursos que usamos
  (`aws_s3_bucket*`, `aws_dynamodb_table`) son estables entre v5 y v6; el
  `plan` tras el upgrade debe salir sin diffs para el bucket de state ni el de
  documentos.
- **`terraform.tfvars`** (gitignored) queda con un `admin_cidr` que ya no se
  usa; se puede vaciar o dejar, no afecta.
