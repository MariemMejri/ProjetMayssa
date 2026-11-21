// Générateur de G-code Fanuc (tournage 2 axes).
// Fonction pure : même pièce + mêmes réglages => même texte, à chaque fois.
// Origine : X0 sur l'axe de broche, Z0 sur la face libre ; les z de la pièce
// sont écrits en Z négatif.

import 'piece.dart';
import 'reglages.dart';
import 'validation.dart';

const String avertissement = '(PROGRAMME NON VERIFIE - SIMULER AVANT USINAGE)';

/// Levée quand la pièce ne passe pas les contrôles.
class PieceInvalideException implements Exception {
  final List<String> erreurs;
  PieceInvalideException(this.erreurs);

  @override
  String toString() => 'Pièce invalide :\n- ${erreurs.join('\n- ')}';
}

/// Nombre Fanuc : TOUJOURS avec un point décimal (X44. et non X44,
/// que certaines commandes lisent 0,044 mm). 3 décimales max.
String nombre(double v) {
  final s = v.abs() < 0.0005 ? '0.000' : v.toStringAsFixed(3);
  return s.replaceFirst(RegExp(r'0+$'), '');
}

/// Valeur en microns sans point décimal (P, Q des cycles G75/G76).
String microns(double mm) => (mm * 1000).round().toString();

String _z(double z) => nombre(-z);

String _outil(int n) {
  final t = n.toString().padLeft(2, '0');
  return 'T$t$t';
}

String genererGcode(Piece piece, Reglages r) {
  final erreurs = validerPiece(piece, r);
  if (erreurs.isNotEmpty) throw PieceInvalideException(erreurs);

  final pts = piece.points;
  final xApproche = piece.brut.diametre + r.distanceApproche;
  final securite = 'G0 X${nombre(r.securiteX)} Z${nombre(r.securiteZ)}';
  final l = <String>[];

  // 1. En-tête
  l
    ..add('%')
    ..add('O${r.numeroProgramme.toString().padLeft(4, '0')}')
    ..add(avertissement)
    ..add('(BRUT D${nombre(piece.brut.diametre)} L${nombre(piece.brut.longueur)})')
    ..add('G21 G40 G99')
    ..add(securite);

  // 2. Ébauche G71
  l
    ..add('(EBAUCHE)')
    ..add(_outil(r.outilEbauche))
    ..add('G50 S${r.vitesseBrocheMax}')
    ..add('G96 S${nombre(r.vitesseCoupeEbauche)} M3')
    ..add('G0 X${nombre(xApproche)} Z${nombre(r.distanceApproche)}')
    ..add('G71 U${nombre(r.profondeurPasse)} R${nombre(r.retraitEbauche)}')
    ..add('G71 P10 Q20 U${nombre(r.surepaisseurU)} W${nombre(r.surepaisseurW)} '
        'F${nombre(r.avanceEbauche)}');

  // Profil N10..N20. Premier bloc : X seul (G71 type I).
  l
    ..add('N10 G0 X${nombre(pts.first.x)}')
    ..add('G1 Z${_z(pts.first.z)} F${nombre(r.avanceFinition)}');
  for (var i = 1; i < pts.length; i++) {
    l.add(_blocProfil(pts[i - 1], pts[i], r));
  }
  // Remontée jusqu'au-dessus du brut : usine l'épaulement final.
  l.add('N20 G1 X${nombre(xApproche)}');

  // 3. Finition G70
  l
    ..add('(FINITION)')
    ..add('G96 S${nombre(r.vitesseCoupeFinition)}')
    ..add('G70 P10 Q20')
    ..add(securite);

  // 4. Gorges G75
  if (piece.gorges.isNotEmpty) {
    l
      ..add('(GORGES)')
      ..add(_outil(r.outilGorge))
      ..add('G96 S${nombre(r.vitesseCoupeGorge)} M3');
    for (final g in piece.gorges) {
      final zDebut = r.referenceGorgeCoteMandrin ? g.z + r.largeurOutilGorge : g.z;
      final zFin = zDebut + g.largeur - r.largeurOutilGorge;
      final aDecaler = (zFin - zDebut).abs() > 0.0005;
      l
        ..add('(GORGE D${nombre(g.diametreFond)} L${nombre(g.largeur)} Z${nombre(g.z)})')
        ..add('G0 X${nombre(xApproche)} Z${_z(zDebut)}')
        ..add('G75 R${nombre(r.retraitGorge)}')
        ..add('G75 X${nombre(g.diametreFond)} Z${_z(zFin)} P${microns(r.picGorge)}'
            '${aDecaler ? ' Q${microns(r.largeurOutilGorge * 0.8)}' : ''}'
            ' F${nombre(r.avanceGorge)}')
        ..add('G0 X${nombre(xApproche)}');
    }
    l.add(securite);
  }

  // 5. Filetages G76
  if (piece.filetages.isNotEmpty) {
    l
      ..add('(FILETAGES)')
      ..add(_outil(r.outilFiletage))
      ..add('G97 S${r.vitesseBrocheFiletage} M3');
    for (final f in piece.filetages) {
      final passes = r.passesFinitionFilet.toString().padLeft(2, '0');
      l
        ..add('(FILETAGE M${nombre(f.diametre)} PAS ${nombre(f.pas)})')
        // Départ 2 pas avant le filet pour que l'axe Z soit à vitesse.
        ..add('G0 X${nombre(xApproche)} Z${_z(f.zDebut - 2 * f.pas)}')
        ..add('G76 P${passes}0060 Q${microns(r.passeMiniFilet)} '
            'R${nombre(r.surepaisseurFilet)}')
        ..add('G76 X${nombre(f.diametreFond)} Z${_z(f.zFin)} '
            'P${microns(f.profondeur)} Q${microns(r.premierePasseFilet)} '
            'F${nombre(f.pas)}');
    }
    l.add(securite);
  }

  // 6. Fin
  l
    ..add('M5')
    ..add('M30')
    ..add('%');

  return '${l.join('\n')}\n';
}

/// Un bloc du profil, du point [a] au point [b].
String _blocProfil(Point a, Point b, Reglages r) {
  if (b.segment == TypeSegment.arc) {
    final concave = b.typeArc == TypeArc.concave;
    final g = (concave == r.concaveEnG2) ? 'G2' : 'G3';
    return '$g X${nombre(b.x)} Z${_z(b.z)} R${nombre(b.rayon!)}';
  }
  final axes = [
    if ((b.x - a.x).abs() > 0.0005) 'X${nombre(b.x)}',
    if ((b.z - a.z).abs() > 0.0005) 'Z${_z(b.z)}',
  ];
  return 'G1 ${axes.join(' ')}';
}
