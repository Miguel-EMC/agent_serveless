# agent_serveless

Agente de IA **100% serverless en AWS**, construido para una charla de AWS
Community Day Ecuador (Cuenca). El caso de uso es **ficticio**: no contiene
datos, arquitectura ni nombres reales de ningún empleador.

## Qué hace

Un agente RAG (Retrieval-Augmented Generation) que responde preguntas
citando la fuente, usando únicamente servicios administrados de AWS —
sin servidores que mantener y sin frameworks de orquestación (LangChain,
LangGraph, LlamaIndex).

## Arquitectura

```
Documentos (S3) → Bedrock Knowledge Base → RDS PostgreSQL + pgvector
                                                    │
                                                    ▼
                        Lambda (Python + boto3) ──► Bedrock (modelo)
                                                    │
                                                    ▼
                                        Respuesta con cita de la fuente
```

- **S3**: almacena los documentos fuente (texto/PDF) del caso de uso ficticio.
- **Amazon Bedrock Knowledge Base**: ingesta y chunking (512 tokens, 20% de
  overlap), embeddings con Titan Text Embeddings.
- **RDS PostgreSQL + pgvector**: base vectorial (free tier: `db.t3.micro`,
  20GB). No se usa Aurora ni OpenSearch Serverless.
- **AWS Lambda**: orquesta el agente en Python puro (boto3 + SDK de
  Bedrock), sin frameworks de orquestación — cada paso (retrieval, prompt,
  llamada al modelo) es código explícito.
- **Amazon Bedrock (modelo)**: genera la respuesta final con el contexto
  recuperado, citando el documento/chunk usado.
- **API Gateway**: solo se menciona como paso de producción; en esta demo
  el Lambda se invoca directamente (consola o AWS CLI).

Todo el despliegue es con **Terraform** desde cero (sin plantillas de
terceros), con remote state en S3 + locking en DynamoDB, módulos propios
por servicio, e IAM de mínimo privilegio en cada rol.

## Estructura del repositorio

```
/terraform
  /modules            # un módulo por servicio: s3, rds, bedrock-kb, lambda, iam
  /environments/dev    # configuración del entorno de desarrollo
/lambda
  /src                 # código Python del agente
  /tests
/docs
```

## Estado del proyecto

Se construye por fases, cada una con su propia aprobación antes de avanzar
a la siguiente:

1. Setup del proyecto (esta fase)
2. Remote state (S3 + DynamoDB)
3. Módulos S3 (documentos) y RDS (pgvector)
4. Módulo Bedrock Knowledge Base
5. Código Python del Lambda
6. Módulo Lambda + IAM + despliegue
7. Prueba end-to-end
8. Prueba de reproducibilidad (`terraform destroy` + `apply` desde cero)

## Cómo se despliega

Instrucciones detalladas de despliegue (Terraform) se agregan a medida que
se completan las fases de infraestructura.
