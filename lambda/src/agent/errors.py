"""Excepciones del agente. Manejo de errores: qué pasa si Bedrock no responde,
si no hay resultados relevantes, etc."""

from __future__ import annotations


class AgentError(Exception):
    """Error controlado del agente (se traduce a una respuesta legible)."""


class NoRelevantContext(AgentError):
    """La recuperación no devolvió fragmentos por encima del umbral."""


class ModelError(AgentError):
    """La llamada al modelo de generación (Converse) falló."""
