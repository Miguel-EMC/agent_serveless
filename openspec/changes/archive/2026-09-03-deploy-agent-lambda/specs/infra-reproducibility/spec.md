## ADDED Requirements

### Requirement: El agente se despliega como Lambda con rol de mínimo privilegio

El agente SHALL desplegarse como una función AWS Lambda empaquetada en un
archivo `.zip` estándar (sin contenedores ni ECR), con un runtime de Python
fijo. El rol de ejecución de la función SHALL ser de mínimo privilegio, sin
`Action: "*"` ni `Resource: "*"`, y su acceso SHALL limitarse a: escribir en su
propio grupo de logs de CloudWatch, `bedrock:InvokeModel` sobre el modelo de
generación configurado, y `bedrock:Retrieve` sobre la Knowledge Base del
proyecto. La configuración de la función (id de la KB, modelo, top-k, umbral)
SHALL pasarse por variables de entorno, sin hardcodear.

#### Scenario: La función está empaquetada como zip estándar

- **WHEN** se inspecciona la función Lambda tras el `apply`
- **THEN** su tipo de paquete es `Zip`
- **AND** su runtime es una versión de Python
- **AND** su handler apunta al entrypoint del agente

#### Scenario: El rol de ejecución es de mínimo privilegio

- **WHEN** se revisa la política del rol de ejecución de la función
- **THEN** no contiene `Action: "*"` ni `Resource: "*"` sin acotar
- **AND** solo concede escritura de logs sobre el grupo de logs de la función,
  `bedrock:InvokeModel` sobre el modelo configurado y `bedrock:Retrieve` sobre
  la Knowledge Base

#### Scenario: La configuración va por variables de entorno

- **WHEN** se inspeccionan las variables de entorno de la función
- **THEN** incluyen el id de la Knowledge Base y el id del modelo
- **AND** ningún archivo del repositorio hardcodea esos valores en el código del
  agente
