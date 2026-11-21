"""Serveur Photo -> cotes JSON.

Le téléphone envoie la photo ici ; le serveur garde la clé API secrète,
appelle l'IA, et renvoie le JSON de la pièce (le "contrat").

Lancer :  .venv\\Scripts\\uvicorn main:app --host 0.0.0.0 --port 8000
Tester :  http://localhost:8000/docs
"""

import json
import logging

from dotenv import load_dotenv
from fastapi import FastAPI, File, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

load_dotenv()  # lit serveur/.env (GEMINI_API_KEY, GEMINI_MODEL)

journal = logging.getLogger("uvicorn.error")  # s'affiche dans le terminal d'uvicorn

import ia  # noqa: E402  (après load_dotenv)
from schema import vers_contrat  # noqa: E402

TYPES_ACCEPTES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}
TAILLE_MAX = 10 * 1024 * 1024  # 10 Mo

app = FastAPI(title="Photo -> G-code : lecture de dessin")


def _erreur(code: int, message: str) -> JSONResponse:
    journal.warning("Réponse %s : %s", code, message)
    return JSONResponse(status_code=code, content={"erreur": message})


@app.exception_handler(RequestValidationError)
def requete_invalide(_: Request, exc: RequestValidationError):
    # Ex. : champ "photo" absent. Même format {"erreur": ...} que le reste.
    return _erreur(400, f"Requête invalide (photo manquante ?) : {exc.errors()}")


@app.get("/sante")
def sante():
    return {"ok": True}


# "def" (pas "async def") : FastAPI l'exécute dans un thread, l'appel IA
# ne bloque pas les autres requêtes.
@app.post("/analyser")
def analyser(photo: UploadFile = File(...)):
    if photo.content_type not in TYPES_ACCEPTES:
        return _erreur(415, f"Format non accepté ({photo.content_type}). Envoie une photo JPEG ou PNG.")

    image = photo.file.read(TAILLE_MAX + 1)
    if len(image) > TAILLE_MAX:
        return _erreur(413, "Photo trop lourde (10 Mo maximum).")
    if not image:
        return _erreur(400, "Photo vide.")

    journal.info("Photo reçue : %s, %s, %d Ko", photo.filename, photo.content_type, len(image) // 1024)
    try:
        analyse = ia.analyser_avec_gemini(image, photo.content_type)
    except ia.ErreurIA as e:
        return _erreur(429 if e.quota else 502, str(e))

    if not analyse.est_piece_tournee:
        return _erreur(422, f"Ce dessin n'est pas une pièce tournée : {analyse.raison}")

    contrat = vers_contrat(analyse)
    journal.info("JSON renvoyé :\n%s", json.dumps(contrat, ensure_ascii=False, indent=2))
    return contrat
