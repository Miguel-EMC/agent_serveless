# Punto de entrada único del workflow del agente RAG serverless.
# Cada target es un wrapper delgado sobre terraform o sobre scripts/.
# Los targets todavía no implementados avisan la fase en la que se llenan.

.DEFAULT_GOAL := help
.PHONY: help bootstrap deploy package invoke destroy reproduce

help: ## Lista los targets disponibles
	@echo "Targets:"
	@echo "  bootstrap   Crea el remote state (bucket S3 + tabla DynamoDB)   [Fase 1]"
	@echo "  deploy      terraform apply del stack principal (environments/dev) [Fase 5]"
	@echo "  package     Construye el .zip estándar del Lambda desde lambda/src [Fase 5]"
	@echo "  invoke      Invoca el Lambda con lambda/tests/events/sample-question.json [Fase 6]"
	@echo "  destroy     terraform destroy del stack principal (no el bootstrap) [Fase 7]"
	@echo "  reproduce   destroy + apply + prueba e2e, cronometrado            [Fase 7]"

bootstrap: ## Crea el remote state (bucket S3 + tabla DynamoDB)
	terraform -chdir=terraform/bootstrap init
	terraform -chdir=terraform/bootstrap apply

deploy: ## terraform apply del stack principal (environments/dev)
	terraform -chdir=terraform/environments/dev init
	terraform -chdir=terraform/environments/dev apply

package: ## Construye el .zip del Lambda
	@echo "TODO: Fase 5 - scripts/package-lambda.sh"

invoke: ## Invoca el Lambda con un evento de ejemplo
	@echo "TODO: Fase 6 - scripts/invoke-lambda.sh"

destroy: ## terraform destroy del stack principal (conserva el bootstrap)
	terraform -chdir=terraform/environments/dev destroy

reproduce: ## destroy + apply + prueba e2e, cronometrado
	@echo "TODO: Fase 7 - destroy + apply desde cero + repetir prueba e2e"
