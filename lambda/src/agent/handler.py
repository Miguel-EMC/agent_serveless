"""Entrypoint del Lambda: orquesta retrieval -> prompt -> generación.

Evento de prueba (sin API Gateway):  {"question": "..."}
"""

from __future__ import annotations

from botocore.exceptions import ClientError

from agent import generation, retrieval
from agent.config import load_settings
from agent.errors import ModelError
from agent.prompt import build_messages

_NO_CONTEXT_ANSWER = "No encontré información sobre eso en los documentos."


def lambda_handler(event, context=None):  # noqa: ARG001 - context no se usa
    # 1. Validar la entrada.
    question = (event or {}).get("question")
    if not isinstance(question, str) or not question.strip():
        return {"error": "El evento debe incluir 'question' (texto no vacío).",
                "statusCode": 400}

    question = question.strip()
    settings = load_settings()

    try:
        # 2. Búsqueda semántica en la Knowledge Base.
        chunks = retrieval.retrieve(question, settings)

        # 3. Sin contexto relevante -> no se llama al modelo (evita alucinar).
        if not chunks:
            return {"answer": _NO_CONTEXT_ANSWER, "sources": [], "used_chunks": 0}

        # 4. Armar el prompt y generar la respuesta.
        answer = generation.generate(build_messages(question, chunks), settings)

    except (ClientError, ModelError) as exc:
        return {"error": str(exc), "statusCode": 502}

    # 5. Devolver la respuesta citando las fuentes.
    return {
        "answer": answer,
        "sources": [
            {"document": chunk.source_uri, "score": round(chunk.score, 3)}
            for chunk in chunks
        ],
        "used_chunks": len(chunks),
    }
