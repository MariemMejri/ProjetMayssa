// Pièce d'exemple (celle du cahier des charges), chargée au démarrage.
const String exempleJson = '''
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
}
''';
