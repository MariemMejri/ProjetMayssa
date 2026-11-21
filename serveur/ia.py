"""Appel de l'IA. Seul fichier qui dépend du fournisseur (Gemini aujourd'hui ;
on pourra ajouter Groq ici sans toucher au reste)."""

import os

from google import genai
from google.genai import types

from prompt import PROMPT_SYSTEME, PROMPT_UTILISATEUR
from schema import AnalyseDessin

_client: genai.Client | None = None


class ErreurIA(Exception):
    """Erreur côté IA (clé, quota, réponse illisible)."""

    def __init__(self, message: str, quota: bool = False):
        super().__init__(message)
        self.quota = quota


def _client_gemini() -> genai.Client:
    global _client
    if _client is None:
        cle = os.environ.get("GEMINI_API_KEY")
        if not cle:
            raise ErreurIA("GEMINI_API_KEY manquante dans serveur/.env")
        # v1beta : nécessaire pour system_instruction et response_schema
        # (la version v1 les refuse : "Developer instruction is not enabled").
        _client = genai.Client(
            api_key=cle,
            http_options=types.HttpOptions(api_version="v1beta"),
        )
    return _client


def analyser_avec_gemini(image: bytes, type_mime: str) -> AnalyseDessin:
    modele = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    try:
        reponse = _client_gemini().models.generate_content(
            model=modele,
            contents=[
                types.Part.from_bytes(data=image, mime_type=type_mime),
                PROMPT_UTILISATEUR,
            ],
            config=types.GenerateContentConfig(
                system_instruction=PROMPT_SYSTEME,
                response_mime_type="application/json",
                response_schema=AnalyseDessin,
                temperature=0,
            ),
        )
    except ErreurIA:
        raise
    except Exception as e:  # erreurs réseau / API
        texte = str(e)
        quota = "429" in texte or "RESOURCE_EXHAUSTED" in texte
        raise ErreurIA(
            "Quota gratuit Gemini atteint, réessaie dans une minute." if quota
            else f"Erreur Gemini : {texte[:300]}",
            quota=quota,
        ) from e

    if isinstance(reponse.parsed, AnalyseDessin):
        return reponse.parsed
    try:
        return AnalyseDessin.model_validate_json(reponse.text or "")
    except Exception as e:
        raise ErreurIA("Réponse de l'IA illisible, réessaie avec une photo plus nette.") from e
