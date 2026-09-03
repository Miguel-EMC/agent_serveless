## ADDED Requirements

### Requirement: El agente recupera contexto con la operación Retrieve

El agente SHALL consultar la Knowledge Base con la operación `Retrieve` de
`bedrock-agent-runtime` (no `RetrieveAndGenerate`), pasando el texto de la
pregunta y un número de resultados configurable (`top_k`). El agente SHALL
normalizar cada resultado a `{texto, documento_de_origen, score}` y SHALL
descartar los que estén por debajo de un umbral de score configurable.

#### Scenario: Retrieve con top-k

- **WHEN** el agente recibe una pregunta
- **THEN** llama a `Retrieve` con el `knowledgeBaseId` de la KB y
  `numberOfResults = top_k`
- **AND** convierte `retrievalResults` en una lista de
  `{texto, documento_de_origen, score}`

#### Scenario: Filtro por umbral de score

- **WHEN** algún resultado de `Retrieve` tiene un score por debajo del umbral
  configurado
- **THEN** ese resultado no se incluye en el contexto que se pasa al modelo

#### Scenario: Cada fragmento conserva su documento de origen

- **WHEN** se normaliza un resultado de `Retrieve`
- **THEN** conserva la ubicación en S3 del documento del que proviene
