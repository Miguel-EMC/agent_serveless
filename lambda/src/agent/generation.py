"""Llamada al modelo de Bedrock con la API Converse.

Converse normaliza el formato de mensajes entre familias de modelos (Nova,
Claude, Llama...), así que cambiar MODEL_ID no obliga a reescribir el payload.
"""

from __future__ import annotations

import boto3
from botocore.exceptions import ClientError

from agent.config import Settings
from agent.errors import ModelError
from agent.prompt import SYSTEM

# Cliente perezoso y cacheado (ver nota en retrieval.py).
_client = None


def _get_client(region: str):
    global _client
    if _client is None:
        _client = boto3.client("bedrock-runtime", region_name=region)
    return _client


def generate(messages: list[dict], settings: Settings) -> str:
    """Genera la respuesta final. Lanza ModelError si Bedrock falla."""
    try:
        response = _get_client(settings.region).converse(
            modelId=settings.model_id,
            system=[{"text": SYSTEM}],
            messages=messages,
            # Respuestas cortas y casi deterministas para una demo.
            inferenceConfig={"maxTokens": 512, "temperature": 0.2},
        )
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code", "ClientError")
        raise ModelError(f"Bedrock Converse falló ({code}).") from exc

    try:
        return response["output"]["message"]["content"][0]["text"].strip()
    except (KeyError, IndexError) as exc:
        raise ModelError("Respuesta de Bedrock sin texto.") from exc
