# Arquitectura del repo

Referencia viva del layout del monorepo y de las decisiones estructurales.
El *por qué* detallado de cada decisión está en
`openspec/changes/establish-repo-structure/design.md`.

## Componentes AWS (recordatorio)

```
Documentos (S3) --> Bedrock Knowledge Base --> RDS PostgreSQL + pgvector
                                                       |
                                                       v
                           Lambda (Python + boto3) --> Bedrock (modelo)
                                                       |
                                                       v
                                     Respuesta con cita de la fuente
```

API Gateway solo se menciona como paso de producción; no se implementa en la
demo (el Lambda se invoca directo por consola o AWS CLI).

## Árbol de carpetas

```
agent_serveless/
|
+-- README.md
+-- .gitignore
+-- Makefile                        # unico punto de entrada del workflow
|
+-- openspec/
|   +-- config.yaml                 # contexto + rules del proyecto (heredado por cada cambio)
|   +-- specs/                      # capabilities vivas (se llenan al archivar cada cambio)
|   +-- changes/                    # un cambio por fase (Opcion A)
|       +-- archive/
|
+-- terraform/
|   +-- bootstrap/                  # Fase 1 -- raiz Terraform SEPARADA, state LOCAL
|   |   +-- README.md               # "correr una vez, primero; sin backend s3"
|   |   +-- (main.tf, variables.tf, outputs.tf, terraform.tfstate)   # se crean en Fase 1
|   |
|   +-- modules/                    # reutilizables -- sin bloques provider/backend
|   |   +-- s3-documents/           # bucket de documentos fuente
|   |   +-- rds-pgvector/           # instancia PostgreSQL + extension pgvector
|   |   |   +-- sql/enable-pgvector.sql
|   |   +-- bedrock-kb/             # Knowledge Base + su rol IAM de servicio
|   |   +-- agent-lambda/           # funcion Lambda + su rol de ejecucion
|   |   +-- iam/                    # SOLO lo transversal (puede quedar vacio)
|   |
|   +-- environments/
|       +-- dev/                    # raiz que cablea los modulos; backend "s3"
|           +-- (backend.tf, providers.tf, main.tf, variables.tf, outputs.tf,
|               terraform.tfvars, terraform.tfvars.example)          # se crean por fases
|
+-- lambda/
|   +-- src/
|   |   +-- agent/                  # paquete Python del agente
|   |       +-- __init__.py
|   |       +-- handler.py          # lambda_handler (entrypoint)
|   |       +-- retrieval.py        # Retrieve contra la Knowledge Base
|   |       +-- prompt.py           # armado del prompt con contexto
|   |       +-- generation.py       # Bedrock Converse API
|   |       +-- errors.py           # manejo de errores
|   +-- tests/
|   |   +-- events/sample-question.json
|   +-- dist/                       # .zip construido (gitignored)
|   +-- requirements.txt            # runtime -- vacio a proposito (boto3 en el runtime)
|   +-- requirements-dev.txt        # pytest, etc.
|
+-- sample-data/
|   +-- fictional-corp/             # documentos ficticios que alimentan la KB en la demo
|
+-- scripts/
|   +-- package-lambda.sh           # construye el .zip estandar desde lambda/src
|   +-- invoke-lambda.sh            # aws lambda invoke con un evento de ejemplo
|   +-- sync-knowledge-base.sh      # dispara el ingestion job de la KB
|
+-- docs/
    +-- architecture.md             # este archivo
    +-- cost-estimate.md            # salida de la Fase 6
    +-- runbook.md                  # deploy / destroy / reproducir
```

Los archivos entre paréntesis todavía no existen: se crean en la fase indicada.

## Decisiones estructurales

| #  | Decisión | Resolución |
|----|----------|------------|
| D1 | State del bootstrap | State **local**; `terraform/bootstrap/terraform.tfstate` **se commitea**. No tiene secretos (solo nombres y ARNs del bucket y la tabla) y hace que el propio bootstrap sea reproducible desde cero. La alternativa de migrar el state del bootstrap a su propio bucket queda documentada pero no es el camino por defecto (paso frágil en vivo). **Esto NO aplica al stack principal**, que usa backend `s3`. |
| D2 | IAM: módulo compartido vs co-locado | Cada rol vive en el módulo del servicio al que sirve (rol de ejecución en `agent-lambda`, rol de servicio de la KB en `bedrock-kb`). `modules/iam` queda solo para lo transversal (p. ej. una policy de KMS) y se elimina si acaba vacío en la Fase 5. Reinterpreta el "un módulo por servicio, incl. iam" del prompt a favor de "mínimo privilegio visible por servicio". |
| D3 | Nombres de módulos | Renombrados mientras estaban vacíos: `s3` -> `s3-documents`, `rds` -> `rds-pgvector`, `lambda` -> `agent-lambda`. `bedrock-kb` e `iam` se quedan. |
| D4 | Ubicación de datos de ejemplo | `sample-data/fictional-corp/` top-level, **fuera de `docs/`**: son insumo de datos (se suben a un bucket S3 real en la Fase 6), no documentación. |
| D5 | Punto de entrada del workflow | `Makefile` en la raíz (`bootstrap`, `deploy`, `package`, `invoke`, `destroy`, `reproduce`, `help`). `scripts/` guarda el shell real; el `Makefile` es el mapa que se lee en una pantalla durante la charla. |
| D6 | Capa `environments/dev/` | Se mantiene aunque la demo sea solo `dev`: aísla `backend.tf` y `providers.tf`, y deja la puerta abierta a `stg`/`prod` sin mover módulos. |
| D7 | Mapeo Fase -> cambio OpenSpec | Opción A: un cambio por fase, nombres semánticos en kebab-case, sin prefijo numérico (OpenSpec ordena por dependencias/estado). Ver tabla abajo. |

## Mapeo Fase -> cambio OpenSpec (Opción A)

| Fase | Cambio OpenSpec | Capabilities que toca |
|------|-----------------|-----------------------|
| 0 | (commit `2c4075c`, previo a OpenSpec) | -- |
| 0.5 | `establish-repo-structure` ✔ archivado | -- (estructura/tooling, `skip_specs`) |
| 1 | `add-remote-state-backend` ✔ archivado | `infra-reproducibility` |
| 2 | `add-document-and-vector-stores` ✔ hecho | `document-ingestion`, `infra-reproducibility` |
| 3 | `add-bedrock-knowledge-base` | `document-ingestion`, `semantic-retrieval` |
| 4 | `add-agent-lambda` | `semantic-retrieval`, `answer-generation` |
| 5 | `deploy-agent-lambda` | `infra-reproducibility` |
| 6 + 7 | `prove-end-to-end` | valida todas (specs = criterios de aceptación de `infra-reproducibility`) |

Fases 6 y 7 (prueba e2e + reproducibilidad) se juntan en un solo cambio porque
no aportan una capability nueva: son ejercicios de validación cuyos specs son
los criterios de aceptación.

## Convenciones

- Una fase por sesión, con aprobación explícita de Miguel entre fases.
- Un commit por fase; rama dedicada, nunca `main` directo.
- Terraform desde cero, sin plantillas de terceros.
- IAM de mínimo privilegio en todo rol; nunca `Action: "*"`.
- Lambda en Python puro con boto3; sin LangChain / LangGraph / LlamaIndex.
- Empaquetado `.zip` estándar; sin Docker / ECR.
- Caso de uso 100% ficticio (regla de confidencialidad en `openspec/config.yaml`).

## Caveats conocidos

- **VPC**: el stack `environments/dev/` asume que la cuenta tiene su **VPC
  default** en `us-east-1` (el módulo `rds-pgvector` construye el
  `db_subnet_group` desde sus subredes). Si se borrara, hay que añadir un módulo
  `network` con una VPC mínima (ver `add-document-and-vector-stores/design.md`
  DD1).
- **RDS `publicly_accessible = true`**: la instancia tiene endpoint público pero
  el Security Group no abre `0.0.0.0/0` — el acceso real lo controla el SG
  (solo la Lambda + un `admin_cidr` opcional). Endurecer a privado + bastión es
  trabajo post-demo.
