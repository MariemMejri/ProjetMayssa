// Contrôles avant génération. Renvoie la liste des erreurs (vide = OK).

import 'dart:math';

import 'piece.dart';
import 'reglages.dart';

const double _eps = 0.0005;

List<String> validerPiece(Piece piece, Reglages r) {
  final erreurs = <String>[];
  final brut = piece.brut;
  final pts = piece.points;

  // --- Brut ---
  if (brut.diametre <= 0 || brut.longueur <= 0) {
    erreurs.add('Le brut doit avoir un diamètre et une longueur positifs.');
  }

  // --- Réglages de sécurité ---
  if (r.securiteX < brut.diametre + r.distanceApproche) {
    erreurs.add('Position de sécurité X${r.securiteX} trop proche du brut '
        '(Ø${brut.diametre}).');
  }
  if (r.securiteZ < r.distanceApproche) {
    erreurs.add('Position de sécurité Z${r.securiteZ} trop proche de la face.');
  }

  // --- Profil ---
  if (pts.length < 2) {
    erreurs.add('Le profil doit contenir au moins 2 points.');
    return erreurs; // la suite n'a pas de sens
  }

  if (pts.first.segment == TypeSegment.arc) {
    erreurs.add('${pts.first.nom} : le premier point ne peut pas être la fin d\'un arc.');
  }

  for (var i = 0; i < pts.length; i++) {
    final p = pts[i];
    if (p.x < -_eps || p.z < -_eps) {
      erreurs.add('${p.nom} : X et Z doivent être positifs ou nuls.');
    }
    if (p.x > brut.diametre + _eps) {
      erreurs.add('${p.nom} : Ø${p.x} dépasse le diamètre du brut (Ø${brut.diametre}).');
    }
    if (p.z > brut.longueur + _eps) {
      erreurs.add('${p.nom} : Z${p.z} dépasse la longueur du brut (${brut.longueur}).');
    }
    if (i == 0) continue;

    final prec = pts[i - 1];
    if (p.x < prec.x - _eps) {
      erreurs.add('${prec.nom} → ${p.nom} : X diminue (${prec.x} → ${p.x}). '
          'Le cycle G71 type I ne peut pas l\'usiner.');
    }
    if (p.z < prec.z - _eps) {
      erreurs.add('${prec.nom} → ${p.nom} : Z diminue (${prec.z} → ${p.z}).');
    }
    if ((p.x - prec.x).abs() < _eps && (p.z - prec.z).abs() < _eps) {
      erreurs.add('${prec.nom} et ${p.nom} sont identiques.');
    }

    if (p.segment == TypeSegment.arc) {
      if (p.rayon == null || p.rayon! <= 0) {
        erreurs.add('${p.nom} : l\'arc doit avoir un rayon positif.');
      } else {
        // Distance réelle entre les points (X est un diamètre -> /2).
        final corde = sqrt(pow((p.x - prec.x) / 2, 2) + pow(p.z - prec.z, 2));
        if (p.rayon! < corde / 2 - _eps) {
          erreurs.add('${p.nom} : rayon R${p.rayon} trop petit, minimum '
              '${(corde / 2).toStringAsFixed(3)} pour relier ${prec.nom} à ${p.nom}.');
        }
      }
      if (p.typeArc == null) {
        erreurs.add('${p.nom} : préciser si l\'arc est concave ou convexe.');
      }
    }
  }

  final zMin = pts.first.z;
  final zMax = pts.last.z;

  // --- Gorges ---
  for (final g in piece.gorges) {
    final nom = 'Gorge Z${g.z}';
    if (g.largeur <= 0 || g.diametreFond <= 0) {
      erreurs.add('$nom : largeur et Ø fond doivent être positifs.');
      continue;
    }
    if (g.largeur < r.largeurOutilGorge - _eps) {
      erreurs.add('$nom : largeur ${g.largeur} plus petite que l\'outil '
          '(${r.largeurOutilGorge}).');
    }
    final zFin = g.z + g.largeur;
    if (g.z < zMin - _eps || zFin > zMax + _eps) {
      erreurs.add('$nom : sort du profil (Z${g.z} à Z$zFin, profil de Z$zMin à Z$zMax).');
      continue;
    }
    final dMin = min(diametreProfil(pts, g.z), diametreProfil(pts, zFin));
    if (g.diametreFond >= dMin - _eps) {
      erreurs.add('$nom : Ø fond ${g.diametreFond} n\'est pas sous le profil (Ø$dMin).');
    }
  }

  // --- Filetages ---
  for (final f in piece.filetages) {
    final nom = 'Filetage Ø${f.diametre}';
    if (f.pas <= 0) {
      erreurs.add('$nom : le pas doit être positif.');
      continue;
    }
    if (f.zDebut >= f.zFin) {
      erreurs.add('$nom : z_debut doit être plus petit que z_fin.');
      continue;
    }
    if (f.zDebut < zMin - _eps || f.zFin > zMax + _eps) {
      erreurs.add('$nom : sort du profil (Z${f.zDebut} à Z${f.zFin}, '
          'profil de Z$zMin à Z$zMax).');
      continue;
    }
    final dMin = min(diametreProfil(pts, f.zDebut), diametreProfil(pts, f.zFin));
    if (f.diametre > dMin + _eps) {
      erreurs.add('$nom : plus grand que le profil à cet endroit (Ø$dMin).');
    }
    if (f.diametreFond <= 0) {
      erreurs.add('$nom : pas trop grand pour ce diamètre.');
    }
  }

  // --- Incertitudes ---
  for (final inc in piece.incertitudes) {
    if (!inc.confirmee) {
      erreurs.add('Incertitude non confirmée : ${inc.texte}');
    }
  }

  return erreurs;
}

/// Diamètre du profil à la cote [z] (interpolation linéaire ; un arc est
/// approché par sa corde, suffisant pour ces contrôles).
/// Sur un épaulement vertical, renvoie le plus petit diamètre.
double diametreProfil(List<Point> pts, double z) {
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1];
    final b = pts[i];
    if (b.z - a.z > _eps && z >= a.z - _eps && z <= b.z + _eps) {
      return a.x + (b.x - a.x) * (z - a.z) / (b.z - a.z);
    }
  }
  return pts.firstWhere((p) => (p.z - z).abs() < _eps, orElse: () => pts.last).x;
}
