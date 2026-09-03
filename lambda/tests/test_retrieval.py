import json
from pathlib import Path

from agent import retrieval
from agent.config import Settings

FIXTURE = json.loads(
    (Path(__file__).parent / "fixtures" / "retrieve_response.json").read_text()
)


class _FakeClient:
    def __init__(self, response):
        self._response = response
        self.calls = []

    def retrieve(self, **kwargs):
        self.calls.append(kwargs)
        return self._response


def test_retrieve_normalizes_and_filters(monkeypatch):
    fake = _FakeClient(FIXTURE)
    monkeypatch.setattr(retrieval, "_client", fake)
    settings = Settings(knowledge_base_id="KB123", top_k=5, min_score=0.4)

    chunks = retrieval.retrieve("¿cuántos días de vacaciones?", settings)

    # El tercer resultado (score 0.19) se descarta por el umbral.
    assert len(chunks) == 2
    assert chunks[0].score == 0.81
    assert chunks[0].source_uri.endswith("raw/vacation-policy.md")
    assert "22 días" in chunks[0].text

    # Se pasó el knowledgeBaseId y el top_k.
    assert fake.calls[0]["knowledgeBaseId"] == "KB123"
    assert (
        fake.calls[0]["retrievalConfiguration"]["vectorSearchConfiguration"][
            "numberOfResults"
        ]
        == 5
    )


def test_retrieve_empty_when_all_below_threshold(monkeypatch):
    monkeypatch.setattr(retrieval, "_client", _FakeClient(FIXTURE))
    settings = Settings(knowledge_base_id="KB123", min_score=0.95)

    assert retrieval.retrieve("x", settings) == []
