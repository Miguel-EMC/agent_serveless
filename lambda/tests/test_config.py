import pytest

from agent.config import DEFAULT_MODEL_ID, load_settings


def test_load_settings_full_env(monkeypatch):
    monkeypatch.setenv("KNOWLEDGE_BASE_ID", "KB123")
    monkeypatch.setenv("MODEL_ID", "anthropic.claude-3-5-haiku-20241022-v1:0")
    monkeypatch.setenv("TOP_K", "3")
    monkeypatch.setenv("MIN_SCORE", "0.5")
    monkeypatch.setenv("AWS_REGION", "us-east-1")

    s = load_settings()

    assert s.knowledge_base_id == "KB123"
    assert s.model_id == "anthropic.claude-3-5-haiku-20241022-v1:0"
    assert s.top_k == 3
    assert s.min_score == 0.5
    assert s.region == "us-east-1"


def test_load_settings_defaults(monkeypatch):
    monkeypatch.setenv("KNOWLEDGE_BASE_ID", "KB123")
    for var in ("MODEL_ID", "TOP_K", "MIN_SCORE"):
        monkeypatch.delenv(var, raising=False)

    s = load_settings()

    assert s.model_id == DEFAULT_MODEL_ID
    assert s.top_k == 5
    assert s.min_score == 0.4


def test_load_settings_missing_kb(monkeypatch):
    monkeypatch.delenv("KNOWLEDGE_BASE_ID", raising=False)
    with pytest.raises(ValueError, match="KNOWLEDGE_BASE_ID"):
        load_settings()
