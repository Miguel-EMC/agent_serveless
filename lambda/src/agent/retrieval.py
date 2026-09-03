"""Búsqueda semántica contra la Bedrock Knowledge Base.

Se usa la operación `Retrieve` (no `RetrieveAndGenerate`): devuelve solo los
fragmentos relevantes, y el prompt + la llamada al modelo los hace este código,
para que cada paso del RAG sea explícito.
"""

from __future__ import annotations

from dataclasses import dataclass

import boto3

from agent.config import Settings

# Cliente perezoso y cacheado: se crea en la primera invocación y se reutiliza
# entre invocaciones cálidas del Lambda. Perezoso para no necesitar credenciales
# ni región al importar el módulo (importante para los tests).
_client = None


def _get_client(region: str):
    global _client
    if _client is None:
        _client = boto3.client("bedrock-agent-runtime", region_name=region)
    return _client


@dataclass(frozen=True)
class Chunk:
    text: str
    source_uri: str
    score: float


def retrieve(question: str, settings: Settings) -> list[Chunk]:
    """Recupera hasta `top_k` fragmentos y descarta los de score bajo."""
    response = _get_client(settings.region).retrieve(
        knowledgeBaseId=settings.knowledge_base_id,
        retrievalQuery={"text": question},
        retrievalConfiguration={
            "vectorSearchConfiguration": {"numberOfResults": settings.top_k}
        },
    )

    chunks: list[Chunk] = []
    for result in response.get("retrievalResults", []):
        score = float(result.get("score", 0.0))
        # Umbral: si la KB no tiene nada suficientemente parecido, mejor no
        # pasarlo como contexto (el modelo alucinaría sobre ruido).
        if score < settings.min_score:
            continue
        chunks.append(
            Chunk(
                text=result.get("content", {}).get("text", ""),
                source_uri=_source_uri(result),
                score=score,
            )
        )
    return chunks


def _source_uri(result: dict) -> str:
    """Ubicación en S3 del documento del que salió el fragmento."""
    location = result.get("location", {})
    s3 = location.get("s3Location", {})
    return s3.get("uri", location.get("type", "desconocido"))
