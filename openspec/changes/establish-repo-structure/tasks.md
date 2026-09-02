## 1. Renombrar módulos Terraform

- [x] 1.1 `git mv terraform/modules/s3 terraform/modules/s3-documents` y verificar con `git status` que aparece como rename (R)
- [x] 1.2 `git mv terraform/modules/rds terraform/modules/rds-pgvector` y verificar rename en `git status`
- [x] 1.3 `git mv terraform/modules/lambda terraform/modules/agent-lambda` y verificar rename en `git status`
- [x] 1.4 Confirmar que `terraform/modules/` contiene exactamente: `s3-documents/`, `rds-pgvector/`, `bedrock-kb/`, `agent-lambda/`, `iam/`, cada uno con su `.gitkeep` (`find terraform/modules -name .gitkeep | wc -l` == 5)

## 2. Nuevos directorios

- [x] 2.1 Crear `terraform/bootstrap/` con `.gitkeep` y un `terraform/bootstrap/README.md` que explique "correr una vez, primero; state local, sin backend s3" (verificar que el archivo existe y describe el propósito)
- [x] 2.2 Crear `sample-data/fictional-corp/` con `.gitkeep` (verificar `test -d sample-data/fictional-corp`)
- [x] 2.3 Crear `scripts/` con `.gitkeep` (verificar `test -d scripts`)
- [x] 2.4 Confirmar que ningún directorio nuevo contiene `.tf` ni `.py` (`find terraform/bootstrap sample-data scripts -name '*.tf' -o -name '*.py' | wc -l` == 0)

## 3. Reorganizar el paquete Lambda

- [x] 3.1 Crear `lambda/src/agent/` con `__init__.py` vacío y placeholders vacíos `handler.py`, `retrieval.py`, `prompt.py`, `generation.py`, `errors.py` (cada uno solo con un docstring de una línea sobre su rol); eliminar `lambda/src/.gitkeep`
- [x] 3.2 Crear `lambda/requirements.txt` (comentario: "boto3 viene en el runtime; vacío a propósito") y `lambda/requirements-dev.txt` (`pytest`)
- [x] 3.3 Crear `lambda/tests/events/sample-question.json` con un evento de ejemplo `{"question": "..."}` y dejar `lambda/tests/.gitkeep`
- [x] 3.4 Verificar `python -c "import ast; [ast.parse(open(f).read()) for f in __import__('glob').glob('lambda/src/agent/*.py')]"` (los placeholders parsean)

## 4. Makefile

- [x] 4.1 Crear `Makefile` en la raíz con targets `bootstrap`, `deploy`, `package`, `invoke`, `destroy`, `reproduce`, `help` (default). Cada target no implementado imprime `@echo "TODO: Fase N"` en vez de fallar
- [x] 4.2 Verificar `make help` lista los 6 targets y `make` sin argumentos no devuelve error

## 5. Contexto OpenSpec

- [x] 5.1 Escribir `openspec/config.yaml` con `context` (stack: AWS serverless, Terraform, Python+boto3; convenciones: Terraform desde cero sin plantillas de terceros, remote state S3+DynamoDB, un módulo por servicio, IAM mínimo privilegio nunca `Action:"*"`, sin frameworks de orquestación, empaquetado .zip estándar, API Gateway no se implementa, caso de uso 100% ficticio, una fase por sesión con aprobación explícita)
- [x] 5.2 Añadir a `openspec/config.yaml` las `rules` por artefacto que apliquen (p. ej. proposal: declarar siempre la regla de confidencialidad; design: preferir alternativas consideradas explícitas)
- [x] 5.3 Verificar `openspec context` refleja el contenido nuevo y `openspec validate --strict` no reporta errores de config (config parseada sin warnings; `context` y `operations.apply.guidance` visibles vía `openspec instructions apply --json`)

## 6. Documentación

- [x] 6.1 Escribir `docs/architecture.md` con: el árbol de carpetas completo del repo, la tabla de decisiones D1–D7 (resumida desde `design.md`), y el mapeo Fase -> cambio OpenSpec (Opción A). Eliminar `docs/.gitkeep`
- [x] 6.2 Verificar que `docs/architecture.md` menciona por qué `bootstrap/terraform.tfstate` se commitea y que eso NO aplica al stack principal

## 7. Ajustes de repo existentes

- [x] 7.1 Añadir `lambda/dist/` a `.gitignore` y verificar `git check-ignore lambda/dist/x.zip`
- [x] 7.2 Actualizar la sección "Estructura del repositorio" del `README.md` para reflejar los nombres nuevos (`s3-documents`, `rds-pgvector`, `agent-lambda`), `bootstrap/`, `sample-data/`, `scripts/`, `Makefile`
- [x] 7.3 Verificar `git diff --stat` en `README.md` y `.gitignore` muestra solo los cambios esperados

## 8. Cierre

- [x] 8.1 `openspec validate establish-repo-structure --strict` pasa sin errores
- [x] 8.2 `openspec status --change establish-repo-structure --json` muestra todos los artefactos `done`/`skipped`
- [x] 8.3 Commit único en la rama actual: "Establecer estructura del monorepo y contexto OpenSpec" (mensaje con Co-Authored-By), y `git status` queda limpio
