import pytest
from botocore.exceptions import ClientError

from agent import generation
from agent.config import Settings
from agent.errors import ModelError

SETTINGS = Settings(knowledge_base_id="KB123", model_id="amazon.nova-lite-v1:0")
MESSAGES = [{"role": "user", "content": [{"text": "hola"}]}]


class _FakeClient:
    def __init__(self, *, response=None, error=None):
        self._response = response
        self._error = error

    def converse(self, **kwargs):
        if self._error:
            raise self._error
        return self._response


def test_generate_returns_text(monkeypatch):
    resp = {"output": {"message": {"content": [{"text": "  Son 22 días [1].  "}]}}}
    monkeypatch.setattr(generation, "_client", _FakeClient(response=resp))

    assert generation.generate(MESSAGES, SETTINGS) == "Son 22 días [1]."


def test_generate_wraps_client_error(monkeypatch):
    err = ClientError({"Error": {"Code": "ThrottlingException"}}, "Converse")
    monkeypatch.setattr(generation, "_client", _FakeClient(error=err))

    with pytest.raises(ModelError, match="ThrottlingException"):
        generation.generate(MESSAGES, SETTINGS)


def test_generate_wraps_empty_response(monkeypatch):
    monkeypatch.setattr(generation, "_client", _FakeClient(response={"output": {}}))

    with pytest.raises(ModelError, match="sin texto"):
        generation.generate(MESSAGES, SETTINGS)
