# Módulo `rds-pgvector`

Crea la base vectorial: instancia PostgreSQL `db.t3.micro` (free tier, 20 GB
gp3, cifrada) en la VPC default de la cuenta, con un `db_subnet_group` sobre sus
subredes, un `parameter_group` con `rds.force_ssl = 1`, y un security group
**restrictivo**.

**El security group NO abre `0.0.0.0/0`.** El ingreso al 5432 se habilita sólo
si se pasa:
- `agent_security_group_id` → regla desde el SG del cómputo del agente (Fase 5),
- `admin_cidr` → regla desde un CIDR de administración para el setup e
  inspección.

**pgvector no se instala aquí.** Tras el `apply` hay que ejecutar
`CREATE EXTENSION IF NOT EXISTS vector;` con `psql` (ver `docs/runbook.md`,
Fase 2). La contraseña del usuario maestro la genera y gestiona RDS en Secrets
Manager (`manage_master_user_password = true`); nunca entra al state.

| Input | Default | Descripción |
|-------|---------|-------------|
| `name_prefix` | — | Prefijo de los recursos. |
| `db_name` | `ragdb` | Base de datos inicial. |
| `master_username` | `ragadmin` | Usuario maestro. |
| `instance_class` | `db.t3.micro` | Clase de instancia. |
| `allocated_storage` | `20` | GB. |
| `engine_version` | `null` | `null` = última 16.x. |
| `agent_security_group_id` | `null` | SG del agente (Fase 5). |
| `admin_cidr` | `null` | CIDR admin; rechaza `0.0.0.0/0`. |
| `tags` | `{}` | Tags. |

| Output | Descripción |
|--------|-------------|
| `db_host` / `db_port` / `db_name` | Datos de conexión no sensibles. |
| `master_user_secret_arn` | Secreto con la contraseña (gestionado por RDS). |
| `security_group_id` | SG de la instancia. |
