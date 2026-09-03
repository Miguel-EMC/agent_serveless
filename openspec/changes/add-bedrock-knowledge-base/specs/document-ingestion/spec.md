## MODIFIED Requirements

### Requirement: Vector store gestionado para los embeddings

El proyecto SHALL usar **Amazon S3 Vectors** como vector store gestionado para
los embeddings, sin operar una base de datos propia. SHALL existir un vector
bucket de S3 Vectors y, dentro, un índice vectorial con:

- `distance_metric` = `cosine`,
- `data_type` = `float32`,
- `dimension` igual a la dimensión del modelo de embeddings de la Knowledge
  Base,
- las claves de metadatos `AMAZON_BEDROCK_TEXT` y `AMAZON_BEDROCK_METADATA`
  marcadas como **no filtrables** (requisito de Bedrock).

El contenido SHALL estar cifrado en reposo y el vector bucket SHALL NOT ser de
acceso público.

#### Scenario: No hay base de datos que operar

- **WHEN** se revisa la infraestructura del proyecto
- **THEN** no existe ninguna instancia de base de datos relacional para los
  embeddings
- **AND** no hay credenciales de base de datos que gestionar ni rotar

#### Scenario: El índice de vectores coincide con el modelo de embeddings

- **WHEN** se inspecciona el índice de S3 Vectors tras crearlo
- **THEN** su `dimension` es igual a la dimensión configurada en el modelo de
  embeddings de la Knowledge Base
- **AND** su `distance_metric` es `cosine`
- **AND** `AMAZON_BEDROCK_TEXT` y `AMAZON_BEDROCK_METADATA` están entre las
  claves de metadatos no filtrables

#### Scenario: El vector store es privado y cifrado

- **WHEN** se inspecciona el vector bucket tras crearlo
- **THEN** su contenido está cifrado en reposo
- **AND** no es accesible de forma anónima o pública

## ADDED Requirements

### Requirement: Configuración de ingesta de la Knowledge Base

SHALL existir una Amazon Bedrock Knowledge Base con un data source de tipo S3
apuntando al prefijo `raw/` del bucket de documentos, que trocea el contenido en
fragmentos de tamaño fijo de **512 tokens con 20% de solapamiento** y genera los
embeddings con **Amazon Titan Text Embeddings v2**. La KB SHALL usar el índice
de S3 Vectors como storage. La KB SHALL asumir un rol IAM de mínimo privilegio
(sin `Action: "*"`) con acceso solo a: el modelo de embeddings, el bucket de
documentos en lectura, y el índice de vectores.

#### Scenario: Data source con chunking y fuente correctos

- **WHEN** se describe el data source de la Knowledge Base
- **THEN** su fuente es el bucket de documentos, prefijo `raw/`
- **AND** la estrategia de chunking es de tamaño fijo, 512 tokens, 20% de
  solapamiento

#### Scenario: La KB usa Titan Text Embeddings v2 y S3 Vectors

- **WHEN** se describe la Knowledge Base
- **THEN** el modelo de embeddings es Titan Text Embeddings v2
- **AND** el storage es el índice de S3 Vectors creado para el proyecto

#### Scenario: El rol de la KB es de mínimo privilegio

- **WHEN** se revisa la política del rol IAM de la Knowledge Base
- **THEN** no contiene `Action: "*"` ni `Resource: "*"` sin acotar
- **AND** solo concede acceso al modelo de embeddings, al bucket de documentos
  en lectura y al índice de vectores
- **AND** la relación de confianza limita el uso del rol a Bedrock para esta
  cuenta (condiciones `aws:SourceAccount` y `aws:SourceArn`)
