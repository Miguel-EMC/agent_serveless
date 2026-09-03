## MODIFIED Requirements

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
