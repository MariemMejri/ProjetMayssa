// Réglages machine / coupe. Modifiables par l'utilisateur (enregistrés en phase 5).
// Unités : mm, mm/tr (G99), m/min (G96), tr/min.

class Reglages {
  final int numeroProgramme;

  // Outils (T0101, T0202, T0303)
  final int outilEbauche;
  final int outilGorge;
  final int outilFiletage;

  // Position de sécurité (X en diamètre) et distance d'approche au-dessus du brut
  final double securiteX;
  final double securiteZ;
  final double distanceApproche;

  // Ébauche G71
  final double profondeurPasse; // au rayon
  final double retraitEbauche;
  final double avanceEbauche;
  final double surepaisseurU; // au diamètre
  final double surepaisseurW;
  final double vitesseCoupeEbauche;
  final int vitesseBrocheMax; // G50

  // Finition G70
  final double vitesseCoupeFinition;
  final double avanceFinition;

  // Arcs : true = tourelle arrière (concave -> G2, convexe -> G3).
  // false = tourelle avant (inverse).
  final bool concaveEnG2;

  // Gorges G75
  final double largeurOutilGorge;
  final double vitesseCoupeGorge;
  final double avanceGorge;
  final double picGorge; // profondeur de chaque pic, au rayon
  final double retraitGorge;

  /// false = le point piloté de l'outil à gorge est son arête côté face libre ;
  /// true = son arête côté mandrin.
  final bool referenceGorgeCoteMandrin;

  // Filetage G76 (toujours en G97 : vitesse de broche constante)
  final int vitesseBrocheFiletage;
  final int passesFinitionFilet;
  final double premierePasseFilet; // au rayon
  final double passeMiniFilet; // au rayon
  final double surepaisseurFilet;

  const Reglages({
    this.numeroProgramme = 1,
    this.outilEbauche = 1,
    this.outilGorge = 2,
    this.outilFiletage = 3,
    this.securiteX = 100,
    this.securiteZ = 50,
    this.distanceApproche = 2,
    this.profondeurPasse = 1.5,
    this.retraitEbauche = 0.5,
    this.avanceEbauche = 0.25,
    this.surepaisseurU = 0.4,
    this.surepaisseurW = 0.1,
    this.vitesseCoupeEbauche = 180,
    this.vitesseBrocheMax = 2500,
    this.vitesseCoupeFinition = 220,
    this.avanceFinition = 0.1,
    this.concaveEnG2 = true,
    this.largeurOutilGorge = 3,
    this.vitesseCoupeGorge = 80,
    this.avanceGorge = 0.05,
    this.picGorge = 1,
    this.retraitGorge = 0.5,
    this.referenceGorgeCoteMandrin = false,
    this.vitesseBrocheFiletage = 600,
    this.passesFinitionFilet = 1,
    this.premierePasseFilet = 0.3,
    this.passeMiniFilet = 0.1,
    this.surepaisseurFilet = 0.05,
  });
}
