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

---

## Fase 2 - Almacenes: documentos (S3) y base vectorial (RDS + pgvector)

> **OBSOLETO desde la Fase 3a.** El RDS `db.t3.micro` + pgvector se retiró: el
> Bedrock Knowledge Base gestionado no puede usar un RDS estándar como vector
> store (exige la RDS Data API, exclusiva de Aurora). El vector store pasó a
> **Amazon S3 Vectors** (ver "Fase 3"). De esta sección solo sigue vigente el
> **bucket de documentos**; toda la parte de RDS, security groups, Secrets
> Manager y el setup de `pgvector` con `psql` ya no aplica.

Crea el bucket de documentos y la instancia PostgreSQL con `pgvector`. Es el
primer `apply` del stack `terraform/environments/dev/` (usa el backend `s3` de
la Fase 1).

### Pre-check

1. Poner tu IP pública en `terraform/environments/dev/terraform.tfvars`:

   ```
   admin_cidr = "$(curl -s ifconfig.me)/32"
   ```

   Sin esto la base de datos no acepta ninguna conexión y no se puede instalar
   `pgvector`.

2. `aws sts get-caller-identity` con el perfil correcto (`AWS_PROFILE=personal`).

### Permisos mínimos adicionales

Sobre los de la Fase 1, en `us-east-1`: `s3:*` sobre el bucket de documentos;
`rds:CreateDBInstance/CreateDBSubnetGroup/CreateDBParameterGroup` +
`rds:Describe*` + `rds:AddTagsToResource`; `ec2:CreateSecurityGroup` +
`ec2:AuthorizeSecurityGroup*` + `ec2:Describe*`;
`secretsmanager:CreateSecret/GetSecretValue/TagResource` (RDS crea y gestiona el
secreto de la contraseña).

### Ejecución

```
make deploy
# equivale a:
#   terraform -chdir=terraform/environments/dev init
#   terraform -chdir=terraform/environments/dev apply
```

Terraform muestra el plan (14 recursos: bucket + 7 configs/objetos, instancia
RDS + subnet group + parameter group + security group + reglas) y pide `yes`.
La instancia RDS tarda ~5-10 min.

> El comando emite un aviso de deprecación de `dynamodb_table`. Es cosmético:
> Terraform >= 1.11 prefiere `use_lockfile` (locking nativo de S3), pero la
> arquitectura decidida usa la tabla DynamoDB y se mantiene a propósito.

### Setup de pgvector (una vez, tras el apply)

```
DEV=terraform/environments/dev
HOST=$(terraform -chdir=$DEV output -raw db_host)
SECRET_ARN=$(terraform -chdir=$DEV output -raw db_secret_arn)

# Contraseña gestionada por RDS -> Secrets Manager
PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" \
  --query SecretString --output text | python3 -c 'import sys,json;print(json.load(sys.stdin)["password"])')

export PGPASSWORD
psql "host=$HOST port=5432 dbname=ragdb user=ragadmin sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql "host=$HOST port=5432 dbname=ragdb user=ragadmin sslmode=require" -c "\dx"
unset PGPASSWORD
```

Sin `psql` local:

```
docker run --rm -e PGPASSWORD -e HOST postgres:16 \
  psql "host=$HOST port=5432 dbname=ragdb user=ragadmin sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

`\dx` debe listar `vector`.

### Verificación en AWS

```
aws rds describe-db-instances --db-instance-identifier rag-serverless-demo-pgvector \
  --query 'DBInstances[0].{Class:DBInstanceClass,Encrypted:StorageEncrypted,MultiAZ:MultiAZ,Public:PubliclyAccessible,Status:DBInstanceStatus}'
aws ec2 describe-security-groups --filters Name=group-name,Values=rag-serverless-demo-db \
  --query 'SecurityGroups[0].IpPermissions'   # ninguna regla con 0.0.0.0/0 en 5432
```

### Al terminar la sesión de trabajo

```
make destroy   # borra bucket de docs, RDS, secreto, SG, subnet group
```

El bootstrap de la Fase 1 **no se toca**. La instancia RDS corriendo suma horas
de free tier.

---

## Fase 3 - Bedrock Knowledge Base + S3 Vectors

Crea el vector store (S3 Vectors), la Knowledge Base con Titan Text Embeddings
v2, su data source S3 (`raw/`, chunking 512/20%) y su rol IAM de minimo
privilegio. No ingesta nada todavia (eso es la Fase 6).

### Pre-check

```
# El modelo de embeddings debe estar habilitado (los de Amazon suelen estarlo)
aws bedrock list-foundation-models \
  --query "modelSummaries[?modelId=='amazon.titan-embed-text-v2:0'].[modelId,modelLifecycle.status]" \
  --output text
```

Si el `apply` falla luego con `AccessDeniedException` sobre el modelo, habilitar
"Titan Text Embeddings V2" en la consola de Bedrock -> Model access, y
reintentar.

### Ejecucion

```
make deploy      # terraform -chdir=terraform/environments/dev init + apply
```

Plan esperado: 6 recursos nuevos (vector bucket, indice, rol + policy, KB, data
source), 0 destroy. La KB tarda ~1-2 min en quedar ACTIVE.

### Verificacion

```
DEV=terraform/environments/dev
KB=$(terraform -chdir=$DEV output -raw knowledge_base_id)
DS=$(terraform -chdir=$DEV output -raw data_source_id)

aws bedrock-agent get-knowledge-base --knowledge-base-id $KB \
  --query 'knowledgeBase.{status:status,storage:storageConfiguration.type}'
aws bedrock-agent get-data-source --knowledge-base-id $KB --data-source-id $DS \
  --query 'dataSource.{chunking:vectorIngestionConfiguration.chunkingConfiguration,prefixes:dataSourceConfiguration.s3Configuration.inclusionPrefixes,del:dataDeletionPolicy}'
aws s3vectors get-index --vector-bucket-name rag-serverless-demo-vectors \
  --index-name rag-serverless-demo-kb-index
aws iam get-role-policy --role-name rag-serverless-demo-kb-role \
  --policy-name rag-serverless-demo-kb-policy
```

Esperado: KB `status = ACTIVE`, `storage = S3_VECTORS`; data source con chunking
`FIXED_SIZE` 512/20, prefijo `raw/`, `dataDeletionPolicy = DELETE`; indice
`dimension = 1024`, `distanceMetric = cosine`, `AMAZON_BEDROCK_TEXT` y
`AMAZON_BEDROCK_METADATA` no filtrables; la policy del rol sin `"*"` en Action ni
Resource.

### Ingesta

Se corre en la Fase 6, con documentos ya subidos a `raw/`:

```
scripts/sync-knowledge-base.sh
```

---

## Fase 5 - Despliegue del agente (Lambda)

Empaqueta el codigo de la Fase 4 y lo despliega como funcion Lambda con un rol
de ejecucion de minimo privilegio.

### Pre-check

```
aws bedrock list-foundation-models \
  --query "modelSummaries[?modelId=='amazon.nova-lite-v1:0'].[modelId,modelLifecycle.status]" \
  --output text
```

Si el modelo de generacion no esta habilitado (o se cambia por otro), ajustar
`var.model_id` en `terraform/environments/dev` (un solo sitio: es tambien lo que
acota el permiso `bedrock:InvokeModel`).

### Ejecucion

```
make deploy      # aplica log group + rol + policy + funcion (~4 recursos)
```

El `.zip` lo construye Terraform (`data "archive_file"`); no hace falta correr
`make package` antes. `make package` queda para inspeccionar el zip a mano.

### Invocacion de humo

```
make invoke                      # usa lambda/tests/events/sample-question.json
make invoke Q="¿cuantos dias de vacaciones tengo?"
```

Con la KB todavia vacia (sin ingesta), la respuesta esperada es:

```
{"answer": "No encontre informacion sobre eso en los documentos.",
 "sources": [], "used_chunks": 0}
```

Eso confirma que permisos, env vars y la llamada `Retrieve` funcionan. La
prueba con respuesta real es la Fase 6.

### Logs

```
aws logs tail /aws/lambda/rag-serverless-demo-agent --follow
```

### Verificacion

```
aws lambda get-function --function-name rag-serverless-demo-agent \
  --query 'Configuration.{runtime:Runtime,handler:Handler,pkg:PackageType,timeout:Timeout,mem:MemorySize}'
aws lambda get-function-configuration --function-name rag-serverless-demo-agent \
  --query 'Environment.Variables'
aws iam get-role-policy --role-name rag-serverless-demo-agent-exec \
  --policy-name rag-serverless-demo-agent-policy
```

Esperado: `PackageType = Zip`, runtime `python3.13`, handler
`agent.handler.lambda_handler`; env vars con `KNOWLEDGE_BASE_ID` y `MODEL_ID`;
policy con 3 statements acotados (logs sobre su log group, `bedrock:InvokeModel`
sobre el modelo, `bedrock:Retrieve` sobre la KB), sin `"*"`.

---

## Fase 6 - Prueba end-to-end

Con el stack desplegado (Fase 5), se prueba que el sistema responde de verdad
citando la fuente correcta.

### 1. Subir el corpus ficticio

```
DEV=terraform/environments/dev
BUCKET=$(terraform -chdir=$DEV output -raw documents_bucket_name)
aws s3 cp sample-data/fictional-corp/ "s3://$BUCKET/raw/" --recursive
aws s3 ls "s3://$BUCKET/raw/"
```

### 2. Ingesta

```
scripts/sync-knowledge-base.sh      # dispara start-ingestion-job y espera COMPLETE
```

Si sale `FAILED`, revisar las estadisticas que imprime y el motivo (formato del
documento, permisos del rol de la KB) antes de reintentar.

### 3. Preguntas de prueba

```
make invoke Q="¿Cuantos dias de vacaciones tengo al ano?"
make invoke Q="¿En cuantos dias se reembolsan los gastos de viaje?"
make invoke Q="¿Cuantos dias a la semana puedo trabajar desde casa?"
make invoke Q="¿Cual es la politica de coche de empresa?"
```

Esperado:

| Pregunta | `sources` debe incluir | Respuesta |
|----------|------------------------|-----------|
| vacaciones | `raw/vacation-policy.md` | 23 dias habiles |
| gastos de viaje | `raw/expense-policy.md` | dentro de 30 dias |
| trabajo desde casa | `raw/remote-work-policy.md` | hasta 3 dias/semana |
| coche de empresa | (ninguno) | "No encontre informacion..." |

Anotar las respuestas reales en `docs/cost-estimate.md`.

### Si `Retrieve` da `ThrottlingException`

1. Reintentar espaciado: el rate-limit inicial de una KB nueva suele relajarse
   en minutos/horas.
2. Si persiste: Service Quotas -> Amazon Bedrock -> cuota de consultas a
   knowledge base / `Retrieve`, pedir aumento.
3. Plan C para la charla: mostrar el paso con la CLI directa
   `aws bedrock-agent-runtime retrieve --knowledge-base-id <id> --retrieval-query '{"text":"..."}'`.

### Logs de la invocacion

```
aws logs tail /aws/lambda/rag-serverless-demo-agent --since 10m
```

---

## Fase 7 - Prueba de reproducibilidad

Destruir el stack `dev` y volver a levantarlo desde cero. **El bootstrap de la
Fase 1 NO se toca.**

```
time make reproduce
```

`make reproduce` hace `terraform destroy` + `terraform apply` del stack `dev`
(-auto-approve). Luego, a mano:

```
aws s3 cp sample-data/fictional-corp/ "s3://$(terraform -chdir=terraform/environments/dev output -raw documents_bucket_name)/raw/" --recursive
scripts/sync-knowledge-base.sh
# repetir las 4 preguntas de la Fase 6
```

### Qué mirar si algo no reconstruye limpio

- `terraform -chdir=terraform/environments/dev state list` vs lo que hay en AWS:
  algun recurso que quedo huerfano tras el destroy (el vector bucket tiene
  `force_destroy = true` y el data source `data_deletion_policy = DELETE`, asi
  que deberia salir limpio).
- Un `apply` que falla por una dependencia (p. ej. el indice de S3 Vectors
  antes que el vector bucket): reportar el recurso y el orden.
- El nombre del bucket de documentos cambia en cada apply (`random_id`): es
  esperado; el output y el `aws s3 cp` lo resuelven.

### Registrar

En `docs/cost-estimate.md`: el tiempo total (`time make reproduce` + tiempo de
ingesta + re-test) y si hubo que corregir algo a mano.
