## MODIFIED Requirements

### Requirement: El stack de aplicación se aplica desde cero de forma reproducible

El stack del entorno `dev` SHALL poder aprovisionarse con un único
`terraform apply` partiendo de un directorio local sin state (solo la
configuración de backend), y un `terraform destroy` seguido de un nuevo
`terraform apply` SHALL producir un stack equivalente sin recursos huérfanos.
El ciclo completo de reproducibilidad (destroy → apply → re-ingesta → repetir
la prueba end-to-end) SHALL completarse sin intervención manual de corrección y
con su duración registrada.

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

#### Scenario: Ciclo de reproducibilidad cronometrado

- **WHEN** se ejecuta `terraform destroy` del stack `dev`, luego `terraform
  apply` desde cero, se re-ingestan los documentos y se repite la prueba
  end-to-end
- **THEN** el sistema vuelve a responder correctamente citando las fuentes
- **AND** ningún paso requirió corregir a mano un recurso huérfano o una
  dependencia rota
- **AND** la duración total del ciclo queda registrada en `docs/`
