## 1. Corpus ficticio

- [x] 1.1 `sample-data/fictional-corp/vacation-policy.md`: política de vacaciones de "Fictional Corp" (~200 palabras, datos concretos: nº de días, antelación, acumulación). Todo inventado
- [x] 1.2 `sample-data/fictional-corp/expense-policy.md`: política de gastos (qué se reembolsa, plazo en días, límites)
- [x] 1.3 `sample-data/fictional-corp/remote-work-policy.md`: política de trabajo remoto (días/semana, requisitos, presencialidad)
- [x] 1.4 Eliminar `sample-data/fictional-corp/.gitkeep`; los 3 archivos son coherentes entre sí y sin datos de ninguna empresa real
- [x] 1.5 Revisión de confidencialidad: ningún nombre, cifra o política corresponde a una empresa real (autocontrol + si algo suena "de verdad", cambiarlo)

## 2. Runbook — Fase 6

- [x] 2.1 `docs/runbook.md` sección "Fase 6 — Prueba end-to-end": (a) `aws s3 cp sample-data/fictional-corp/ s3://<documents_bucket_name>/raw/ --recursive`; (b) `scripts/sync-knowledge-base.sh` y esperar `COMPLETE`; (c) las 4 preguntas de `design.md` DD2 con `make invoke Q="..."`; (d) verificar que cada respuesta cita el documento correcto y la de control responde "no encontré información"
- [x] 2.2 En esa sección: qué hacer si `Retrieve` da `ThrottlingException` (reintentar espaciado; Service Quotas; `aws bedrock-agent-runtime retrieve` directo como plan C) — de `design.md` DD4
- [x] 2.3 En esa sección: cómo leer los logs de la invocación (`aws logs tail /aws/lambda/rag-serverless-demo-agent`)

## 3. Runbook — Fase 7

- [x] 3.1 `docs/runbook.md` sección "Fase 7 — Prueba de reproducibilidad": `time make reproduce` (destroy + apply del stack `dev`, NO el bootstrap); luego re-subir `sample-data/` a `raw/`, `scripts/sync-knowledge-base.sh`, repetir las preguntas de la Fase 6
- [x] 3.2 En esa sección: qué mirar si algo no reconstruye limpio (recurso huérfano en `terraform state list` vs AWS, dependencia que falla el `apply`) y cómo reportarlo
- [x] 3.3 En esa sección: registrar el tiempo total (destroy + apply + ingesta + re-test) en `docs/cost-estimate.md`

## 4. Tooling y cost-estimate

- [x] 4.1 `Makefile`: target `reproduce` deja de ser stub — `terraform -chdir=terraform/environments/dev destroy -auto-approve` + `... apply -auto-approve` + `@echo` recordando re-ingesta y re-test; `make -n reproduce` muestra los comandos
- [x] 4.2 `docs/cost-estimate.md`: plantilla con (a) tabla pregunta → respuesta → documento citado (a rellenar), (b) desglose de costo esperado (embeddings de ingesta, Converse, S3 Vectors, resto free tier; total esperado < $0.10), (c) hueco para el tiempo del ciclo de reproducibilidad
- [x] 4.3 `docs/architecture.md`: marcar Fases 6 y 7 en la tabla de mapeo; enlazar `docs/cost-estimate.md`

## 5. Cierre del trabajo de este cambio

- [x] 5.1 `openspec validate prove-end-to-end --strict` pasa
- [x] 5.2 `git status`: entran `sample-data/fictional-corp/*.md`, `docs/cost-estimate.md`, `docs/runbook.md`, `docs/architecture.md`, `Makefile`; NADA de infra ni state
- [x] 5.3 Commit "Fase 6+7: corpus ficticio, guion de prueba e2e y de reproducibilidad" con `Co-Authored-By`

## 6. Ejecución por Miguel (fuera del alcance del código; se marca al completarse)

- [ ] 6.1 Subir el corpus a `raw/` y ejecutar la ingesta (`scripts/sync-knowledge-base.sh` → `COMPLETE`)
- [ ] 6.2 Invocar las 4 preguntas; verificar que cada respuesta cita el documento correcto y la de control dice "no encontré información". Pegar resultados en `docs/cost-estimate.md`
- [ ] 6.3 `time make reproduce` + re-ingesta + repetir la prueba; registrar el tiempo total y si algo no reconstruyó limpio
- [ ] 6.4 Rellenar `docs/cost-estimate.md` con las preguntas/respuestas reales y el costo aproximado (calculadora de precios de AWS / consumo observado); commit
- [ ] 6.5 Archivar con `/openspec-archive-change prove-end-to-end` (sync: MODIFIED en `semantic-retrieval`, `answer-generation`, `infra-reproducibility`)
