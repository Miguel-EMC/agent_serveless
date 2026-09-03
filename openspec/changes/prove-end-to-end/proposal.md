## Why

Toda la infraestructura y el código están en pie (Fases 1–5). Falta probar que
el sistema **responde de verdad**, citando la fuente correcta, y que la
infraestructura es **reproducible** (destruir y volver a levantar desde cero).
Son las Fases 6 y 7, juntas en un solo cambio porque no añaden comportamiento
nuevo: son ejercicios de validación cuyos criterios de aceptación afinan specs
ya existentes.

## What Changes

- **`sample-data/fictional-corp/`**: 3 documentos Markdown ficticios de
  "Fictional Corp" (una empresa inventada) — política de vacaciones, política de
  gastos, política de trabajo remoto. Contenido inventado, sin relación con
  ninguna empresa real.
- **`docs/runbook.md`**: sección "Fase 6 — Prueba end-to-end" con el
  procedimiento exacto: subir los documentos a `s3://.../raw/`, correr
  `scripts/sync-knowledge-base.sh` (ingesta), invocar el Lambda con 3–4
  preguntas relacionadas, y verificar que cada respuesta cita el documento
  correcto. Incluye qué hacer si `Retrieve` devuelve `ThrottlingException`
  (esperar / pedir aumento de cuota).
- **`docs/runbook.md`**: sección "Fase 7 — Prueba de reproducibilidad":
  `make destroy` del stack `dev` (NO el bootstrap), `make deploy` desde cero,
  re-ingesta, repetir la prueba de la Fase 6, y cronometrar todo. Qué mirar si
  algo no reconstruye limpio (recurso huérfano, dependencia rota).
- **`docs/cost-estimate.md`**: plantilla + resultado — qué preguntas se
  probaron, qué respondió el sistema, y el costo aproximado de la prueba
  (tokens de Bedrock: embeddings de la ingesta + Converse de las respuestas;
  S3 Vectors; todo lo demás en free tier).
- **`docs/architecture.md`**: marcar Fases 6 y 7 hechas; enlazar el
  cost-estimate.
- **`Makefile`**: el target `reproduce` deja de ser stub — encadena
  `destroy` + `deploy` + un recordatorio de re-ingestar y re-probar.

No hay código de infraestructura ni de aplicación nuevo. La ejecución real
(subir documentos, ingesta, invocaciones, destroy/apply) la corre Miguel; este
cambio deja el guion y los criterios.

## Capabilities

### Modified Capabilities

- `semantic-retrieval`: se **modifica** el requisito "Base de conocimiento
  consultable" para fijar como criterio de aceptación que, con documentos
  ingestados, una consulta `Retrieve` devuelve fragmentos del documento
  correcto (antes el escenario "Retrieve devuelve fragmentos con su fuente"
  quedaba pendiente de la Fase 6; ahora se marca como verificable y verificado).
- `answer-generation`: se **modifica** el requisito "La respuesta cita sus
  fuentes" para exigir que, en la prueba e2e, la fuente citada sea el documento
  que efectivamente contiene la respuesta (no basta con citar *una* fuente).
- `infra-reproducibility`: se **modifica** el requisito "El stack de aplicación
  se aplica desde cero de forma reproducible" para añadir un escenario de
  prueba cronometrada: destroy + apply + re-ingesta + re-test completan sin
  recursos huérfanos y en un tiempo registrado.

### New Capabilities

Ninguna.

## Impact

- **Nuevos archivos**: `sample-data/fictional-corp/{vacation,expense,
  remote-work}-policy.md`, `docs/cost-estimate.md`.
- **Modificados**: `docs/runbook.md`, `docs/architecture.md`, `Makefile`, tres
  specs.
- **AWS**: sin cambios de infraestructura. La prueba genera costo de Bedrock
  por tokens (céntimos para 3 documentos cortos + unas pocas preguntas) y un
  poco de S3 Vectors. La Fase 7 destruye y recrea el stack `dev` (el bootstrap
  no se toca).
- **Confidencialidad**: "Fictional Corp" y todo su contenido son inventados.
  Ningún dato, nombre o política de ninguna empresa real.
- **Riesgo conocido**: el `Retrieve` de la KB venía dando `ThrottlingException`
  en la Fase 5. Si persiste, la Fase 6 no puede pasar hasta que se relaje el
  rate-limit o se pida aumento de cuota de Bedrock; se documenta.
