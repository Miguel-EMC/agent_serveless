"""Configuración del agente, leída de variables de entorno una sola vez."""

from __future__ import annotations

import os
from dataclasses import dataclass

# Modelo de generación por defecto. Es de Amazon (suele venir con model access
# habilitado) y se puede cambiar por env var sin tocar código porque usamos la
# API Converse, que normaliza el payload entre familias de modelos.
DEFAULT_MODEL_ID = "amazon.nova-lite-v1:0"


@dataclass(frozen=True)
class Settings:
    knowledge_base_id: str
    model_id: str = DEFAULT_MODEL_ID
    top_k: int = 5
    min_score: float = 0.4
    region: str = "us-east-1"


def load_settings() -> Settings:
    """Construye Settings desde el entorno. Falla claro si falta la KB."""
    kb_id = os.environ.get("KNOWLEDGE_BASE_ID", "").strip()
    if not kb_id:
        raise ValueError(
            "Falta la variable de entorno KNOWLEDGE_BASE_ID "
            "(la setea el módulo Terraform del Lambda en la Fase 5)."
        )

    # AWS_REGION lo inyecta el runtime de Lambda; AWS_DEFAULT_REGION es el
    # fallback para correr local.
    region = (
        os.environ.get("AWS_REGION")
        or os.environ.get("AWS_DEFAULT_REGION")
        or "us-east-1"
    )

    return Settings(
        knowledge_base_id=kb_id,
        model_id=os.environ.get("MODEL_ID", DEFAULT_MODEL_ID),
        top_k=int(os.environ.get("TOP_K", "5")),
        min_score=float(os.environ.get("MIN_SCORE", "0.4")),
        region=region,
    )
