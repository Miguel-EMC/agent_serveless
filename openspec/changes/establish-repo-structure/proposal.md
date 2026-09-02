## Why

El repo tiene el esqueleto mínimo de la Fase 0 (`terraform/`, `lambda/`, `docs/`)
pero le faltan piezas que todas las fases siguientes van a necesitar: el
directorio `bootstrap/` para el remote state, un lugar para los documentos
ficticios de la demo, scripts de build/deploy, y el contexto de OpenSpec del
proyecto (`openspec/config.yaml`). Definir esta estructura ahora, antes de
escribir Terraform, evita reacomodar carpetas a mitad de la construcción por
fases y deja un layout que se lee claro en la charla.

## What Changes

- Renombrar los módulos vacíos a nombres que revelan intención:
  `terraform/modules/s3` -> `terraform/modules/s3-documents`,
  `terraform/modules/rds` -> `terraform/modules/rds-pgvector`.
  Se mantienen `bedrock-kb`, `lambda` (como `agent-lambda`) e `iam`.
- Crear `terraform/bootstrap/` como raíz Terraform separada (state local) para
  el bucket de remote state + tabla de lock de la Fase 1.
- Crear `sample-data/fictional-corp/` para los documentos ficticios que
  alimentan la Knowledge Base en la demo (fuera de `docs/`).
- Crear `scripts/` para los helpers de flujo (`package-lambda.sh`,
  `invoke-lambda.sh`, `sync-knowledge-base.sh`).
- Añadir un `Makefile` en la raíz como único punto de entrada del workflow
  (`bootstrap`, `deploy`, `package`, `invoke`, `destroy`, `reproduce`).
- Reorganizar `lambda/src/` como paquete `agent/` (`handler.py`, `retrieval.py`,
  `prompt.py`, `generation.py`, `errors.py`) y añadir `lambda/requirements.txt`,
  `lambda/requirements-dev.txt`, `lambda/dist/` (gitignored).
- Escribir `openspec/config.yaml` con el contexto del proyecto (stack,
  convenciones: Terraform desde cero, IAM de mínimo privilegio, sin frameworks
  de orquestación, caso de uso 100% ficticio) y las rules por artefacto.
- Escribir `docs/architecture.md` con el árbol de carpetas de referencia y la
  tabla de decisiones estructurales (state del bootstrap, IAM co-locado vs
  módulo compartido, nombres de módulos, ubicación de datos de ejemplo).
- Actualizar `.gitignore` (`lambda/dist/`) y el `README.md` (sección de
  estructura) para reflejar el layout nuevo.
- Definir el mapeo Fase -> cambio OpenSpec (Opción A: un cambio por fase),
  documentado en `docs/architecture.md`.

Sin cambios de comportamiento: no se escribe lógica de infraestructura ni de
aplicación en este cambio. Es puramente estructura, tooling y documentación.

## Capabilities

### New Capabilities

Ninguna. Este cambio no introduce comportamiento observable; solo prepara el
layout del repo y el contexto de OpenSpec. Se marca `skip_specs: true` en
`.openspec.yaml`.

### Modified Capabilities

Ninguna.

## Impact

- **Estructura de carpetas**: renombres bajo `terraform/modules/`, nuevos
  directorios top-level (`sample-data/`, `scripts/`), nueva raíz Terraform
  (`terraform/bootstrap/`), reorganización de `lambda/src/`.
- **Tooling**: nuevo `Makefile`, nuevo `openspec/config.yaml`.
- **Docs**: nuevo `docs/architecture.md`; `README.md` actualizado.
- **Sin impacto en**: AWS (no se despliega nada), dependencias de runtime,
  APIs. Ningún `terraform apply`.
- **Cabo suelto que se resuelve**: `terraform/bootstrap/.terraform/` (cache de
  provider huérfano, sin `.tf`) queda legitimado al crear los `.tf` del
  bootstrap en la Fase 1; aquí solo se crea el directorio y su `README.md`.
