"""Tests du serveur SANS appeler Gemini (l'IA est remplacée par une fausse réponse).
Lancer : .venv\\Scripts\\pytest"""

import pytest
from fastapi.testclient import TestClient

import ia
import main
from schema import AnalyseDessin

client = TestClient(main.app)
PHOTO = {"photo": ("dessin.jpg", b"fausse image", "image/jpeg")}


def fausse_ia(reponse):
    def _analyser(image, type_mime):
        if isinstance(reponse, Exception):
            raise reponse
        return AnalyseDessin.model_validate(reponse)
    return _analyser


@pytest.fixture
def ia_repond(monkeypatch):
    def _installer(reponse):
        monkeypatch.setattr(ia, "analyser_avec_gemini", fausse_ia(reponse))
    return _installer


def test_piece_tournee_renvoie_le_contrat(ia_repond):
    ia_repond({
        "est_piece_tournee": True,
        "raison": "",
        "brut": {"diametre": 60, "longueur": 100},
        "points": [
            {"nom": "P1", "x": 0, "z": 0, "segment": "droite"},
            {"nom": "P2", "x": 44, "z": 0, "segment": "droite"},
            {"nom": "P3", "x": 56, "z": 6, "segment": "arc", "rayon": 6, "type": "concave"},
        ],
        "filetages": [{"diametre": 44, "pas": 2, "z_debut": 2, "z_fin": 40}],
        "incertitudes": ["Diamètre du brut non coté, 60 supposé"],
    })
    r = client.post("/analyser", files=PHOTO)
    assert r.status_code == 200
    assert r.json() == {
        "brut": {"diametre": 60, "longueur": 100},
        "points": [
            {"nom": "P1", "x": 0, "z": 0},
            {"nom": "P2", "x": 44, "z": 0},
            {"nom": "P3", "x": 56, "z": 6, "segment": "arc", "rayon": 6, "type": "concave"},
        ],
        "gorges": [],
        "filetages": [{"diametre": 44, "pas": 2, "z_debut": 2, "z_fin": 40}],
        "incertitudes": ["Diamètre du brut non coté, 60 supposé"],
    }


def test_piece_de_fraisage_refusee(ia_repond):
    ia_repond({"est_piece_tournee": False, "raison": "Plaque avec poche et perçages."})
    r = client.post("/analyser", files=PHOTO)
    assert r.status_code == 422
    assert "pas une pièce tournée" in r.json()["erreur"]


def test_valeurs_manquantes_deviennent_incertitudes(ia_repond):
    ia_repond({
        "est_piece_tournee": True,
        "raison": "",
        "points": [
            {"nom": "P1", "x": 0, "z": 0, "segment": "droite"},
            {"nom": "P2", "x": 30, "z": 5, "segment": "arc"},
        ],
    })
    inc = client.post("/analyser", files=PHOTO).json()["incertitudes"]
    assert any("Brut non trouvé" in i for i in inc)
    assert any("P2 : arc incomplet" in i for i in inc)


def test_quota_atteint(ia_repond):
    ia_repond(ia.ErreurIA("Quota gratuit Gemini atteint", quota=True))
    r = client.post("/analyser", files=PHOTO)
    assert r.status_code == 429


def test_format_refuse():
    r = client.post("/analyser", files={"photo": ("a.pdf", b"x", "application/pdf")})
    assert r.status_code == 415


def test_sante():
    assert client.get("/sante").json() == {"ok": True}


def test_photo_manquante():
    r = client.post("/analyser", data={"autre": "x"})
    assert r.status_code == 400
    assert "photo manquante" in r.json()["erreur"]
