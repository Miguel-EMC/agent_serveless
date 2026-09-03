import pytest

from agent import handler
from agent.errors import ModelError
from agent.retrieval import Chunk

CHUNKS = [
    Chunk(text="22 días de vacaciones.", source_uri="s3://b/raw/vac.md", score=0.812),
]


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setenv("KNOWLEDGE_BASE_ID", "KB123")


def test_handler_answers_with_sources(monkeypatch):
    monkeypatch.setattr(handler.retrieval, "retrieve", lambda q, s: CHUNKS)
    monkeypatch.setattr(handler.generation, "generate", lambda m, s: "Son 22 días [1].")

    out = handler.lambda_handler({"question": "¿Cuántos días de vacaciones?"})

    assert out["answer"] == "Son 22 días [1]."
    assert out["used_chunks"] == 1
    assert out["sources"] == [{"document": "s3://b/raw/vac.md", "score": 0.812}]


def test_handler_no_context_skips_model(monkeypatch):
    calls = []
    monkeypatch.setattr(handler.retrieval, "retrieve", lambda q, s: [])
    monkeypatch.setattr(
        handler.generation, "generate", lambda m, s: calls.append(1) or "x"
    )

    out = handler.lambda_handler({"question": "algo no cubierto"})

    assert out["used_chunks"] == 0
    assert out["sources"] == []
    assert "no encontré" in out["answer"].lower()
    assert calls == []  # no se llamó al modelo


def test_handler_missing_question():
    out = handler.lambda_handler({})
    assert out["statusCode"] == 400
    assert "question" in out["error"]


def test_handler_bedrock_error_is_contained(monkeypatch):
    monkeypatch.setattr(handler.retrieval, "retrieve", lambda q, s: CHUNKS)

    def _boom(messages, settings):
        raise ModelError("Bedrock Converse falló (ThrottlingException).")

    monkeypatch.setattr(handler.generation, "generate", _boom)

    out = handler.lambda_handler({"question": "x"})

    assert out["statusCode"] == 502
    assert "Bedrock" in out["error"]
