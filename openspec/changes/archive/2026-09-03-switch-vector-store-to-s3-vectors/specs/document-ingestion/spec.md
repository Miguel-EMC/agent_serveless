## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Base vectorial PostgreSQL con pgvector

**Reason**: El Bedrock Knowledge Base gestionado no puede usar un RDS PostgreSQL
estándar como vector store (requiere la RDS Data API, exclusiva de Aurora). Se
adopta Amazon S3 Vectors, que no necesita una instancia de base de datos.

**Migration**: La instancia `rag-serverless-demo-pgvector` se destruye. Los
embeddings pasan a un índice de S3 Vectors creado en
`add-bedrock-knowledge-base`. No hay datos que migrar: la demo aún no había
ingestado documentos.

### Requirement: Credenciales de la base de datos gestionadas en Secrets Manager

**Reason**: Sin base de datos relacional no hay contraseña de usuario maestro
que gestionar. S3 Vectors se accede con IAM, no con credenciales.

**Migration**: El secreto gestionado por RDS se elimina al destruir la
instancia. El acceso al vector store lo controla el rol IAM de la Knowledge
Base (definido en `add-bedrock-knowledge-base`).

### Requirement: Acceso de red restringido a la base de datos

**Reason**: S3 Vectors es un servicio gestionado sin endpoint de red propio ni
security groups; el control de acceso es por IAM. No hay puerto 5432 que
proteger.

**Migration**: El security group `rag-serverless-demo-db` y sus reglas se
destruyen. El acceso al vector store se restringe con la política del rol IAM
de la Knowledge Base.
