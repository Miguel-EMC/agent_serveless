## MODIFIED Requirements

### Requirement: Base de conocimiento consultable

SHALL existir una Amazon Bedrock Knowledge Base, con estado activo, que pueda
responder consultas de recuperación (`Retrieve`) sobre el corpus ingestado. La
KB SHALL exponer un identificador estable que las fases siguientes (la Lambda
del agente) usan para consultarla. Con al menos un documento ingestado, una
consulta `Retrieve` relacionada con ese documento SHALL devolver fragmentos
provenientes del documento correcto.

#### Scenario: La Knowledge Base está disponible

- **WHEN** se describe la Knowledge Base tras el `apply`
- **THEN** su estado es activo
- **AND** su identificador se expone como output del stack

#### Scenario: Retrieve devuelve fragmentos con su fuente

- **WHEN** hay documentos ingestados y se hace una consulta `Retrieve` con una
  pregunta cuya respuesta está en un documento concreto
- **THEN** la respuesta incluye uno o más fragmentos de texto
- **AND** cada fragmento indica el documento de origen (ubicación en S3)
- **AND** el fragmento de mayor score proviene del documento que contiene la
  respuesta
