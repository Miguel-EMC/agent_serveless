# document-ingestion

## Purpose

Cubre la preparación y disponibilidad del material que la Bedrock Knowledge Base
va a ingestar: el almacén de documentos fuente y la base vectorial donde se
guardan los embeddings, junto con sus controles de acceso y credenciales.

## Requirements

### Requirement: Bucket privado y versionado para documentos fuente

El proyecto SHALL proveer un bucket de Amazon S3 dedicado a los documentos
fuente, con versionado activado, todo el acceso público bloqueado y cifrado en
reposo. El bucket SHALL organizar los objetos bajo un prefijo `raw/` para los
documentos originales y reservar `processed/` para uso futuro.

#### Scenario: El bucket de documentos es privado y versionado

- **WHEN** se inspecciona la configuración del bucket de documentos tras crearlo
- **THEN** el "block public access" está activo en sus cuatro flags
- **AND** el versionado de objetos está en estado `Enabled`
- **AND** el cifrado en reposo por defecto está configurado

#### Scenario: Los prefijos de organización existen

- **WHEN** se listan los prefijos de nivel superior del bucket
- **THEN** existen `raw/` y `processed/`

### Requirement: Base vectorial PostgreSQL con pgvector

El proyecto SHALL proveer una instancia gestionada de PostgreSQL dimensionada
para free tier (`db.t3.micro`, 20 GB) con almacenamiento cifrado, y la extensión
`vector` (pgvector) SHALL quedar instalada en la base de datos de la aplicación
para poder usarse como vector store.

#### Scenario: La instancia está disponible y cifrada

- **WHEN** se describe la instancia de base de datos tras crearla
- **THEN** el motor es PostgreSQL en clase `db.t3.micro`
- **AND** `storage_encrypted` es `true`
- **AND** la instancia no es multi-AZ

#### Scenario: La extensión pgvector está instalada

- **WHEN** se conecta a la base de datos de la aplicación y se listan las
  extensiones
- **THEN** la extensión `vector` aparece como instalada

### Requirement: Credenciales de la base de datos gestionadas en Secrets Manager

La contraseña del usuario maestro de la base de datos SHALL generarse
automáticamente y almacenarse en AWS Secrets Manager. La contraseña SHALL NOT
aparecer en el state de Terraform en claro, ni estar hardcodeada en el código,
ni versionada en el repositorio. Los datos no sensibles de conexión (host,
puerto, nombre de la base) SHALL exponerse como outputs de Terraform para que
las fases siguientes los consuman.

#### Scenario: El secreto existe y no está en el state

- **WHEN** se inspecciona AWS Secrets Manager tras crear la instancia
- **THEN** existe un secreto con la contraseña del usuario maestro
- **AND** el archivo de state del stack no contiene esa contraseña en claro

#### Scenario: Ningún archivo versionado contiene la contraseña

- **WHEN** se revisa el repositorio
- **THEN** ningún archivo `.tf`, `.tfvars` ni de documentación contiene la
  contraseña de la base de datos en claro

#### Scenario: La conexión no sensible está disponible como output

- **WHEN** se consultan los outputs del stack tras el apply
- **THEN** están disponibles el host, el puerto y el nombre de la base de datos
- **AND** el ARN del secreto de la contraseña

### Requirement: Acceso de red restringido a la base de datos

El grupo de seguridad de la instancia de base de datos SHALL NOT permitir
ingreso desde `0.0.0.0/0`. El acceso al puerto de PostgreSQL SHALL limitarse al
grupo de seguridad del cómputo del agente y, opcionalmente, a un rango CIDR de
administración configurable para tareas de setup e inspección.

#### Scenario: Sin ingreso público

- **WHEN** se inspeccionan las reglas de ingreso del grupo de seguridad de la
  base de datos
- **THEN** ninguna regla permite `0.0.0.0/0` en el puerto 5432

#### Scenario: El CIDR de administración es opcional

- **WHEN** el rango CIDR de administración se deja sin configurar
- **THEN** el único ingreso permitido al puerto 5432 es desde el grupo de
  seguridad del cómputo del agente
