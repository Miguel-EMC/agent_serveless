from agent.prompt import SYSTEM, build_messages
from agent.retrieval import Chunk

CHUNKS = [
    Chunk(text="22 días de vacaciones al año.", source_uri="s3://b/raw/vac.md", score=0.8),
    Chunk(text="Acumulables hasta 5 días.", source_uri="s3://b/raw/vac.md", score=0.6),
]


def test_build_messages_shape():
    messages = build_messages("¿Cuántos días de vacaciones?", CHUNKS)

    assert isinstance(messages, list) and len(messages) == 1
    msg = messages[0]
    assert msg["role"] == "user"
    assert isinstance(msg["content"], list)
    text = msg["content"][0]["text"]

    # Fragmentos numerados y presentes.
    assert "[1] 22 días de vacaciones al año." in text
    assert "[2] Acumulables hasta 5 días." in text
    # La pregunta está incluida.
    assert "¿Cuántos días de vacaciones?" in text


def test_system_prompt_forbids_inventing():
    assert "no encontraste" in SYSTEM.lower() or "no inventes" in SYSTEM.lower()
