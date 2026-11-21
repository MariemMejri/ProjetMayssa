// Modèle de données de la pièce : le "contrat" entre l'IA et le générateur.
// Les noms de champs JSON sont ceux du prototype web (nom, x, z, segment, rayon, type).

/// Lit un nombre JSON (int, double ou texte "12,5") et le convertit en double.
double _lireNombre(dynamic valeur, String champ) {
  if (valeur is num) return valeur.toDouble();
  if (valeur is String) {
    final d = double.tryParse(valeur.trim().replaceAll(',', '.'));
    if (d != null) return d;
  }
  throw FormatException('Champ "$champ" : nombre attendu, reçu "$valeur"');
}

double? _lireNombreOptionnel(dynamic valeur, String champ) =>
    valeur == null ? null : _lireNombre(valeur, champ);

List<Map<String, dynamic>> _lireListe(dynamic valeur) =>
    valeur == null ? [] : List<Map<String, dynamic>>.from(valeur as List);

/// Brut cylindrique.
class Brut {
  final double diametre;
  final double longueur;

  Brut({required this.diametre, required this.longueur});

  factory Brut.fromJson(Map<String, dynamic> json) => Brut(
        diametre: _lireNombre(json['diametre'], 'brut.diametre'),
        longueur: _lireNombre(json['longueur'], 'brut.longueur'),
      );

  Map<String, dynamic> toJson() => {'diametre': diametre, 'longueur': longueur};
}

enum TypeSegment { droite, arc }

/// concave = congé intérieur, convexe = arête arrondie.
enum TypeArc { concave, convexe }

/// Un point du profil extérieur.
/// [x] = DIAMÈTRE en mm, [z] = distance depuis la face libre (positive vers le mandrin).
/// [segment], [rayon] et [typeArc] décrivent le segment qui ARRIVE à ce point.
class Point {
  final String nom;
  final double x;
  final double z;
  final TypeSegment segment;
  final double? rayon;
  final TypeArc? typeArc;

  Point({
    required this.nom,
    required this.x,
    required this.z,
    this.segment = TypeSegment.droite,
    this.rayon,
    this.typeArc,
  });

  factory Point.fromJson(Map<String, dynamic> json) {
    final nom = (json['nom'] ?? '?').toString();
    final segmentTexte = (json['segment'] ?? 'droite').toString().toLowerCase();
    final typeTexte = json['type']?.toString().toLowerCase();
    return Point(
      nom: nom,
      x: _lireNombre(json['x'], '$nom.x'),
      z: _lireNombre(json['z'], '$nom.z'),
      segment: segmentTexte == 'arc' ? TypeSegment.arc : TypeSegment.droite,
      rayon: _lireNombreOptionnel(json['rayon'], '$nom.rayon'),
      typeArc: switch (typeTexte) {
        'concave' => TypeArc.concave,
        'convexe' => TypeArc.convexe,
        _ => null,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'x': x,
        'z': z,
        if (segment == TypeSegment.arc) ...{
          'segment': 'arc',
          'rayon': rayon,
          'type': typeArc?.name,
        },
      };
}

/// Gorge : de [z] (flanc côté face libre) à [z] + [largeur] (flanc côté mandrin).
class Gorge {
  final double diametreFond;
  final double largeur;
  final double z;

  Gorge({required this.diametreFond, required this.largeur, required this.z});

  factory Gorge.fromJson(Map<String, dynamic> json) => Gorge(
        diametreFond: _lireNombre(json['diametre_fond'], 'gorge.diametre_fond'),
        largeur: _lireNombre(json['largeur'], 'gorge.largeur'),
        z: _lireNombre(json['z'], 'gorge.z'),
      );

  Map<String, dynamic> toJson() =>
      {'diametre_fond': diametreFond, 'largeur': largeur, 'z': z};
}

/// Filetage métrique extérieur, de [zDebut] à [zFin].
class Filetage {
  final double diametre;
  final double pas;
  final double zDebut;
  final double zFin;

  Filetage({
    required this.diametre,
    required this.pas,
    required this.zDebut,
    required this.zFin,
  });

  /// Profondeur de filet (au rayon) = 0,6134 × pas.
  double get profondeur => 0.6134 * pas;

  /// Ø fond de filet = Ø nominal − 2 × profondeur.
  double get diametreFond => diametre - 2 * profondeur;

  factory Filetage.fromJson(Map<String, dynamic> json) => Filetage(
        diametre: _lireNombre(json['diametre'], 'filetage.diametre'),
        pas: _lireNombre(json['pas'], 'filetage.pas'),
        zDebut: _lireNombre(json['z_debut'], 'filetage.z_debut'),
        zFin: _lireNombre(json['z_fin'], 'filetage.z_fin'),
      );

  Map<String, dynamic> toJson() =>
      {'diametre': diametre, 'pas': pas, 'z_debut': zDebut, 'z_fin': zFin};
}

/// Une supposition de l'IA que l'utilisateur doit confirmer.
class Incertitude {
  final String texte;
  bool confirmee;

  Incertitude(this.texte, {this.confirmee = false});
}

/// La pièce complète.
class Piece {
  final Brut brut;
  final List<Point> points;
  final List<Gorge> gorges;
  final List<Filetage> filetages;
  final List<Incertitude> incertitudes;

  Piece({
    required this.brut,
    required this.points,
    this.gorges = const [],
    this.filetages = const [],
    this.incertitudes = const [],
  });

  /// Les incertitudes venant du JSON sont toujours NON confirmées.
  factory Piece.fromJson(Map<String, dynamic> json) => Piece(
        brut: Brut.fromJson(Map<String, dynamic>.from(json['brut'] as Map)),
        points: _lireListe(json['points']).map(Point.fromJson).toList(),
        gorges: _lireListe(json['gorges']).map(Gorge.fromJson).toList(),
        filetages: _lireListe(json['filetages']).map(Filetage.fromJson).toList(),
        incertitudes: ((json['incertitudes'] as List?) ?? [])
            .map((t) => Incertitude(t.toString()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'brut': brut.toJson(),
        'points': points.map((p) => p.toJson()).toList(),
        'gorges': gorges.map((g) => g.toJson()).toList(),
        'filetages': filetages.map((f) => f.toJson()).toList(),
        'incertitudes': incertitudes.map((i) => i.texte).toList(),
      };
}
