## MODIFIED Requirements

### Requirement: La respuesta cita sus fuentes

La salida del agente SHALL incluir, además del texto de la respuesta, la lista
de documentos de origen de los fragmentos usados (ubicación en S3) y cuántos
fragmentos se usaron. En una prueba end-to-end con documentos reales, para una
pregunta cuya respuesta está en un documento concreto, ese documento SHALL
aparecer entre las fuentes citadas.

#### Scenario: La salida incluye las fuentes

- **WHEN** el agente responde una pregunta usando contexto
- **THEN** la salida contiene un campo con la respuesta en texto
- **AND** un campo con la lista de documentos de origen y su score
- **AND** el número de fragmentos usados

#### Scenario: La fuente citada es la que contiene la respuesta

- **WHEN** se invoca el agente con una pregunta cuya respuesta está en un
  documento ficticio concreto del corpus de prueba
- **THEN** ese documento aparece en la lista de `sources` de la salida
- **AND** el texto de la respuesta es coherente con el contenido de ese
  documento
