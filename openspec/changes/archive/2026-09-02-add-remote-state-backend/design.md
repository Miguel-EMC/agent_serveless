## Context

Ver `proposal.md` - Why, y `specs/infra-reproducibility/spec.md` para los
requisitos. La decisión de fondo (bootstrap como raíz separada con state local,
`.tfstate` commiteado) ya se tomó en el cambio archivado
`establish-repo-structure` (D1). Este documento fija los detalles de
implementación de esa decisión y las que faltaban.

Inputs de Miguel para esta fase:
- Región: `us-east-1`
- Prefijo de recursos: `rag-serverless-demo`
- Sufijo del bucket: `random_id` de Terraform

Restricción de entorno: el `terraform apply` del bootstrap lo ejecuta Miguel con
sus credenciales AWS; el bootstrap NO gestiona usuarios ni roles IAM.

## Goals / Non-Goals

**Goals:**

- `terraform/bootstrap/` aplica limpio desde un checkout nuevo con un comando.
- El stack `environments/dev/` queda con su `backend "s3"` definido y
  `terraform validate` pasa, aunque todavía no tenga recursos.
- El `.tfstate` del bootstrap se puede commitear (no lo bloquea `.gitignore`).

**Non-Goals:**

- No se crean recursos del stack principal (S3 de documentos, RDS, etc.).
- No se corre `terraform init`/`apply` del stack `environments/dev/` (sin
  recursos todavía; es Fase 2).
- No se configura CI ni backend por-entorno más allá de `dev`.
- No se gestiona ninguna key KMS propia (ver DD4).

## Decisions

### DD1 - Bootstrap: raíz separada, state local, `.tfstate` versionado

`terraform/bootstrap/` no declara `backend`, así que usa state local. Tras el
`apply`, se commitea `terraform/bootstrap/terraform.tfstate`.

- **Contenido del state**: nombre y ARN del bucket, nombre y ARN de la tabla,
  el valor de `random_id`, y metadatos de Terraform. Sin credenciales ni datos
  sensibles.
- **Por qué se commitea**: hace el bootstrap reproducible y auditable sin
  depender de nada externo; si alguien más clona el repo, un `terraform plan`
  del bootstrap muestra "no changes" en vez de proponer recrear el bucket.
- **Alternativa A - no commitear, recrear manualmente**: rechazada; rompe la
  promesa de reproducibilidad para el propio bootstrap y arriesga crear un
  segundo bucket huérfano.
- **Alternativa B - migrar el state del bootstrap a su propio bucket
  (`terraform init -migrate-state`)**: más "puro", pero añade un paso frágil
  en vivo (durante la charla) y acopla el bootstrap a su propio output. Se
  documenta en `docs/runbook.md` como opción avanzada, no como camino por
  defecto.

### DD2 - Sufijo del bucket: `random_id`

`resource "random_id" "suffix" { byte_length = 4 }` → 8 hex chars. Nombre final:
`rag-serverless-demo-tfstate-<hex>`.

- **Por qué**: los nombres de bucket S3 son globales; `random_id` evita
  colisiones sin pedir más input y sin exponer el Account ID en el nombre.
- **Alternativa - Account ID como sufijo**: estable y memorizable, pero mete el
  número de cuenta en un nombre que aparece en logs y en el `backend.tf`
  commiteado. Rechazada por higiene.
- **Alternativa - sufijo elegido a mano**: cero dependencia de un provider
  extra, pero un dato más que mantener sincronizado entre `bootstrap` y
  `backend.tf`. Rechazada.
- **Trade-off**: el nombre exacto del bucket no se conoce hasta el primer
  `apply`. Se resuelve leyéndolo de `terraform output` y copiándolo al
  `backend.tf` del stack (una vez).

### DD3 - DynamoDB: `PAY_PER_REQUEST`, sin autoscaling

Tabla `rag-serverless-demo-tflock`, `billing_mode = "PAY_PER_REQUEST"`, un solo
atributo `LockID` (S) como `hash_key`.

- **Por qué**: el tráfico de locking son unas pocas escrituras por `apply`.
  On-demand = sin planear capacidad y sin costo en reposo.
- **Alternativa - `PROVISIONED` con 1/1 RCU/WCU (free tier)**: entra en free
  tier, pero obliga a pensar en throttling si algún día hay applies paralelos.
  Rechazada; la diferencia de costo a este volumen es ruido.

### DD4 - Cifrado del bucket de state: SSE-S3 (`AES256`)

`aws_s3_bucket_server_side_encryption_configuration` con `sse_algorithm =
"AES256"`.

- **Por qué**: cumple el requisito de "cifrado en reposo" sin introducir una
  KMS key propia (que traería su propia key policy y un rol/permiso más que
  gestionar — justo lo que el principio de mínimo privilegio pide evitar si no
  aporta).
- **Alternativa - SSE-KMS con CMK**: mayor control y auditoría de acceso a la
  key, deseable en producción. Se anota en `docs/runbook.md` como mejora para
  producción; fuera de alcance de la demo.
- **Nota mínimo privilegio**: este cambio no crea ningún rol IAM. El único
  principal involucrado es el usuario de Miguel, que ya tiene permisos amplios
  para el bootstrap manual. Los roles de servicio (KB, Lambda) llegan en fases
  posteriores y ahí sí se enumeran acciones concretas.

### DD5 - `backend.tf` del stack se crea ahora, `init` se difiere

`terraform/environments/dev/backend.tf` se escribe en esta fase con el bloque
`backend "s3"` completo (bucket, `key = "dev/terraform.tfstate"`, `region`,
`dynamodb_table`, `encrypt = true`). Pero NO se corre `terraform init` del
stack: sin recursos, no hay nada que inicializar y `init` con backend remoto
crearía un state vacío innecesario.

- **Por qué crearlo ahora**: deja la Fase 1 auto-contenida — se puede correr
  `terraform -chdir=terraform/environments/dev validate` y `fmt -check` como
  verificación, y la Fase 2 arranca directo con `init`.
- **Alternativa - diferir `backend.tf` entero a Fase 2**: menos archivos
  "adelantados", pero parte la configuración del backend en dos fases y deja la
  Fase 1 sin forma de verificar el lado del stack. Rechazada.

### DD6 - Variables del bootstrap con defaults; sin `tfvars`

`var.prefix` (default `"rag-serverless-demo"`) y `var.region` (default
`"us-east-1"`). El bootstrap se corre sin `-var` ni `tfvars`.

- **Por qué**: un solo entorno, valores ya decididos; los defaults hacen que
  `terraform apply` "just works". El `tfvars` del stack principal (con valores
  no secretos) llega en Fase 2, donde hay más de un valor que variar.

### DD7 - `.gitignore`: negar el ignore para el state del bootstrap

`.gitignore` tiene `*.tfstate`, que bloquearía el commit del state del
bootstrap. Se añade una excepción explícita:

```
!terraform/bootstrap/terraform.tfstate
!terraform/bootstrap/terraform.tfstate.backup
```

Colocada después de las reglas `*.tfstate*` para que la negación gane.

## Risks / Trade-offs

- **[Credenciales AWS ausentes o sin permiso]** → El `apply` falla claro
  (`AccessDenied`). Mitigación: `docs/runbook.md` lista los permisos mínimos
  (`s3:CreateBucket`, `s3:PutBucket*`, `dynamodb:CreateTable`, `*:Describe*`,
  `*:List*`, `*:TagResource`) y Miguel confirma la identidad con
  `aws sts get-caller-identity` antes de correr.
- **[Colisión de nombre de bucket global]** → `random_id` de 4 bytes hace la
  colisión prácticamente imposible; si ocurre, `terraform apply` de nuevo
  regenera el sufijo.
- **[Commitear un `.tfstate` se percibe como antipatrón]** → Se documenta el
  porqué en `docs/runbook.md` y en `terraform/bootstrap/README.md`, y se marca
  explícito que NO aplica al stack principal.
- **[El `.tfstate` del bootstrap se desincroniza si alguien aplica y no
  commitea]** → `docs/runbook.md` incluye el paso "commitear el state" como
  parte del procedimiento de bootstrap; en la práctica el bootstrap se corre
  una sola vez.
- **[`random_id` obliga a un paso manual de copiar el nombre del bucket al
  `backend.tf`]** → Aceptado; ocurre una única vez. El `outputs.tf` del
  bootstrap y `docs/runbook.md` dejan el comando exacto (`terraform output -raw
  state_bucket_name`).

## Migration Plan

1. Escribir los `.tf` del bootstrap y del stack (`versions/providers/backend`).
2. Añadir la excepción a `.gitignore` (DD7).
3. Implementar `make bootstrap`.
4. **PARA** - mostrar `terraform -chdir=terraform/bootstrap plan` a Miguel.
5. Con su OK: `apply`, copiar el nombre del bucket al `backend.tf`, commitear
   los `.tf` + `.terraform.lock.hcl` + `terraform.tfstate`.
6. Verificar según `tasks.md`.

Rollback: `terraform -chdir=terraform/bootstrap destroy` (vacía el bucket
primero si hay versiones) + `git revert`. Como el bootstrap se corre una vez y
nada depende aún del backend, el rollback es barato.

## Open Questions

- ¿El `docs/runbook.md` debe incluir ya el comando de `destroy` del bootstrap, o
  se deja para la Fase 7? Se puede añadir después sin afectar specs ni tasks.
