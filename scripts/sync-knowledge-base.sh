#!/usr/bin/env bash
# Dispara un ingestion job de la Bedrock Knowledge Base y espera a que termine.
# Se usa en la Fase 6, cuando ya hay documentos en el prefijo raw/ del bucket.
#
# Uso:  AWS_PROFILE=personal scripts/sync-knowledge-base.sh
set -euo pipefail

DEV_DIR="$(cd "$(dirname "$0")/.." && pwd)/terraform/environments/dev"

KB_ID="$(terraform -chdir="$DEV_DIR" output -raw knowledge_base_id)"
DS_ID="$(terraform -chdir="$DEV_DIR" output -raw data_source_id)"

echo "Knowledge Base: $KB_ID   Data source: $DS_ID"

JOB_ID="$(aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "$KB_ID" \
  --data-source-id "$DS_ID" \
  --query 'ingestionJob.ingestionJobId' --output text)"

echo "Ingestion job: $JOB_ID"

while true; do
  STATUS="$(aws bedrock-agent get-ingestion-job \
    --knowledge-base-id "$KB_ID" --data-source-id "$DS_ID" \
    --ingestion-job-id "$JOB_ID" \
    --query 'ingestionJob.status' --output text)"
  echo "  status: $STATUS"
  case "$STATUS" in
    COMPLETE) break ;;
    FAILED)   echo "Ingestion FAILED"; exit 1 ;;
    *)        sleep 10 ;;
  esac
done

aws bedrock-agent get-ingestion-job \
  --knowledge-base-id "$KB_ID" --data-source-id "$DS_ID" \
  --ingestion-job-id "$JOB_ID" \
  --query 'ingestionJob.statistics'
