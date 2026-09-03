## Context

Ver `proposal.md` y los specs. El stack `dev` está desplegado (bucket de docs,
KB `J1BNIN7TUB` + data source `IXFQH5VA6D`, vector bucket, Lambda
`rag-serverless-demo-agent`). La KB está **vacía** (sin ingesta). El `Retrieve`
dio `ThrottlingException` en la Fase 5.

## Goals / Non-Goals

**Goals:**

- Un corpus ficticio pequeño y coherente para preguntar sobre él.
- Un guion reproducible: subir → ingestar → preguntar → verificar cita.
- Un guion de reproducibilidad: destroy → apply → re-ingesta → re-test,
  cronometrado.
- Registro de qué se probó, qué respondió y cuánto costó.

**Non-Goals:**

- No se automatiza la prueba (no hay framework de e2e); es un guion que corre
  Miguel.
- No se toca infraestructura ni código.
- No se resuelve el throttle de `Retrieve` aquí (es cuota de AWS); solo se
  documenta la mitigación.

## Decisions

### DD1 - Corpus: 3 políticas de "Fictional Corp"

- `vacation-policy.md`: días de vacaciones, cómo se solicitan, acumulación.
- `expense-policy.md`: qué gastos se reembolsan, plazos, límites.
- `remote-work-policy.md`: días de remoto permitidos, requisitos de equipo,
  reuniones presenciales.

Cada documento ~150–300 palabras, con datos concretos y distintos entre sí para
que las preguntas discriminen la fuente. Todo inventado; "Fictional Corp" es una
empresa que no existe.

- **Por qué 3 y no 2**: con 3 se puede probar que el `Retrieve` elige el
  documento correcto entre varios, no solo que "encuentra algo".

### DD2 - Preguntas de prueba (en el runbook)

Una por documento + una de control:

| Pregunta | Documento esperado |
|----------|--------------------|
| ¿Cuántos días de vacaciones tengo al año? | vacation-policy.md |
| ¿En cuántos días se reembolsan los gastos de viaje? | expense-policy.md |
| ¿Cuántos días a la semana puedo trabajar desde casa? | remote-work-policy.md |
| ¿Cuál es la política de coche de empresa? | (ninguno → "no encontré información") |

La de control valida el camino "sin contexto" con datos reales.

### DD3 - Ingesta: `scripts/sync-knowledge-base.sh`

Ya existe (Fase 3b). Sube nada por sí solo: los documentos se suben con
`aws s3 cp sample-data/fictional-corp/ s3://<bucket>/raw/ --recursive` y luego
el script dispara `start-ingestion-job` y espera a `COMPLETE`.

### DD4 - Throttle de `Retrieve`: mitigación documentada

Si `make invoke` sigue dando `ThrottlingException` tras la ingesta:

1. Reintentar espaciado (el throttle inicial de una KB nueva suele relajarse en
   minutos/horas).
2. Si persiste: Service Quotas → Amazon Bedrock → cuota de `Retrieve` /
   consultas a knowledge base, pedir aumento.
3. Como plan C para la charla: invocar `Retrieve` directo con la CLI
   (`aws bedrock-agent-runtime retrieve`) para mostrar el paso aunque la Lambda
   reintente.

Se documenta en el runbook; no bloquea el resto del guion (ingesta, verificación
de infra).

### DD5 - `make reproduce`

```
reproduce:
	terraform -chdir=terraform/environments/dev destroy -auto-approve
	terraform -chdir=terraform/environments/dev apply -auto-approve
	@echo "Ahora: re-subir sample-data/ a raw/, correr scripts/sync-knowledge-base.sh, y repetir make invoke"
```

No re-ingesta solo (necesita los documentos y esperar el job); deja el
recordatorio. El cronometraje lo hace Miguel con `time make reproduce` + el
tiempo de ingesta.

### DD6 - `docs/cost-estimate.md`

Plantilla con: tabla de preguntas/respuestas, y un desglose de costo —
embeddings de ingesta (Titan v2, ~$0.02 / 1M tokens de entrada; 3 docs cortos =
fracción de centavo), Converse (Nova Lite, ~$0.06 / 1M input + ~$0.24 / 1M
output; unas pocas preguntas = céntimos), S3 Vectors (almacenamiento + queries,
céntimos), resto en free tier. Total esperado: **< $0.10** para una sesión de
pruebas.

## Risks / Trade-offs

- **[El throttle no se relaja]** → La Fase 6 queda parcialmente verificada
  (ingesta OK, `Retrieve` directo OK, Lambda con reintento). Se documenta como
  limitación de la demo, no como fallo del diseño.
- **[La ingesta falla]** → `scripts/sync-knowledge-base.sh` sale con estado
  `FAILED` y las estadísticas; se revisa el motivo (formato de documento,
  permisos del rol de la KB) antes de reintentar.
- **[`terraform destroy` deja algo huérfano]** → Es exactamente lo que la Fase 7
  busca encontrar. Los vectores del data source tienen `data_deletion_policy =
  DELETE` y el vector bucket `force_destroy = true`, así que debería salir
  limpio; si no, se reporta con detalle.

## Migration Plan

1. Escribir los 3 documentos ficticios y `docs/cost-estimate.md` (plantilla).
2. Escribir las secciones "Fase 6" y "Fase 7" del runbook.
3. Implementar `make reproduce`.
4. Commit. **Aquí para el trabajo de este cambio.**
5. Miguel corre el guion (subir, ingestar, preguntar, verificar; luego
   destroy/apply/re-test cronometrado) y rellena `docs/cost-estimate.md` con los
   resultados reales.
6. Con los resultados, se archiva el cambio (sync de los 3 specs MODIFIED).

## Open Questions

- ¿La prueba de reproducibilidad incluye también destruir y recrear el
  `bootstrap`? El prompt dice explícitamente que NO (el bootstrap se queda).
  Confirmado: Fase 7 solo toca el stack `dev`.
