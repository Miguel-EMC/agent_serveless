# Runbook

Procedimientos operativos del proyecto, fase por fase.

---

## Fase 1 - Bootstrap del remote state

Crea el bucket S3 del Terraform state y la tabla DynamoDB de locking. **Se corre
una sola vez**, antes que cualquier otra cosa de Terraform.

### Pre-check

```
aws sts get-caller-identity        # confirma identidad y cuenta
aws configure get region           # o exporta AWS_REGION=us-east-1
```

### Permisos mínimos necesarios

El usuario/rol que corre el bootstrap necesita, en `us-east-1`:

- `s3:CreateBucket`, `s3:PutBucketVersioning`, `s3:PutBucketPublicAccessBlock`,
  `s3:PutEncryptionConfiguration`, `s3:PutBucketOwnershipControls`,
  `s3:PutBucketTagging`, `s3:GetBucket*`, `s3:GetEncryptionConfiguration`,
  `s3:ListBucket`
- `dynamodb:CreateTable`, `dynamodb:DescribeTable`, `dynamodb:TagResource`,
  `dynamodb:ListTagsOfResource`

No crea usuarios ni roles IAM.

### Ejecución

```
make bootstrap
# equivale a:
#   terraform -chdir=terraform/bootstrap init
#   terraform -chdir=terraform/bootstrap apply
```

Terraform mostrará el plan (1 bucket S3 + sus configs, 1 tabla DynamoDB, 1
`random_id`) y pedirá confirmación antes de crear nada.

### Resultado (aplicado 2026-09-02, cuenta 034703319129, us-east-1)

| Recurso | Valor |
|---------|-------|
| Bucket de state | `rag-serverless-demo-tfstate-777a8ea1` |
| Tabla de lock | `rag-serverless-demo-tflock` |

Verificado: versioning `Enabled`, block public access en los 4 flags, cifrado
`AES256`, ownership `BucketOwnerEnforced`; tabla `ACTIVE`, `PAY_PER_REQUEST`,
hash key `LockID` (S).

### Después del apply

1. Leer el nombre del bucket generado:

   ```
   terraform -chdir=terraform/bootstrap output -raw state_bucket_name
   ```

2. Pegar ese valor en el campo `bucket` de
   `terraform/environments/dev/backend.tf` (reemplaza
   `REEMPLAZAR_CON_OUTPUT_DEL_BOOTSTRAP`).

3. Commitear, en un solo commit de Fase 1:
   - `terraform/bootstrap/*.tf`
   - `terraform/bootstrap/.terraform.lock.hcl`
   - `terraform/bootstrap/terraform.tfstate`  <-- sí, el state va al repo
   - `terraform/environments/dev/*.tf`
   - `.gitignore`, `Makefile`, `docs/runbook.md`

### Por qué se commitea `terraform/bootstrap/terraform.tfstate`

El bootstrap usa **state local** porque no puede usar el backend `s3` que
todavía no existe (problema de huevo y gallina). Versionar su `.tfstate`:

- hace el bootstrap reproducible y auditable sin depender de nada externo;
- evita que otro checkout del repo proponga recrear el bucket (un `terraform
  plan` del bootstrap dice "no changes");
- es seguro: el state del bootstrap solo contiene nombres, ARNs y el valor de
  `random_id`. **No contiene secretos.**

Esto **NO aplica al stack principal** (`terraform/environments/dev/`), que usa
backend `s3` con locking; su state nunca toca el repo (`.gitignore` lo bloquea).

### Destruir el bootstrap

Normalmente **no se destruye** (es la base de todo). Si hiciera falta, ver la
Fase 7; a grandes rasgos: vaciar todas las versiones del bucket y luego
`terraform -chdir=terraform/bootstrap destroy`. Antes hay que migrar o descartar
el state del stack principal, que vive dentro de ese bucket.

### Alternativa avanzada (no usada): mover el state del bootstrap a su bucket

Tras crear el bucket, se podría correr `terraform -chdir=terraform/bootstrap
init -migrate-state` con un `backend "s3"` para que el propio bootstrap deje de
usar state local. Es más "puro" pero añade un paso frágil y acopla el bootstrap
a su output; en este proyecto se prefiere el `.tfstate` versionado.
