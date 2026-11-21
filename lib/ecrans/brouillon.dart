// Brouillon de pièce pour le formulaire : chaque champ est un texte modifiable.
// On ne crée la vraie Piece qu'au moment de générer (versPiece).

import 'package:flutter/foundation.dart';

import '../gcode/piece.dart';

String _texte(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Lit un nombre saisi ("12,5" ou "12.5"). Lève FormatException si invalide.
double lireNombre(String texte, String champ) {
  final v = double.tryParse(texte.trim().replaceAll(',', '.'));
  if (v == null) throw FormatException('$champ : nombre invalide « $texte »');
  return v;
}

class BrouillonPoint {
  final Key cle = UniqueKey();
  String x;
  String z;
  bool arc;
  String rayon;
  TypeArc typeArc;

  BrouillonPoint({
    this.x = '',
    this.z = '',
    this.arc = false,
    this.rayon = '',
    this.typeArc = TypeArc.concave,
  });

  factory BrouillonPoint.depuis(Point p) => BrouillonPoint(
        x: _texte(p.x),
        z: _texte(p.z),
        arc: p.segment == TypeSegment.arc,
        rayon: _texte(p.rayon),
        typeArc: p.typeArc ?? TypeArc.concave,
      );
}

class BrouillonGorge {
  final Key cle = UniqueKey();
  String diametreFond;
  String largeur;
  String z;

  BrouillonGorge({this.diametreFond = '', this.largeur = '', this.z = ''});
}

class BrouillonFiletage {
  final Key cle = UniqueKey();
  String diametre;
  String pas;
  String zDebut;
  String zFin;

  BrouillonFiletage(
      {this.diametre = '', this.pas = '', this.zDebut = '', this.zFin = ''});
}

class BrouillonPiece {
  String diametreBrut;
  String longueurBrut;
  final List<BrouillonPoint> points;
  final List<BrouillonGorge> gorges;
  final List<BrouillonFiletage> filetages;
  final List<Incertitude> incertitudes;

  BrouillonPiece({
    this.diametreBrut = '',
    this.longueurBrut = '',
    List<BrouillonPoint>? points,
    List<BrouillonGorge>? gorges,
    List<BrouillonFiletage>? filetages,
    List<Incertitude>? incertitudes,
  })  : points = points ?? [BrouillonPoint(x: '0', z: '0')],
        gorges = gorges ?? [],
        filetages = filetages ?? [],
        incertitudes = incertitudes ?? [];

  factory BrouillonPiece.depuis(Piece p) => BrouillonPiece(
        diametreBrut: _texte(p.brut.diametre),
        longueurBrut: _texte(p.brut.longueur),
        points: p.points.map(BrouillonPoint.depuis).toList(),
        gorges: p.gorges
            .map((g) => BrouillonGorge(
                diametreFond: _texte(g.diametreFond),
                largeur: _texte(g.largeur),
                z: _texte(g.z)))
            .toList(),
        filetages: p.filetages
            .map((f) => BrouillonFiletage(
                diametre: _texte(f.diametre),
                pas: _texte(f.pas),
                zDebut: _texte(f.zDebut),
                zFin: _texte(f.zFin)))
            .toList(),
        incertitudes: p.incertitudes,
      );

  /// Convertit en Piece. Les points sont renommés P1, P2, ... dans l'ordre.
  Piece versPiece() {
    final points = <Point>[];
    for (var i = 0; i < this.points.length; i++) {
      final b = this.points[i];
      final nom = 'P${i + 1}';
      points.add(Point(
        nom: nom,
        x: lireNombre(b.x, '$nom Ø X'),
        z: lireNombre(b.z, '$nom Z'),
        segment: b.arc ? TypeSegment.arc : TypeSegment.droite,
        rayon: b.arc ? lireNombre(b.rayon, '$nom rayon') : null,
        typeArc: b.arc ? b.typeArc : null,
      ));
    }
    return Piece(
      brut: Brut(
        diametre: lireNombre(diametreBrut, 'Brut Ø'),
        longueur: lireNombre(longueurBrut, 'Brut longueur'),
      ),
      points: points,
      gorges: [
        for (final (i, g) in gorges.indexed)
          Gorge(
            diametreFond: lireNombre(g.diametreFond, 'Gorge ${i + 1} Ø fond'),
            largeur: lireNombre(g.largeur, 'Gorge ${i + 1} largeur'),
            z: lireNombre(g.z, 'Gorge ${i + 1} Z'),
          ),
      ],
      filetages: [
        for (final (i, f) in filetages.indexed)
          Filetage(
            diametre: lireNombre(f.diametre, 'Filetage ${i + 1} Ø'),
            pas: lireNombre(f.pas, 'Filetage ${i + 1} pas'),
            zDebut: lireNombre(f.zDebut, 'Filetage ${i + 1} Z début'),
            zFin: lireNombre(f.zFin, 'Filetage ${i + 1} Z fin'),
          ),
      ],
      incertitudes: incertitudes,
    );
  }
}
