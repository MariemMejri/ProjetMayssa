import 'dart:convert';

import 'package:demo5/gcode/generateur.dart';
import 'package:demo5/gcode/piece.dart';
import 'package:demo5/gcode/reglages.dart';
import 'package:flutter_test/flutter_test.dart';

const reglages = Reglages();

/// Construit une pièce à partir de JSON (comme le renverra l'IA)
/// et confirme toutes les incertitudes.
Piece pieceDepuisJson(String texte, {bool confirmer = true}) {
  final piece = Piece.fromJson(jsonDecode(texte) as Map<String, dynamic>);
  if (confirmer) {
    for (final i in piece.incertitudes) {
      i.confirmee = true;
    }
  }
  return piece;
}

/// Vérifie que la génération est refusée avec une erreur contenant [extrait].
void attendreRefus(Piece piece, String extrait) {
  expect(
    () => genererGcode(piece, reglages),
    throwsA(isA<PieceInvalideException>().having(
      (e) => e.erreurs.join('\n'),
      'erreurs',
      contains(extrait),
    )),
  );
}

void main() {
  group('Pièces d\'exemple -> G-code exact', () {
    test('1. Cylindre avec chanfrein', () {
      final piece = pieceDepuisJson('''
      {
        "brut": {"diametre": 50, "longueur": 80},
        "points": [
          {"nom": "P1", "x": 0,  "z": 0},
          {"nom": "P2", "x": 36, "z": 0},
          {"nom": "P3", "x": 40, "z": 2},
          {"nom": "P4", "x": 40, "z": 30}
        ]
      }''');

      expect(genererGcode(piece, reglages), '''
%
O0001
(PROGRAMME NON VERIFIE - SIMULER AVANT USINAGE)
(BRUT D50. L80.)
G21 G40 G99
G0 X100. Z50.
(EBAUCHE)
T0101
G50 S2500
G96 S180. M3
G0 X52. Z2.
G71 U1.5 R0.5
G71 P10 Q20 U0.4 W0.1 F0.25
N10 G0 X0.
G1 Z0. F0.1
G1 X36.
G1 X40. Z-2.
G1 Z-30.
N20 G1 X52.
(FINITION)
G96 S220.
G70 P10 Q20
G0 X100. Z50.
M5
M30
%
''');
    });

    test('2. Exemple du cahier des charges (arc concave, gorge, filetage)', () {
      final piece = pieceDepuisJson('''
      {
        "brut": {"diametre": 60, "longueur": 100},
        "points": [
          {"nom": "P1", "x": 0,  "z": 0},
          {"nom": "P2", "x": 40, "z": 0},
          {"nom": "P3", "x": 44, "z": 2},
          {"nom": "P4", "x": 44, "z": 50},
          {"nom": "P5", "x": 56, "z": 56, "segment": "arc", "rayon": 6, "type": "concave"}
        ],
        "gorges":    [{"diametre_fond": 32, "largeur": 3, "z": 48}],
        "filetages": [{"diametre": 44, "pas": 2, "z_debut": 2, "z_fin": 40}],
        "incertitudes": ["Diamètre du brut non coté, 60 supposé"]
      }''');

      expect(genererGcode(piece, reglages), '''
%
O0001
(PROGRAMME NON VERIFIE - SIMULER AVANT USINAGE)
(BRUT D60. L100.)
G21 G40 G99
G0 X100. Z50.
(EBAUCHE)
T0101
G50 S2500
G96 S180. M3
G0 X62. Z2.
G71 U1.5 R0.5
G71 P10 Q20 U0.4 W0.1 F0.25
N10 G0 X0.
G1 Z0. F0.1
G1 X40.
G1 X44. Z-2.
G1 Z-50.
G2 X56. Z-56. R6.
N20 G1 X62.
(FINITION)
G96 S220.
G70 P10 Q20
G0 X100. Z50.
(GORGES)
T0202
G96 S80. M3
(GORGE D32. L3. Z48.)
G0 X62. Z-48.
G75 R0.5
G75 X32. Z-48. P1000 F0.05
G0 X62.
G0 X100. Z50.
(FILETAGES)
T0303
G97 S600 M3
(FILETAGE M44. PAS 2.)
G0 X62. Z2.
G76 P010060 Q100 R0.05
G76 X41.546 Z-40. P1227 Q300 F2.
G0 X100. Z50.
M5
M30
%
''');
    });

    test('3. Arc convexe, épaulement, gorge plus large que l\'outil', () {
      final piece = pieceDepuisJson('''
      {
        "brut": {"diametre": 40, "longueur": 60},
        "points": [
          {"nom": "P1", "x": 0,  "z": 0},
          {"nom": "P2", "x": 24, "z": 0},
          {"nom": "P3", "x": 30, "z": 3, "segment": "arc", "rayon": 3, "type": "convexe"},
          {"nom": "P4", "x": 30, "z": 25},
          {"nom": "P5", "x": 36, "z": 25},
          {"nom": "P6", "x": 36, "z": 40}
        ],
        "gorges": [{"diametre_fond": 24, "largeur": 5, "z": 20}]
      }''');

      expect(genererGcode(piece, reglages), '''
%
O0001
(PROGRAMME NON VERIFIE - SIMULER AVANT USINAGE)
(BRUT D40. L60.)
G21 G40 G99
G0 X100. Z50.
(EBAUCHE)
T0101
G50 S2500
G96 S180. M3
G0 X42. Z2.
G71 U1.5 R0.5
G71 P10 Q20 U0.4 W0.1 F0.25
N10 G0 X0.
G1 Z0. F0.1
G1 X24.
G3 X30. Z-3. R3.
G1 Z-25.
G1 X36.
G1 Z-40.
N20 G1 X42.
(FINITION)
G96 S220.
G70 P10 Q20
G0 X100. Z50.
(GORGES)
T0202
G96 S80. M3
(GORGE D24. L5. Z20.)
G0 X42. Z-20.
G75 R0.5
G75 X24. Z-22. P1000 Q2400 F0.05
G0 X42.
G0 X100. Z50.
M5
M30
%
''');
    });

    test('Tourelle avant : les arcs sont inversés', () {
      final piece = pieceDepuisJson('''
      {
        "brut": {"diametre": 60, "longueur": 100},
        "points": [
          {"nom": "P1", "x": 0,  "z": 0},
          {"nom": "P2", "x": 44, "z": 0},
          {"nom": "P3", "x": 44, "z": 50},
          {"nom": "P4", "x": 56, "z": 56, "segment": "arc", "rayon": 6, "type": "concave"}
        ]
      }''');
      final gcode = genererGcode(piece, const Reglages(concaveEnG2: false));
      expect(gcode, contains('G3 X56. Z-56. R6.'));
    });
  });

  group('Premier vrai dessin lu par Gemini', () {
    String json(String pointsAvantArc) => '''
      {
        "brut": {"diametre": 85, "longueur": 103.393},
        "points": [
          {"nom": "P1", "x": 0, "z": 0},
          {"nom": "P2", "x": 30, "z": 0},
          {"nom": "P3", "x": 40, "z": 5},
          {"nom": "P4", "x": 40, "z": 35},
          {"nom": "P5", "x": 42, "z": 39},
          {"nom": "P6", "x": 42, "z": 46.393},
          {"nom": "P7", "x": 60, "z": 58.393},
          {"nom": "P8", "x": 60, "z": 78.393},
          $pointsAvantArc
          {"nom": "P9", "x": 80, "z": 82.393, "segment": "arc", "rayon": 4, "type": "convexe"},
          {"nom": "P10", "x": 80, "z": 98.393}
        ]
      }''';

    test('tel que lu : arc R4 impossible, refusé', () {
      attendreRefus(pieceDepuisJson(json('')), 'P9 : rayon R4.0 trop petit');
    });

    test('corrigé (face Ø60 -> Ø72 puis arrondi R4) : G-code généré', () {
      final gcode = genererGcode(
          pieceDepuisJson(json('{"nom": "P8b", "x": 72, "z": 78.393},')), reglages);
      expect(gcode, contains('G1 Z-78.393\nG1 X72.\nG3 X80. Z-82.393 R4.\n'));
      expect(gcode, contains('N20 G1 X87.'));
    });
  });

  group('Format des nombres Fanuc', () {
    test('toujours un point décimal', () {
      expect(nombre(44), '44.');
      expect(nombre(0), '0.');
      expect(nombre(-2), '-2.');
      expect(nombre(2.5), '2.5');
      expect(nombre(41.5464), '41.546');
      expect(nombre(-0.0001), '0.');
    });
  });

  group('Contrôles avant génération', () {
    const profilOk = '''
      {"nom": "P1", "x": 0,  "z": 0},
      {"nom": "P2", "x": 40, "z": 0},
      {"nom": "P3", "x": 40, "z": 30}''';

    test('X qui diminue', () {
      attendreRefus(pieceDepuisJson('''
      {"brut": {"diametre": 50, "longueur": 80},
       "points": [{"nom": "P1", "x": 0, "z": 0}, {"nom": "P2", "x": 40, "z": 10},
                  {"nom": "P3", "x": 30, "z": 20}]}'''), 'X diminue');
    });

    test('Z qui diminue', () {
      attendreRefus(pieceDepuisJson('''
      {"brut": {"diametre": 50, "longueur": 80},
       "points": [{"nom": "P1", "x": 0, "z": 0}, {"nom": "P2", "x": 40, "z": 10},
                  {"nom": "P3", "x": 45, "z": 5}]}'''), 'Z diminue');
    });

    test('Diamètre plus grand que le brut', () {
      attendreRefus(pieceDepuisJson('''
      {"brut": {"diametre": 30, "longueur": 80}, "points": [$profilOk]}'''),
          'dépasse le diamètre du brut');
    });

    test('Z plus grand que la longueur du brut', () {
      attendreRefus(pieceDepuisJson('''
      {"brut": {"diametre": 50, "longueur": 20}, "points": [$profilOk]}'''),
          'dépasse la longueur du brut');
    });

    test('Rayon d\'arc trop petit', () {
      attendreRefus(pieceDepuisJson('''
      {"brut": {"diametre": 60, "longueur": 80},
       "points": [{"nom": "P1", "x": 0, "z": 0}, {"nom": "P2", "x": 40, "z": 0},
                  {"nom": "P3", "x": 50, "z": 10, "segment": "arc", "rayon": 2, "type": "convexe"}]}'''),
          'rayon R2.0 trop petit');
    });

    test('Filetage hors du profil', () {
      attendreRefus(pieceDepuisJson('''
      {"brut": {"diametre": 50, "longueur": 80}, "points": [$profilOk],
       "filetages": [{"diametre": 40, "pas": 1.5, "z_debut": 10, "z_fin": 45}]}'''),
          'sort du profil');
    });

    test('Gorge hors du profil', () {
      attendreRefus(pieceDepuisJson('''
      {"brut": {"diametre": 50, "longueur": 80}, "points": [$profilOk],
       "gorges": [{"diametre_fond": 34, "largeur": 3, "z": 29}]}'''),
          'sort du profil');
    });

    test('Incertitude non confirmée', () {
      attendreRefus(
          pieceDepuisJson('''
      {"brut": {"diametre": 50, "longueur": 80}, "points": [$profilOk],
       "incertitudes": ["Longueur du brut supposée"]}''', confirmer: false),
          'Incertitude non confirmée');
    });
  });
}
