## Context

Ver `proposal.md` - Why. Estado: la Fase 2 dejó en el stack `dev` el bucket de
documentos (`rag-serverless-demo-docs-483f7fb2`) **y** un RDS
`db.t3.micro` + pgvector con su SG, subnet group, parameter group y secreto
gestionado. La investigación de la Fase 3 confirmó que el KB gestionado no
habla con RDS estándar; Miguel eligió S3 Vectors.

Todos los `.tf` pinnean `aws ~> 5.0` (provider v5.100.0). S3 Vectors necesita el
provider v6 (`aws_s3vectors_vector_bucket` / `aws_s3vectors_index` +
`storage_configuration { type = "S3_VECTORS" }` llegaron en v6.27, dic-2025).

## Goals / Non-Goals

**Goals:**

- Dejar el stack `dev` con solo el bucket de documentos, sin recursos de RDS.
- Provider AWS en `~> 6.0` en todas las raíces, con `plan` limpio (sin diffs)
  para lo que sobrevive (buckets de state y de documentos, tabla de lock).
- Specs y docs coherentes con "el vector store es S3 Vectors".

**Non-Goals:**

- No se crea S3 Vectors ni la Knowledge Base (eso es `add-bedrock-knowledge-base`).
- No se toca el bootstrap de la Fase 1 salvo el pin del provider.
- No se borra el bucket de documentos ni su contenido.

## Decisions

### DD1 - Orden: destroy dirigido primero, luego borrar el código

1. Con el código de la Fase 2 todavía presente: `terraform -chdir=...dev apply`
   con el módulo RDS **comentado/removido** hace que Terraform planee destruir
   solo esos recursos. Alternativa: `terraform destroy -target=module.rds_pgvector`.
   Se usa la primera (quitar del código + apply) porque `-target` deja el state
   "sucio" y es más difícil de revisar.
2. Una vez que AWS confirma los recursos destruidos, se borra
   `terraform/modules/rds-pgvector/`.

- **Por qué en ese orden**: si se borra el módulo antes del apply, Terraform
  pierde la definición y falla el `plan` ("module not installed"). Primero se
  saca la llamada del `main.tf` del stack (Terraform planea el destroy), se
  aplica, y recién ahí se borra el directorio del módulo.

### DD2 - Provider `~> 6.0`: `>= 6.0` con lockfile actualizado

`versions.tf` de `bootstrap`, `s3-documents` y `environments/dev` pasan a
`version = "~> 6.0"`. Se corre `terraform init -upgrade` en `bootstrap` y `dev`;
los `.terraform.lock.hcl` se commitean con el hash de la nueva versión.

- **Riesgo**: v6 es un major. Los recursos vivos (`aws_s3_bucket`,
  `aws_s3_bucket_versioning/public_access_block/sse/ownership`,
  `aws_dynamodb_table`, `aws_s3_object`) no tuvieron cambios de esquema
  incompatibles entre v5 y v6. Mitigación: tras el upgrade, `terraform plan` de
  `bootstrap` y de `dev` (ya sin RDS) debe salir **"No changes"** para todo lo
  que no sea el destroy de RDS. Si aparece un diff inesperado, se documenta y se
  para.
- **Alternativa**: quedarse en v5 y usar un provider aliasado v6 solo para los
  recursos de S3 Vectors. Rechazada: dos versiones del mismo provider en un
  proyecto chico es más complejidad que actualizar una vez.

### DD3 - `environments/dev/variables.tf`: se queda solo `tags`

`admin_cidr` se elimina (era para el SG de RDS). `terraform.tfvars` (gitignored)
puede quedar con la línea vieja: Terraform ignora variables no declaradas con un
warning, o se limpia. El runbook indica limpiarlo.

### DD4 - Purpose de `document-ingestion`

El `## Purpose` actual menciona "la base vectorial donde se guardan los
embeddings ... controles de acceso y credenciales". El delta de spec no puede
cambiar el Purpose (regla de OpenSpec); se edita
`openspec/specs/document-ingestion/spec.md` directamente en el paso de sync del
archivado, para que diga "el vector store gestionado" en vez de "la base
vectorial ... credenciales".

## Risks / Trade-offs

- **[El apply de destroy borra algo de más]** → Se revisa el `plan` antes
  (debe listar solo `module.rds_pgvector.*` como destroy y 0 cambios en
  `module.s3_documents`). PARA para aprobación de Miguel.
- **[El upgrade a v6 propone recrear el bucket de state o de documentos]** →
  Muy improbable (esquemas estables). Si pasa, se para y se investiga el
  atributo concreto; no se aplica.
- **[Borrar la instancia RDS pierde el `CREATE EXTENSION vector` ya hecho]** →
  Irrelevante: no se había ingestado nada y pgvector deja de usarse.
- **[`aws_db_instance` con `deletion_protection = false` y
  `skip_final_snapshot = true`]** → El destroy es limpio y sin snapshot, que es
  lo deseado para la demo.

## Migration Plan

1. Quitar `module "rds_pgvector"` y sus outputs/variable de
   `terraform/environments/dev/`.
2. Subir el pin del provider a `~> 6.0` en las 3 raíces/módulos vivos.
3. `terraform -chdir=terraform/environments/dev init -upgrade`.
4. `terraform -chdir=terraform/environments/dev plan` → debe mostrar solo el
   destroy de los recursos RDS. **PARA** para Miguel.
5. Con OK: `apply` (lo corre Miguel). Verificar en AWS que RDS/SG/secreto ya no
   existen.
6. Borrar `terraform/modules/rds-pgvector/`.
7. `terraform -chdir=terraform/bootstrap init -upgrade` + `plan` (debe ser "No
   changes").
8. Actualizar `docs/` y `openspec/config.yaml`; commit único; archivar
   (sincroniza los specs modificados).

Rollback: `git revert` del commit + re-`apply` recrea el RDS (el módulo vuelve
con el revert). Como nada dependía aún de él, el rollback es barato.

## Open Questions

- ¿Se aprovecha este cambio para renombrar el módulo `bedrock-kb` →
  `knowledge-base` o se deja? Sin impacto; se decide en 3b.
