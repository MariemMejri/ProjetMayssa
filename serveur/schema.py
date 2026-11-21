"""Schéma de la réponse demandée à l'IA, et conversion vers le "contrat" JSON
lu par l'application (mêmes noms de champs que le prototype web)."""

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class Segment(str, Enum):
    droite = "droite"
    arc = "arc"


class TypeArc(str, Enum):
    concave = "concave"
    convexe = "convexe"


class Brut(BaseModel):
    diametre: float = Field(description="Diamètre du brut en mm")
    longueur: float = Field(description="Longueur du brut en mm")


class Point(BaseModel):
    nom: str = Field(description="P1, P2, P3...")
    x: float = Field(description="DIAMÈTRE en mm (pas le rayon)")
    z: float = Field(description="Distance en mm depuis la face libre, positive vers le mandrin")
    segment: Segment = Field(description="Forme du segment qui ARRIVE à ce point")
    rayon: Optional[float] = Field(None, description="Rayon de l'arc, seulement si segment = arc")
    type: Optional[TypeArc] = Field(None, description="Seulement si segment = arc")


class Gorge(BaseModel):
    diametre_fond: float
    largeur: float
    z: float = Field(description="Z du flanc de la gorge côté face libre")


class Filetage(BaseModel):
    diametre: float = Field(description="Diamètre nominal, ex. 44 pour M44")
    pas: float
    z_debut: float = Field(description="Z du début du filet, côté face libre")
    z_fin: float = Field(description="Z de la fin du filet, côté mandrin")


class AnalyseDessin(BaseModel):
    est_piece_tournee: bool = Field(
        description="false si le dessin n'est pas une pièce de tournage (fraisage, plaque, illisible...)"
    )
    raison: str = Field(description="Si est_piece_tournee = false : pourquoi, en une phrase. Sinon chaîne vide.")
    brut: Optional[Brut] = None
    points: list[Point] = []
    gorges: list[Gorge] = []
    filetages: list[Filetage] = []
    incertitudes: list[str] = Field(
        [], description="Chaque valeur supposée, déduite ou mal lisible, en une phrase"
    )


def vers_contrat(analyse: AnalyseDessin) -> dict:
    """Transforme la réponse de l'IA en JSON pour l'application.
    N'invente rien : les valeurs manquantes deviennent des incertitudes."""
    incertitudes = list(analyse.incertitudes)

    if analyse.brut is None:
        incertitudes.append("Brut non trouvé : saisir son diamètre et sa longueur.")
        brut = {"diametre": 0, "longueur": 0}
    else:
        brut = analyse.brut.model_dump()

    points = []
    for p in analyse.points:
        point = {"nom": p.nom, "x": p.x, "z": p.z}
        if p.segment == Segment.arc:
            point["segment"] = "arc"
            point["rayon"] = p.rayon
            point["type"] = p.type.value if p.type else None
            if p.rayon is None or p.type is None:
                incertitudes.append(f"{p.nom} : arc incomplet (rayon ou concave/convexe manquant).")
        points.append(point)

    if len(points) < 2:
        incertitudes.append("Profil non trouvé ou incomplet : saisir les points.")

    return {
        "brut": brut,
        "points": points,
        "gorges": [g.model_dump() for g in analyse.gorges],
        "filetages": [f.model_dump() for f in analyse.filetages],
        "incertitudes": incertitudes,
    }
