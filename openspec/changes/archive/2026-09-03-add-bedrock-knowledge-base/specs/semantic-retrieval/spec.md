## Purpose

Cubre la recuperación de contexto relevante para una pregunta: la base de
conocimiento consultable que, dado un texto, devuelve los fragmentos de
documento más parecidos junto con la fuente de la que provienen.

## ADDED Requirements

### Requirement: Base de conocimiento consultable

SHALL existir una Amazon Bedrock Knowledge Base, con estado activo, que pueda
responder consultas de recuperación (`Retrieve`) sobre el corpus ingestado. La
KB SHALL exponer un identificador estable que las fases siguientes (la Lambda
del agente) usan para consultarla.

#### Scenario: La Knowledge Base está disponible

- **WHEN** se describe la Knowledge Base tras el `apply`
- **THEN** su estado es activo
- **AND** su identificador se expone como output del stack

#### Scenario: Retrieve devuelve fragmentos con su fuente

- **WHEN** hay al menos un documento ingestado y se hace una consulta
  `Retrieve` con una pregunta relacionada
- **THEN** la respuesta incluye uno o más fragmentos de texto
- **AND** cada fragmento indica el documento de origen (ubicación en S3)

### Requirement: La recuperación no depende de cómputo propio

La recuperación SHALL apoyarse en el servicio gestionado (Bedrock Knowledge
Base + S3 Vectors), sin que el proyecto opere una base de datos, un motor de
búsqueda ni un servidor de embeddings.

#### Scenario: Sin infraestructura de búsqueda propia

- **WHEN** se revisa la infraestructura del proyecto
- **THEN** no hay instancias de base de datos, clústeres de búsqueda ni
  servidores de modelos administrados por el proyecto para la recuperación
