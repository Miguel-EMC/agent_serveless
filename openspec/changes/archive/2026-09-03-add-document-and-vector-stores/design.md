## Context

Ver `proposal.md` - Why y `specs/document-ingestion/spec.md`. La Fase 1 dejó el
backend `s3` (`rag-serverless-demo-tfstate-777a8ea1` + tabla
`rag-serverless-demo-tflock`) y `terraform/environments/dev/` con
`versions/providers/backend.tf` pero sin recursos ni `init`.

Tensión de fondo de esta fase: la instancia RDS tiene que ser alcanzable por
tres cosas con requisitos de red distintos —
1. la Lambda del agente (Fase 5), que estará en la VPC,
2. la Bedrock Knowledge Base (Fase 3), un servicio gestionado de AWS,
3. Miguel una sola vez, para correr `CREATE EXTENSION vector` —
y al mismo tiempo el requisito es "nada de acceso público" (grupo de seguridad
que no abra `0.0.0.0/0`).

## Goals / Non-Goals

**Goals:**

- Módulos `s3-documents` y `rds-pgvector` reutilizables, sin `provider`/`backend`.
- Primer `terraform init` + `apply` del stack `dev` contra el backend real.
- Instancia PostgreSQL con `pgvector` instalable de forma fiable, sin acceso
  público y con la contraseña fuera del state.

**Non-Goals:**

- No se crea la Bedrock Knowledge Base (Fase 3) ni la Lambda (Fase 5). El
  `security group` de la Lambda todavía no existe; el módulo RDS acepta su id
  como variable opcional vacía y la regla se añade en la Fase 5.
- No se suben documentos de ejemplo (Fase 6).
- No se crea una VPC nueva (ver DD1).
- No hay Multi-AZ, réplicas, ni `deletion_protection` (es una demo).

## Decisions

### DD1 - Red: usar la VPC default de la cuenta

El módulo `rds-pgvector` construye el `aws_db_subnet_group` a partir de las
subredes de la **VPC default** (`data "aws_vpc" "default" { default = true }` +
`data "aws_subnets"`), y crea el `security group` en esa VPC.

- **Por qué**: una VPC dedicada para esta demo son ~6 recursos extra (VPC,
  subredes, IGW, route tables, associations) que hay que destruir y recrear sin
  fallos en la prueba de Fase 7, sin aportar nada al mensaje de la charla. La
  VPC default ya tiene subredes en varias AZ (RDS exige >= 2 AZ en el subnet
  group).
- **Alternativa - VPC dedicada mínima**: más "de verdad" y 100% reproducible
  (no depende de que exista la VPC default). Se documenta como mejora; si en la
  cuenta no hubiera VPC default, se activa esta ruta. Coste real: un módulo
  `network` extra (se desvía de la lista de módulos del prompt).
- **Caveat de reproducibilidad**: el stack asume que la cuenta `034703319129`
  tiene su VPC default en `us-east-1` (la tiene). Queda anotado en el runbook.

### DD2 - RDS `publicly_accessible = true`, pero el grupo de seguridad NO abre al mundo

La instancia recibe DNS/IP pública, pero **todo** el control de acceso lo hace
el `security group`: ingress al 5432 sólo desde
(a) `var.agent_security_group_id` (el SG de la Lambda, se conecta en Fase 5) y
(b) `var.admin_cidr` (opcional, un `/32` con la IP de Miguel para el setup).
Sin `admin_cidr` y antes de la Fase 5, la instancia no acepta ninguna conexión.

- **Por qué `publicly_accessible = true`**: sin VPC dedicada no hay NAT ni
  endpoints; que la instancia sea resoluble desde fuera permite correr
  `CREATE EXTENSION` con `psql` desde el equipo de Miguel (restringido por SG a
  su IP) sin montar un bastión. "Publicly accessible" en RDS significa "tiene un
  endpoint público", no "abierto a todos" — el SG sigue siendo la puerta.
- **Alternativa - `publicly_accessible = false`**: más correcto para
  producción, pero entonces `CREATE EXTENSION` y cualquier inspección exigen un
  bastión, Session Manager, o una Lambda de init dentro de la VPC. Se documenta
  como el objetivo de endurecimiento post-demo.
- **Riesgo**: si `admin_cidr` se deja como `0.0.0.0/0` por descuido, la BD
  queda expuesta. Mitigación: el `default` de `admin_cidr` es `null` (sin
  regla), y una `validation` en la variable rechaza `0.0.0.0/0`.
- **Nota para Fase 3**: la Bedrock KB tendrá que alcanzar esta instancia. La
  ruta más probable es añadir al SG el rango/So de la KB o hacerla accesible
  vía el endpoint público con credenciales de Secrets Manager. Es el punto que
  el prompt marca como "el más probable de dar problemas"; se resolverá ahí,
  no aquí.

### DD3 - `pgvector` se instala a mano con `psql` (una vez), documentado en el runbook

Tras el `apply`, con `admin_cidr` incluyendo la IP de Miguel:

```
psql "host=<endpoint> port=5432 dbname=ragdb user=ragadmin sslmode=require" \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql ... -c "\dx"   # verificar
```

- **Por qué manual**: es una sola línea, una sola vez. No añade nada frágil al
  `terraform apply`.
- **Alternativa (b) - `null_resource` + `local-exec` con `psql`**: automatiza,
  pero exige `psql` en el equipo que corre Terraform y conectividad desde ese
  equipo a RDS; se rompe en CI o si `admin_cidr` no está. Se documenta como
  opción para automatizar más adelante.
- **Alternativa (c) - Lambda de init en la VPC**: la más robusta para privado,
  pero es "más maquinaria" para la demo. Descartada por ahora.
- PostgreSQL 16 en RDS soporta `pgvector` de forma nativa (viene en la lista de
  extensiones permitidas); no hace falta `shared_preload_libraries`.

### DD4 - Contraseña: `manage_master_user_password = true` (secreto gestionado por RDS)

RDS genera la contraseña del usuario `ragadmin` y la mantiene en un secreto de
Secrets Manager cifrado con la clave gestionada `aws/secretsmanager` (o una CMK
si se pasa `master_user_secret_kms_key_id`, no en esta fase).

- **Por qué**: la contraseña **nunca** pasa por el state de Terraform ni por
  variables/outputs. En la Fase 5 la Lambda leerá ese secreto por su ARN
  (`aws_db_instance.this.master_user_secret[0].secret_arn`) con permiso
  `secretsmanager:GetSecretValue` acotado a ese ARN.
- **Alternativa - `random_password` + secreto propio con JSON completo
  (host/port/dbname/password)**: cómodo para el cliente (un solo `GetSecretValue`),
  pero mete la contraseña en el state. Rechazada por el principio de mínimo
  privilegio / no exponer secretos.
- **Consecuencia**: host, puerto y `dbname` no van en el secreto; se exponen
  como outputs del stack y llegarán a la Lambda como variables de entorno en la
  Fase 5.

### DD5 - `parameter_group` propio con `rds.force_ssl = 1`

Grupo de parámetros dedicado (`family = "postgres16"`) con `rds.force_ssl = 1`
para exigir TLS en todas las conexiones. El `psql` del setup usa
`sslmode=require`.

### DD6 - Primer `init` del stack: `-reconfigure`, sin `migrate-state`

El stack nunca tuvo state, así que `terraform -chdir=terraform/environments/dev
init` crea el state directamente en el bucket. No hay `-migrate-state` porque no
hay state local que migrar. El `Makefile` target `deploy` corre `init` + `apply`.

### DD7 - Nombres y `tfvars`

- Prefijo `rag-serverless-demo` heredado. Bucket de documentos:
  `rag-serverless-demo-docs-<suffix>` (se reutiliza un `random_id` en el módulo
  s3, o se deriva del bucket de state — se usa `random_id` propio para
  independencia).
- `terraform/environments/dev/terraform.tfvars` (no secreto): `admin_cidr` (la
  IP de Miguel `/32`), y tags. `terraform.tfvars.example` con `admin_cidr =
  "203.0.113.10/32"` de ejemplo.
- `ragdb` como nombre de base de datos inicial (`db_name`).

## Risks / Trade-offs

- **[La VPC default no existe en la cuenta]** → El `apply` falla al resolver el
  data source. Mitigación: verificado que existe; si se borrara, activar la
  alternativa de DD1 (VPC dedicada).
- **[`admin_cidr` mal puesto expone la BD]** → `default = null` + `validation`
  que rechaza `0.0.0.0/0`.
- **[`psql` no instalado en el equipo de Miguel]** → El runbook incluye la
  alternativa `docker run --rm postgres:16 psql ...`.
- **[Free tier: la instancia corriendo suma horas]** → El runbook recuerda
  `terraform destroy` del stack al terminar cada sesión de trabajo; el bootstrap
  no se toca.
- **[Bedrock KB no podrá conectarse a una RDS con SG restrictivo]** → Riesgo
  real de la Fase 3, fuera del alcance de ésta; anotado en DD2.
- **[Contraseña gestionada por RDS complica un `psql` manual]** → Se lee con
  `aws secretsmanager get-secret-value --secret-id <arn> --query SecretString`;
  el runbook trae el comando exacto.

## Migration Plan

1. Escribir los dos módulos y el `main/variables/outputs.tf` del stack.
2. `terraform -chdir=terraform/environments/dev init` (crea el state en S3).
3. `terraform ... validate` y `plan`. **PARA** - mostrar el plan a Miguel.
4. Con OK: `apply` (lo corre Miguel con `AWS_PROFILE=personal`).
5. Setup de `pgvector` con `psql` (DD3); verificar `\dx`.
6. Verificaciones de `tasks.md`; commit único de Fase 2.

Rollback: `terraform -chdir=terraform/environments/dev destroy` (borra bucket de
docs, RDS, secreto, SG, subnet group) + `git revert`. El backend de la Fase 1
queda intacto.

## Open Questions

- ¿La base inicial se llama `ragdb` o se prefiere otro nombre? No afecta specs
  ni el desglose de tareas; se puede cambiar en `tfvars`.
- ~~¿`engine_version` exacta de PostgreSQL 16?~~ Resuelto en implementación:
  `engine_version = "16"` (major, RDS resuelve la última 16.x). `null` NO sirve
  — RDS elegiría el major más nuevo (PG18) y la familia del parameter group
  (`postgres16`) dejaría de coincidir. El `family`/`name` del parameter group se
  derivan de `local.postgres_major = split(".", var.engine_version)[0]`.
