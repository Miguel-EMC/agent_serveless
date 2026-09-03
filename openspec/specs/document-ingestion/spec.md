# document-ingestion

## Purpose

Cubre la preparación y disponibilidad del material que la Bedrock Knowledge Base
va a ingestar: el almacén de documentos fuente y el vector store gestionado
donde se guardan los embeddings, junto con sus controles de acceso.

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

### Requirement: Vector store gestionado para los embeddings

El proyecto SHALL usar un vector store **gestionado** por AWS para guardar los
embeddings, sin operar una base de datos propia. El vector store SHALL estar
cifrado en reposo y no ser accesible públicamente. El detalle del servicio
concreto (Amazon S3 Vectors) y su índice lo define `add-bedrock-knowledge-base`.

#### Scenario: No hay base de datos que operar

- **WHEN** se revisa la infraestructura del proyecto
- **THEN** no existe ninguna instancia de base de datos relacional para los
  embeddings
- **AND** no hay credenciales de base de datos que gestionar ni rotar

#### Scenario: El vector store es privado y cifrado

- **WHEN** se inspecciona el vector store gestionado tras crearlo
- **THEN** su contenido está cifrado en reposo
- **AND** no es accesible de forma anónima o pública
