# Prueba end-to-end — resultados y costo

Se rellena tras correr las Fases 6 y 7 (ver `runbook.md`).

## Preguntas probadas (Fase 6)

| Pregunta | `sources` citadas | Respuesta del sistema | ¿Correcta? |
|----------|-------------------|-----------------------|-----------|
| ¿Cuántos días de vacaciones tengo al año? | _(rellenar)_ | _(rellenar)_ | |
| ¿En cuántos días se reembolsan los gastos de viaje? | | | |
| ¿Cuántos días a la semana puedo trabajar desde casa? | | | |
| ¿Cuál es la política de coche de empresa? (control) | _(ninguna)_ | _("No encontré información...")_ | |

## Costo aproximado de la prueba

Todo lo que no es Bedrock/S3 Vectors está en free tier (S3, Lambda, DynamoDB,
CloudWatch Logs a este volumen).

| Concepto | Detalle | Costo estimado |
|----------|---------|----------------|
| Embeddings de ingesta (Titan Text Embeddings v2) | 3 documentos cortos (~1.500 palabras ≈ 2k tokens) × 1 ingesta | < $0.01 |
| Generación (Converse, Nova Lite) | ~4 preguntas × (~800 tokens in + ~200 out) | < $0.01 |
| S3 Vectors | almacenamiento de ~pocas decenas de vectores + queries | ~céntimos |
| **Total sesión de pruebas** | | **< $0.10** |

Cifras de referencia (verificar en la calculadora de AWS al momento de la
prueba):
- Titan Text Embeddings v2: ~$0.02 / 1M tokens de entrada.
- Nova Lite: ~$0.06 / 1M tokens de entrada, ~$0.24 / 1M tokens de salida.
- S3 Vectors: pago por uso (PUT, almacenamiento GB-mes, queries).

## Reproducibilidad (Fase 7)

| Métrica | Valor |
|---------|-------|
| `time make reproduce` (destroy + apply) | _(rellenar)_ |
| Tiempo de re-ingesta hasta `COMPLETE` | _(rellenar)_ |
| Tiempo total del ciclo (destroy → re-test OK) | _(rellenar)_ |
| ¿Hubo que corregir algo a mano? | _(sí/no + detalle)_ |
| Recursos huérfanos tras el destroy | _(ninguno / detalle)_ |

## Notas

- El nombre del bucket de documentos cambia en cada `apply` (`random_id`); es
  esperado y los scripts lo resuelven leyendo el output.
- Estado del throttle de `Retrieve` durante la prueba: _(rellenar)_.
