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

### Requirement: El stack de aplicación se aplica desde cero de forma reproducible

El stack del entorno `dev` SHALL poder aprovisionarse con un único
`terraform apply` partiendo de un directorio local sin state (solo la
configuración de backend), y un `terraform destroy` seguido de un nuevo
`terraform apply` SHALL producir un stack equivalente sin recursos huérfanos.

#### Scenario: Apply del stack desde un checkout limpio

- **WHEN** se clona el repo, se corre `terraform init` del stack `dev` contra el
  backend `s3` y luego `terraform apply`
- **THEN** se crean todos los recursos del stack (bucket de documentos y, según
  la fase, el vector store gestionado y la Knowledge Base)
- **AND** no se crea ningún archivo de state local para el stack

#### Scenario: Destroy y re-apply del stack

- **WHEN** se ejecuta `terraform destroy` del stack `dev` y a continuación
  `terraform apply`
- **THEN** el segundo `apply` recrea el stack completo
- **AND** no quedan recursos huérfanos del ciclo anterior

### Requirement: El agente se despliega como Lambda con rol de mínimo privilegio

El agente SHALL desplegarse como una función AWS Lambda empaquetada en un
archivo `.zip` estándar (sin contenedores ni ECR), con un runtime de Python
fijo. El rol de ejecución de la función SHALL ser de mínimo privilegio, sin
`Action: "*"` ni `Resource: "*"`, y su acceso SHALL limitarse a: escribir en su
propio grupo de logs de CloudWatch, `bedrock:InvokeModel` sobre el modelo de
generación configurado, y `bedrock:Retrieve` sobre la Knowledge Base del
proyecto. La configuración de la función (id de la KB, modelo, top-k, umbral)
SHALL pasarse por variables de entorno, sin hardcodear.

#### Scenario: La función está empaquetada como zip estándar

- **WHEN** se inspecciona la función Lambda tras el `apply`
- **THEN** su tipo de paquete es `Zip`
- **AND** su runtime es una versión de Python
- **AND** su handler apunta al entrypoint del agente

#### Scenario: El rol de ejecución es de mínimo privilegio

- **WHEN** se revisa la política del rol de ejecución de la función
- **THEN** no contiene `Action: "*"` ni `Resource: "*"` sin acotar
- **AND** solo concede escritura de logs sobre el grupo de logs de la función,
  `bedrock:InvokeModel` sobre el modelo configurado y `bedrock:Retrieve` sobre
  la Knowledge Base

#### Scenario: La configuración va por variables de entorno

- **WHEN** se inspeccionan las variables de entorno de la función
- **THEN** incluyen el id de la Knowledge Base y el id del modelo
- **AND** ningún archivo del repositorio hardcodea esos valores en el código del
  agente
