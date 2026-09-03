## 1. Quitar RDS del stack (código)

- [x] 1.1 En `terraform/environments/dev/main.tf`: eliminar el bloque `module "rds_pgvector"` (dejar solo `module "s3_documents"` y `locals`)
- [x] 1.2 En `terraform/environments/dev/outputs.tf`: eliminar `db_host`, `db_port`, `db_name`, `db_secret_arn`, `db_security_group_id` (dejar `documents_bucket_name`)
- [x] 1.3 En `terraform/environments/dev/variables.tf`: eliminar `admin_cidr` (dejar `tags`)
- [x] 1.4 `terraform -chdir=terraform/environments/dev fmt -check`

## 2. Provider a v6

- [x] 2.1 `terraform/bootstrap/versions.tf`, `terraform/modules/s3-documents/main.tf`, `terraform/environments/dev/versions.tf`: cambiar `version = "~> 5.0"` → `"~> 6.0"` para `hashicorp/aws` (en `bootstrap` mantener `random ~> 3.0`)
- [x] 2.2 `terraform -chdir=terraform/environments/dev init -upgrade` → instala aws v6.x; `.terraform.lock.hcl` actualizado
- [x] 2.3 `terraform -chdir=terraform/bootstrap init -upgrade`; `.terraform.lock.hcl` actualizado
- [x] 2.4 `terraform -chdir=terraform/environments/dev validate` → Success

## 3. Plan del destroy (requiere aprobación de Miguel)

- [x] 3.1 `terraform -chdir=terraform/environments/dev plan` → debe listar **solo** `module.rds_pgvector.*` a destruir (instancia, parameter group, subnet group, security group, reglas de ingress/egress) y **0 cambios** en `module.s3_documents`. Mostrar a Miguel. **PARA hasta OK explícito**
- [x] 3.2 `terraform -chdir=terraform/bootstrap plan` → debe ser "No changes" (verifica que el upgrade a v6 no toca el bucket de state ni la tabla de lock). Si hay diff, **PARA** y documentar

## 4. Apply del destroy + verificación

- [x] 4.1 Con aprobación: `AWS_PROFILE=personal terraform -chdir=terraform/environments/dev apply` (lo corre Miguel); confirmar N destroy, 0 add, 0 change
- [x] 4.2 Verificar en AWS que ya no existen: `aws rds describe-db-instances --db-instance-identifier rag-serverless-demo-pgvector` → `DBInstanceNotFound`; `aws ec2 describe-security-groups --filters Name=group-name,Values=rag-serverless-demo-db` → vacío; `aws secretsmanager list-secrets` → sin el secreto `rds!db-...` de esta instancia
- [x] 4.3 Verificar que el bucket de documentos sigue: `aws s3api head-bucket --bucket rag-serverless-demo-docs-483f7fb2`

## 5. Borrar el módulo y limpiar

- [x] 5.1 `git rm -r terraform/modules/rds-pgvector/` (recrear `.gitkeep`? no — la carpeta desaparece; la lista de módulos vivos queda `s3-documents`, `bedrock-kb`, `agent-lambda`, `iam`)
- [x] 5.2 `terraform/environments/dev/terraform.tfvars` (gitignored): dejar solo comentario o `tags`, quitar `admin_cidr`
- [x] 5.3 `terraform -chdir=terraform/environments/dev plan` final → "No changes"

## 6. Docs y config

- [x] 6.1 `docs/runbook.md`: en la sección Fase 2, marcar "Setup de pgvector" como **obsoleto** con una nota del cambio de decisión (KB gestionado ⇒ S3 Vectors; ver Fase 3)
- [x] 6.2 `docs/architecture.md`: diagrama y lista de módulos sin `rds-pgvector`; el vector store pasa a "S3 Vectors (Fase 3b)"; tabla de mapeo: Fase 3 = `switch-vector-store-to-s3-vectors` (3a) + `add-bedrock-knowledge-base` (3b); actualizar el caveat de RDS público (ya no aplica)
- [x] 6.3 `openspec/config.yaml`: en `context`, reemplazar el bloque "RDS PostgreSQL + pgvector ... NO uso Aurora ni OpenSearch Serverless" por "Amazon S3 Vectors como vector store del Bedrock KB gestionado (sin instancia de BD; RDS no sirve porque el KB exige Data API = solo Aurora)"

## 7. Cierre

- [x] 7.1 `openspec validate switch-vector-store-to-s3-vectors --strict` pasa
- [x] 7.2 `git status`: entran los `.tf` modificados, los `.terraform.lock.hcl`, docs, config; se registra el borrado de `terraform/modules/rds-pgvector/`; NO entra `.terraform/` ni state
- [x] 7.3 Commit único "Fase 3a: retirar RDS/pgvector, vector store pasa a S3 Vectors, provider a v6" con `Co-Authored-By`
- [x] 7.4 Archivar con `/openspec-archive-change switch-vector-store-to-s3-vectors` — el sync aplica el REMOVED/ADDED en `document-ingestion` y el MODIFIED en `infra-reproducibility`, y edita a mano el `## Purpose` de `document-ingestion` (DD4)
