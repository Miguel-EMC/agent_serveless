"""Armado del prompt final a partir de los fragmentos recuperados.

El contexto se numera [1], [2]... para que el modelo pueda citar qué fragmento
usó en cada afirmación.
"""

from __future__ import annotations

from agent.retrieval import Chunk

SYSTEM = (
    "Eres un asistente que responde preguntas usando EXCLUSIVAMENTE el contexto "
    "que se te da. Reglas:\n"
    "- Si el contexto no contiene la respuesta, di claramente que no encontraste "
    "esa información en los documentos. No inventes.\n"
    "- Cita entre corchetes el número de los fragmentos que uses, por ejemplo "
    "[1] o [2][3].\n"
    "- Responde de forma breve y directa, en el mismo idioma de la pregunta."
)


def build_messages(question: str, chunks: list[Chunk]) -> list[dict]:
    """Devuelve la lista `messages` en formato Converse (un turno de usuario)."""
    context_blocks = "\n\n".join(
        f"[{i}] {chunk.text}" for i, chunk in enumerate(chunks, start=1)
    )
    user_text = (
        "Contexto:\n"
        f"{context_blocks}\n\n"
        f"Pregunta: {question}"
    )
    return [{"role": "user", "content": [{"text": user_text}]}]
