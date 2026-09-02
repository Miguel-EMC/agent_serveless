## 1. Código Terraform del bootstrap

- [x] 1.1 Crear `terraform/bootstrap/versions.tf` con `required_version >= 1.5` y `required_providers` (`hashicorp/aws ~> 5.0`, `hashicorp/random ~> 3.0`); verificar con `terraform -chdir=terraform/bootstrap fmt -check`
- [x] 1.2 Crear `terraform/bootstrap/providers.tf` con `provider "aws" { region = var.region }` (sin `profile` ni credenciales hardcodeadas); verificar `fmt -check`
- [x] 1.3 Crear `terraform/bootstrap/variables.tf` con `prefix` (default `"rag-serverless-demo"`) y `region` (default `"us-east-1"`), ambas `type = string` con `description`
- [x] 1.4 Crear `terraform/bootstrap/main.tf`: `random_id.suffix` (byte_length 4); bucket `aws_s3_bucket` `${var.prefix}-tfstate-${random_id.suffix.hex}`; `aws_s3_bucket_versioning` (Enabled); `aws_s3_bucket_public_access_block` (4 flags true); `aws_s3_bucket_server_side_encryption_configuration` (AES256); `aws_s3_bucket_ownership_controls` (BucketOwnerEnforced); `aws_dynamodb_table` `${var.prefix}-tflock` (PAY_PER_REQUEST, hash_key `LockID`, attribute `LockID` type `S`). Verificar `terraform -chdir=terraform/bootstrap validate` tras `init -backend=false`
- [x] 1.5 Crear `terraform/bootstrap/outputs.tf`: `state_bucket_name`, `state_bucket_arn`, `lock_table_name`, `lock_table_arn`, `region`. Verificar que `validate` sigue pasando
- [x] 1.6 `terraform -chdir=terraform/bootstrap fmt` y confirmar árbol limpio con `git status`

## 2. Backend del stack principal (sin init)

- [x] 2.1 Crear `terraform/environments/dev/versions.tf` (mismos `required_version` / `required_providers` que el bootstrap, sin `random`)
- [x] 2.2 Crear `terraform/environments/dev/providers.tf` (`provider "aws" { region = "us-east-1" }`)
- [x] 2.3 Crear `terraform/environments/dev/backend.tf` con `terraform { backend "s3" { bucket = "<PENDIENTE: output del bootstrap>" key = "dev/terraform.tfstate" region = "us-east-1" dynamodb_table = "rag-serverless-demo-tflock" encrypt = true } }` — dejar el `bucket` con un placeholder comentado hasta la tarea 4.3
- [x] 2.4 Verificar `terraform -chdir=terraform/environments/dev fmt -check` pasa (no se corre `init`/`validate` del stack: aún sin recursos)

## 3. Ajustes de repo

- [x] 3.1 Añadir a `.gitignore`, después de las reglas `*.tfstate*`, las excepciones `!terraform/bootstrap/terraform.tfstate` y `!terraform/bootstrap/terraform.tfstate.backup`; verificar `git check-ignore -v terraform/bootstrap/terraform.tfstate` NO devuelve match (`git add --dry-run` lo acepta)
- [x] 3.2 Reemplazar el stub del target `bootstrap` en el `Makefile` por `terraform -chdir=terraform/bootstrap init` + `terraform -chdir=terraform/bootstrap apply`; verificar `make -n bootstrap` muestra los comandos
- [x] 3.3 Crear `docs/runbook.md` con la sección "Fase 1 - Bootstrap": pre-check (`aws sts get-caller-identity`), permisos mínimos necesarios, `make bootstrap`, cómo leer el nombre del bucket (`terraform -chdir=terraform/bootstrap output -raw state_bucket_name`), paso de commitear el state, y nota de que el bootstrap NO se destruye normalmente
- [x] 3.4 Verificar que `docs/runbook.md` explica por qué se commitea el `.tfstate` del bootstrap y que eso no aplica al stack `dev`

## 4. Aplicar (requiere aprobación de Miguel)

- [x] 4.1 `terraform -chdir=terraform/bootstrap init` y luego `plan`; mostrar el plan a Miguel. **PARA hasta OK explícito** (plan: 7 to add, 0 change, 0 destroy)
- [x] 4.2 Con aprobación: `terraform -chdir=terraform/bootstrap apply` (ejecutado por Miguel con `AWS_PROFILE=personal`); creó 7 recursos, 0 change, 0 destroy
- [x] 4.3 Leer `terraform -chdir=terraform/bootstrap output -raw state_bucket_name` (`rag-serverless-demo-tfstate-777a8ea1`) y ponerlo en `bucket` de `terraform/environments/dev/backend.tf`; `fmt -check` OK
- [x] 4.4 Verificado en AWS: versioning `Enabled`, block public access x4 `true`, cifrado `AES256`, ownership `BucketOwnerEnforced`; tabla `rag-serverless-demo-tflock` `ACTIVE`, `PAY_PER_REQUEST`, hash key `LockID` (S)

## 5. Cierre

- [x] 5.1 `openspec validate add-remote-state-backend --strict` pasa
- [x] 5.2 `git add` de los `.tf`, `terraform/bootstrap/.terraform.lock.hcl`, `terraform/bootstrap/terraform.tfstate`, `.gitignore`, `Makefile`, `docs/runbook.md`; `git status` confirma que el state del bootstrap SÍ queda staged y que ningún `.terraform/` ni state del stack entra
- [x] 5.3 Commit único "Fase 1: remote state backend (S3 + DynamoDB)" con la línea `Co-Authored-By` acordada; `git status` limpio (commit f40022e)
- [ ] 5.4 Archivar el cambio con `/openspec-archive-change add-remote-state-backend` (sincroniza `infra-reproducibility` a `openspec/specs/`)
