## 1. Módulo s3-documents

- [x] 1.1 `terraform/modules/s3-documents/variables.tf`: `name_prefix` (string), `tags` (map, default `{}`); eliminar el `.gitkeep`
- [x] 1.2 `terraform/modules/s3-documents/main.tf`: `random_id.suffix` (4 bytes); `aws_s3_bucket` `${var.name_prefix}-docs-${random_id.suffix.hex}`; `aws_s3_bucket_versioning` (Enabled); `aws_s3_bucket_public_access_block` (4 flags true); `aws_s3_bucket_server_side_encryption_configuration` (AES256); `aws_s3_bucket_ownership_controls` (BucketOwnerEnforced); dos `aws_s3_object` vacíos con key `raw/.keep` y `processed/.keep`
- [x] 1.3 `terraform/modules/s3-documents/outputs.tf`: `bucket_name`, `bucket_arn`
- [x] 1.4 `terraform/modules/s3-documents/README.md` (1 párrafo: qué crea, inputs/outputs)
- [x] 1.5 `terraform fmt` del módulo; sin cambios pendientes en `git status`

## 2. Módulo rds-pgvector

- [x] 2.1 `terraform/modules/rds-pgvector/variables.tf`: `name_prefix` (string); `db_name` (default `"ragdb"`); `master_username` (default `"ragadmin"`); `instance_class` (default `"db.t3.micro"`); `allocated_storage` (default `20`); `engine_version` (default `"16"` — pinned; `null` haría que RDS eligiera PG18 y rompería la familia del parameter group); `agent_security_group_id` (default `null`); `admin_cidr` (default `null`, con `validation` que rechaza `"0.0.0.0/0"`); `tags` (map, default `{}`). Eliminar el `.gitkeep`. El `family`/`name` del parameter group derivan del major (`local.postgres_major`); `rds.force_ssl` con `apply_method = "pending-reboot"` (parámetro estático)
- [x] 2.2 `terraform/modules/rds-pgvector/main.tf` — red: `data "aws_vpc" "default" { default = true }`, `data "aws_subnets" "default"` (filter vpc-id), `aws_db_subnet_group.this` con esas subredes
- [x] 2.3 `terraform/modules/rds-pgvector/main.tf` — SG: `aws_security_group.db` en la VPC default, **sin ingress inline**; `aws_vpc_security_group_ingress_rule` para 5432 desde `agent_security_group_id` (con `count` si no es null) y otro desde `admin_cidr` (si no es null); `aws_vpc_security_group_egress_rule` all-egress
- [x] 2.4 `terraform/modules/rds-pgvector/main.tf` — parámetros: `aws_db_parameter_group.this` (`family = "postgres16"`, parámetro `rds.force_ssl = "1"`)
- [x] 2.5 `terraform/modules/rds-pgvector/main.tf` — instancia: `aws_db_instance.this` con `engine = "postgres"`, `instance_class`, `allocated_storage`, `storage_type = "gp3"`, `storage_encrypted = true`, `db_name`, `username = var.master_username`, `manage_master_user_password = true`, `db_subnet_group_name`, `vpc_security_group_ids = [aws_security_group.db.id]`, `parameter_group_name`, `publicly_accessible = true`, `multi_az = false`, `backup_retention_period = 1`, `skip_final_snapshot = true`, `deletion_protection = false`, `auto_minor_version_upgrade = true`, `apply_immediately = true`
- [x] 2.6 `terraform/modules/rds-pgvector/outputs.tf`: `db_host` (address), `db_port`, `db_name`, `master_user_secret_arn` (`aws_db_instance.this.master_user_secret[0].secret_arn`), `security_group_id`
- [x] 2.7 `terraform/modules/rds-pgvector/README.md` (qué crea; nota de DD2/DD3: SG restrictivo + pgvector se instala aparte)
- [x] 2.8 `terraform fmt` del módulo; `git status` limpio

## 3. Stack environments/dev

- [x] 3.1 `terraform/environments/dev/variables.tf`: `admin_cidr` (default `null`), `tags` (default con `Project`/`Environment`)
- [x] 3.2 `terraform/environments/dev/main.tf`: `module "s3_documents"` (name_prefix `rag-serverless-demo`, tags) y `module "rds_pgvector"` (name_prefix, `admin_cidr = var.admin_cidr`, `agent_security_group_id = null`, tags)
- [x] 3.3 `terraform/environments/dev/outputs.tf`: re-exporta `documents_bucket_name`, `db_host`, `db_port`, `db_name`, `db_secret_arn`, `db_security_group_id`
- [x] 3.4 `terraform.tfvars.example` versionado con un CIDR de ejemplo. `terraform/environments/dev/terraform.tfvars` (con la IP real de Miguel en `admin_cidr`) **se gitignora** (`terraform/environments/*/terraform.tfvars`): mejor no versionar una IP residencial. Sin secretos en ninguno.
- [x] 3.5 `terraform -chdir=terraform/environments/dev fmt -check`

## 4. Init del stack + validación estática

- [x] 4.1 `terraform -chdir=terraform/environments/dev init` contra el backend `s3` real → "Terraform has been successfully initialized!" (aviso de deprecación de `dynamodb_table` — ver nota; `dev/` sin objetos hasta el primer apply)
- [x] 4.2 `terraform -chdir=terraform/environments/dev validate` → Success
- [x] 4.3 `terraform/environments/dev/.terraform.lock.hcl` generado, no gitignored, se versiona

## 5. Apply (requiere aprobación de Miguel)

- [x] 5.1 `terraform -chdir=terraform/environments/dev plan` mostrado a Miguel; tras el fix de `engine_version` el plan quedó `1 to add` (la instancia)
- [x] 5.2 `apply` ejecutado por Miguel (`AWS_PROFILE=personal`, `-auto-approve`); `plan` posterior = "No changes"
- [x] 5.3 Setup de pgvector: `CREATE EXTENSION IF NOT EXISTS vector;` ejecutado vía `psql` con la contraseña de Secrets Manager y la IP de Miguel en `admin_cidr`
- [x] 5.4 Verificado: `\dx` lista `vector` 0.8.1; `aws rds describe-db-instances` → `db.t3.micro`, PostgreSQL `16.13`, `StorageEncrypted true`, `MultiAZ false`, `gp3`/20 GB, `available`; `aws ec2 describe-security-groups` → único ingress al 5432 es `181.196.72.229/32` (sin `0.0.0.0/0`); bucket de docs versionado, público bloqueado x4, prefijos `raw/` + `processed/`

## 6. Tooling y docs

- [x] 6.1 `Makefile`: `deploy` y `destroy` reales (`terraform -chdir=terraform/environments/dev ...`); `make -n deploy` / `make -n destroy` muestran los comandos
- [x] 6.2 `docs/runbook.md`: sección "Fase 2" (pre-check `admin_cidr`, permisos, `make deploy`, setup de pgvector con `psql` y fallback `docker run --rm postgres:16 psql`, verificación `\dx` + AWS, recordatorio de `make destroy`)
- [x] 6.3 `docs/architecture.md`: Fase 2 marcada como hecha en la tabla; caveats VPC default + RDS publicly_accessible anotados

## 7. Cierre

- [x] 7.1 `openspec validate add-document-and-vector-stores --strict` pasa
- [x] 7.2 `git status`: entran los `.tf` de módulos y stack, `.terraform.lock.hcl`, `terraform.tfvars.example`, `Makefile`, docs; NO entra ningún `.terraform/`, ni `terraform.tfstate` del stack, ni `terraform.tfvars` (gitignored)
- [x] 7.3 Commit único "Fase 2: modulos s3-documents y rds-pgvector + init del stack dev" con la línea `Co-Authored-By`; `git status` limpio
- [x] 7.4 Archivar con `/openspec-archive-change add-document-and-vector-stores` (sincroniza `document-ingestion` nuevo + delta de `infra-reproducibility`)
