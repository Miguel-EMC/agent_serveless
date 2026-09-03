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

package: ## Construye el .zip del Lambda en lambda/dist/agent.zip
	scripts/package-lambda.sh

invoke: ## Invoca el Lambda con el evento de ejemplo (o: make invoke Q="tu pregunta")
	scripts/invoke-lambda.sh $(Q)

destroy: ## terraform destroy del stack principal (conserva el bootstrap)
	terraform -chdir=terraform/environments/dev destroy

reproduce: ## destroy + apply del stack dev (luego re-ingesta + re-test a mano)
	terraform -chdir=terraform/environments/dev destroy -auto-approve
	terraform -chdir=terraform/environments/dev apply -auto-approve
	@echo ""
	@echo ">> Ahora, a mano:"
	@echo "   aws s3 cp sample-data/fictional-corp/ s3://\$$(terraform -chdir=terraform/environments/dev output -raw documents_bucket_name)/raw/ --recursive"
	@echo "   scripts/sync-knowledge-base.sh"
	@echo "   make invoke Q=\"...\"   (repetir las preguntas de la Fase 6)"
