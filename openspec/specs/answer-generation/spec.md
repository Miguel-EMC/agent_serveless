# answer-generation

## Purpose

Cubre la generación de la respuesta final del agente: a partir de una pregunta y
unos fragmentos de contexto recuperados, produce una respuesta en lenguaje
natural que se apoya solo en ese contexto y cita las fuentes usadas.

## Requirements

### Requirement: Respuesta acotada al contexto recuperado

El agente SHALL construir el prompt del modelo incluyendo únicamente los
fragmentos recuperados de la Knowledge Base, e instruir al modelo para que
responda **solo** con esa información. Si los fragmentos recuperados no alcanzan
(lista vacía o todos por debajo del umbral de score configurado), el agente
SHALL responder que no encontró información en los documentos, sin inventar.

#### Scenario: Pregunta respondible con el contexto

- **WHEN** se invoca el agente con una pregunta y la recuperación devuelve
  fragmentos relevantes
- **THEN** la respuesta se genera con la API Converse de Bedrock
- **AND** el prompt enviado al modelo contiene los fragmentos recuperados y la
  instrucción de responder solo con ellos

#### Scenario: Sin contexto suficiente

- **WHEN** la recuperación no devuelve fragmentos, o todos están por debajo del
  umbral de score
- **THEN** el agente responde explícitamente que no encontró información en los
  documentos
- **AND** no llama al modelo de generación

### Requirement: La respuesta cita sus fuentes

La salida del agente SHALL incluir, además del texto de la respuesta, la lista
de documentos de origen de los fragmentos usados (ubicación en S3) y cuántos
fragmentos se usaron.

#### Scenario: La salida incluye las fuentes

- **WHEN** el agente responde una pregunta usando contexto
- **THEN** la salida contiene un campo con la respuesta en texto
- **AND** un campo con la lista de documentos de origen y su score
- **AND** el número de fragmentos usados

### Requirement: Errores del modelo controlados

Los fallos al llamar a Bedrock (throttling, acceso denegado, timeout, respuesta
vacía) SHALL capturarse y devolverse como un error legible con un código de
estado apropiado, sin exponer trazas internas.

#### Scenario: Bedrock no responde

- **WHEN** la llamada a Converse falla con un error de cliente
- **THEN** el agente devuelve un objeto de error con un mensaje corto y un
  `statusCode` 4xx o 5xx
- **AND** no propaga la excepción ni incluye el stack trace en la salida
