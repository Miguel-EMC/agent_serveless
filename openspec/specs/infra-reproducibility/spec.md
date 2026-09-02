# infra-reproducibility

## Purpose

Garantiza que toda la infraestructura del agente RAG se pueda crear, destruir y
volver a crear desde cero de forma determinista con Terraform, empezando por el
backend de estado (remote state + locking) del que depende todo lo demás.

## Requirements

### Requirement: Remote state store privado y versionado

El proyecto SHALL proveer un bucket de Amazon S3 dedicado al Terraform state,
con versionado de objetos activado, todo el acceso público bloqueado y cifrado
en reposo.

#### Scenario: El bucket de state rechaza acceso público

- **WHEN** se inspecciona la configuración del bucket de state tras crearlo
- **THEN** el "block public access" está activo en sus cuatro flags
- **AND** el versionado de objetos está en estado `Enabled`
- **AND** el cifrado en reposo por defecto está configurado

#### Scenario: Una versión anterior del state se puede recuperar

- **WHEN** se sobrescribe el archivo de state y luego se listan las versiones
  del objeto
- **THEN** la versión anterior del state sigue disponible en el bucket

### Requirement: Locking del state

El proyecto SHALL proveer una tabla de Amazon DynamoDB con clave primaria
`LockID` para que dos ejecuciones simultáneas de Terraform no puedan corromper
el state.

#### Scenario: Segundo apply concurrente es bloqueado

- **WHEN** una ejecución de Terraform mantiene el lock y se lanza una segunda
  ejecución sobre el mismo state
- **THEN** la segunda ejecución falla o espera con un error de lock en vez de
  escribir el state

### Requirement: El bootstrap del backend es reproducible por sí solo

La creación del remote state y del locking SHALL poder ejecutarse desde un
checkout limpio con un único comando, sin depender del backend `s3` que crea
(sin problema de huevo y gallina). Su propio state SHALL quedar bajo control de
versiones para que el bootstrap sea reproducible sin recursos externos.

#### Scenario: Bootstrap desde cero

- **WHEN** alguien clona el repo y ejecuta el comando de bootstrap con
  credenciales AWS válidas
- **THEN** se crean el bucket de state y la tabla de lock
- **AND** el bootstrap no requiere que el bucket o la tabla existan de antemano

#### Scenario: El state del bootstrap viaja con el repo

- **WHEN** se revisa el repositorio tras el bootstrap
- **THEN** el archivo de state del bootstrap está versionado
- **AND** no contiene secretos (solo nombres, ARNs e identificadores de recursos)

### Requirement: Separación de ciclo de vida entre bootstrap y stack principal

Destruir el stack principal SHALL NOT destruir el remote state ni la tabla de
locking. El bootstrap y el stack principal SHALL ser raíces de Terraform
independientes.

#### Scenario: Destroy del stack principal conserva el backend

- **WHEN** se ejecuta `terraform destroy` sobre el stack del entorno `dev`
- **THEN** el bucket de state y la tabla de lock siguen existiendo
- **AND** un `terraform apply` posterior del stack vuelve a leer el state
  guardado en el bucket

### Requirement: El stack principal usa el remote backend

El entorno `dev` SHALL almacenar su state en el bucket de S3 del backend, con
locking a través de la tabla de DynamoDB, y con el state cifrado.

#### Scenario: init del stack apunta al backend s3

- **WHEN** se inicializa el stack del entorno `dev`
- **THEN** Terraform reporta el backend `s3` con el bucket y la tabla del
  bootstrap
- **AND** no se crea ningún archivo de state local para el stack principal
