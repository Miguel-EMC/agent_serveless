## Context

Ver `proposal.md` - Why. Estado actual: commit `2c4075c` dejó el esqueleto
`terraform/{modules/{s3,rds,bedrock-kb,lambda,iam},environments/dev}`,
`lambda/{src,tests}`, `docs/`, más `.gitignore` y `README.md`. OpenSpec está
inicializado pero sin `config.yaml`, sin specs y sin changes previos.

Restricciones del proyecto (del prompt del arquitecto, no negociables):

- Todo con Terraform desde cero, sin plantillas de terceros.
- Remote state en S3 + locking en DynamoDB.
- Un módulo por servicio; IAM de mínimo privilegio, nunca `Action: "*"`.
- Lambda en Python puro (boto3 + SDK Bedrock), sin LangChain / LangGraph /
  LlamaIndex. Empaquetado `.zip` estándar, sin Docker / ECR.
- API Gateway solo se menciona; no se implementa.
- La prueba real es `terraform destroy` + volver a levantar desde cero.
- Caso de uso 100% ficticio. Cero datos/nombres/arquitectura reales de ningún
  empleador.
- Una fase por sesión, con aprobación explícita entre fases.

## Goals / Non-Goals

**Goals:**

- Un layout de carpetas que aguante las 7 fases sin reacomodos.
- Separar el ciclo de vida del *bootstrap* (remote state) del stack principal.
- Dejar el contexto del proyecto en `openspec/config.yaml` para que cada
  cambio futuro lo herede sin repetirlo.
- Un único punto de entrada de workflow (`Makefile`) legible en la charla.
- Nombres de módulos que revelan intención.

**Non-Goals:**

- No se escribe ningún `.tf` con recursos (eso es Fase 1+).
- No se escribe código Python del agente (eso es Fase 4).
- No se decide la región AWS ni el prefijo del bucket de state (input de
  Miguel en Fase 1).
- No se crean los 6 cambios OpenSpec de las fases siguientes; solo se
  documenta el mapeo.

## Decisions

### D1 - State del bootstrap: local, `.tfstate` commiteado

`terraform/bootstrap/` crea el bucket de state y la tabla de lock. No puede
usar el backend `s3` que aún no existe (huevo y gallina), así que usa state
local.

- **Elegido**: state local, y se **commitea** `terraform/bootstrap/terraform.tfstate`.
  No contiene secretos: solo nombre del bucket, nombre de la tabla y ARNs.
- **Alternativa A**: no commitear el state y documentar la recreación manual.
  Rechazada: rompe la promesa de "reproducible desde cero" para el bootstrap.
- **Alternativa B**: tras crear el bucket, migrar el state del propio bootstrap
  a ese bucket (`terraform init -migrate-state`). Más elegante para el relato,
  pero añade un paso frágil en vivo y acopla el bootstrap a su output.
  Se deja como nota en `docs/architecture.md`, no como camino por defecto.

### D2 - IAM: roles co-locados por servicio; `modules/iam` solo transversal

El prompt dice "un módulo por servicio (s3, rds, bedrock-kb, lambda, iam)".
Reinterpretación: el rol de ejecución de la Lambda vive dentro del módulo
`agent-lambda`; el rol de servicio de la Knowledge Base vive dentro de
`bedrock-kb`. `modules/iam` queda reservado para lo verdaderamente
transversal (p. ej. una policy de KMS compartida) y puede terminar vacío.

- **Rationale**: "mínimo privilegio visible por servicio" — el rol se lee al
  lado del recurso al que sirve; un módulo IAM central tiende a volverse un
  cajón de sastre y a acoplar todos los servicios entre sí.
- **Alternativa**: todos los roles en `modules/iam`. Rechazada por acoplamiento
  y por dificultar el `terraform destroy` selectivo por servicio.
- **Nota**: si `modules/iam` acaba sin contenido en la Fase 5, se elimina.

### D3 - Nombres de módulos: renombrar ahora que están vacíos

`s3` -> `s3-documents`, `rds` -> `rds-pgvector`. `lambda` -> `agent-lambda`.
`bedrock-kb` se queda. `iam` se queda.

- **Rationale**: los directorios solo tienen `.gitkeep`; el renombre cuesta
  cero y los nombres con intención se leen mejor en la charla y en los
  `module "..."` del `environments/dev/main.tf`.
- **Trade-off**: diverge del árbol textual del `README` de la Fase 0 — se
  actualiza el `README` en este mismo cambio.

### D4 - Documentos ficticios: `sample-data/` top-level, no en `docs/`

`sample-data/fictional-corp/` con 3 archivos `.md` de políticas inventadas.

- **Rationale**: estos archivos se **suben a un bucket S3 real** en la Fase 6;
  son insumo de datos, no documentación. Mantenerlos separados de `docs/`
  evita confundir "docs del proyecto" con "corpus de la demo".
- **Alternativa**: `lambda/tests/fixtures/`. Rechazada: no son fixtures de
  test unitario, son el corpus de la KB.

### D5 - `Makefile` en la raíz como índice del workflow

Targets: `bootstrap`, `deploy`, `package`, `invoke`, `destroy`, `reproduce`.
Cada target es un wrapper delgado sobre `terraform` o sobre un script de
`scripts/`.

- **Rationale**: en la charla, `cat Makefile` muestra el flujo completo en una
  pantalla. `scripts/` guarda el shell real; el `Makefile` es el mapa.
- **Alternativa**: `Taskfile.yml` (go-task). Rechazada: `make` no necesita
  instalación extra en la mayoría de entornos.

### D6 - `environments/dev/` se mantiene

Aunque la demo es solo `dev`, la capa `environments/` aísla `backend.tf` y
`providers.tf` del stack, y deja la puerta abierta a `stg`/`prod` sin mover
módulos.

### D7 - Mapeo Fase -> cambio OpenSpec (Opción A)

Un cambio por fase. Nombres semánticos en kebab-case, sin prefijo numérico
(OpenSpec ordena por dependencias/estado, no por nombre). El orden secuencial
lo llevan las referencias entre `proposal.md` y los `tasks.md`.

```
Fase 1  remote state       -> add-remote-state-backend
Fase 2  s3 + rds           -> add-document-and-vector-stores
Fase 3  bedrock KB         -> add-bedrock-knowledge-base
Fase 4  código Lambda      -> add-agent-lambda
Fase 5  módulo Lambda + IAM -> deploy-agent-lambda
Fase 6+7 e2e + reproducir  -> prove-end-to-end   (opción (i): un solo cambio
                              cuyos specs son los criterios de aceptación de
                              la capability infra-reproducibility)
```

Capabilities que irán apareciendo al archivar cada cambio:
`document-ingestion`, `semantic-retrieval`, `answer-generation`,
`infra-reproducibility`.

## Risks / Trade-offs

- **[Renombrar módulos rompe referencias]** → No hay referencias todavía
  (los `.tf` no existen); el riesgo es nulo si se hace en este cambio, antes
  de la Fase 1.
- **[`bootstrap/terraform.tfstate` commiteado se percibe como mala práctica]**
  → Se documenta explícitamente en `docs/architecture.md` por qué es aceptable
  aquí (sin secretos, tamaño mínimo, requisito de reproducibilidad del propio
  bootstrap) y que NO aplica al stack principal (ese usa backend `s3`).
- **[`openspec/config.yaml` mal poblado obliga a reescribir cada cambio]** →
  Se limita a hechos estables del prompt del arquitecto (stack, convenciones,
  regla de confidencialidad); nada específico de una fase.
- **[Alcance del cambio se infla a "montar todo el repo"]** → Este cambio NO
  crea contenido `.tf` ni `.py`; solo directorios, `.gitkeep`, `Makefile`,
  `config.yaml`, `architecture.md` y edición de `.gitignore`/`README.md`.

## Migration Plan

No aplica despliegue. La "migración" es puramente de árbol de archivos:

1. `git mv` de los módulos renombrados (preserva historia).
2. Crear directorios nuevos con `.gitkeep`.
3. Escribir `Makefile`, `openspec/config.yaml`, `docs/architecture.md`.
4. Editar `.gitignore` y `README.md`.
5. Commit único: "Establecer estructura del monorepo y contexto OpenSpec".

Rollback: `git revert` del commit; ningún recurso externo tocado.

## Open Questions

- ¿`prove-end-to-end` debe además cronometrar el `apply` desde cero y
  registrarlo en `docs/`? Se puede decidir al llegar a esa fase sin afectar
  esta estructura.
