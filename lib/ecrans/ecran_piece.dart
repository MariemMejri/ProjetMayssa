// Écran 1 (phase 2) : saisie / modification des cotes de la pièce.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../exemples.dart';
import '../gcode/generateur.dart';
import '../gcode/piece.dart';
import '../gcode/reglages.dart';
import 'brouillon.dart';
import 'ecran_gcode.dart';

class EcranPiece extends StatefulWidget {
  /// Pièce lue par l'IA. Si null (saisie à la main) : l'exemple est chargé.
  final Piece? pieceInitiale;

  const EcranPiece({super.key, this.pieceInitiale});

  @override
  State<EcranPiece> createState() => _EcranPieceState();
}

class _EcranPieceState extends State<EcranPiece> {
  final _defilement = ScrollController();
  late BrouillonPiece _b;
  List<String> _erreurs = [];

  @override
  void initState() {
    super.initState();
    _b = BrouillonPiece.depuis(
        widget.pieceInitiale ?? Piece.fromJson(jsonDecode(exempleJson)));
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  void _remplacer(BrouillonPiece b) => setState(() {
        _b = b;
        _erreurs = [];
      });

  void _generer() {
    FocusScope.of(context).unfocus();
    String? gcode;
    List<String> erreurs = [];
    try {
      gcode = genererGcode(_b.versPiece(), const Reglages());
    } on FormatException catch (e) {
      erreurs = [e.message];
    } on PieceInvalideException catch (e) {
      erreurs = e.erreurs;
    }
    setState(() => _erreurs = erreurs);

    if (gcode != null) {
      final numero = const Reglages().numeroProgramme.toString().padLeft(4, '0');
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranGcode(gcode: gcode!, nomFichier: 'O$numero.nc'),
      ));
    } else {
      _defilement.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _importerJson() async {
    final controleur = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coller le JSON de la pièce'),
        content: TextField(
          controller: controleur,
          maxLines: 12,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controleur.text),
              child: const Text('Importer')),
        ],
      ),
    );
    controleur.dispose();
    if (texte == null || texte.trim().isEmpty || !mounted) return;
    try {
      final piece = Piece.fromJson(jsonDecode(texte) as Map<String, dynamic>);
      _remplacer(BrouillonPiece.depuis(piece));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('JSON invalide : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotes de la pièce'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (choix) => switch (choix) {
              'exemple' => _remplacer(BrouillonPiece.depuis(
                  Piece.fromJson(jsonDecode(exempleJson)))),
              'json' => _importerJson(),
              _ => _remplacer(BrouillonPiece()),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'nouvelle', child: Text('Nouvelle pièce')),
              PopupMenuItem(value: 'exemple', child: Text('Charger l\'exemple')),
              PopupMenuItem(value: 'json', child: Text('Importer du JSON')),
            ],
          ),
        ],
      ),
      body: ListView(
        // La clé change quand on remplace la pièce : tous les champs se réinitialisent.
        key: ObjectKey(_b),
        controller: _defilement,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (_b.incertitudes.isNotEmpty) _carteIncertitudes(),
          if (_erreurs.isNotEmpty) _carteErreurs(),
          _section('Brut', null, [
            Row(children: [
              _champ('Ø brut', _b.diametreBrut, (v) => _b.diametreBrut = v),
              _champ('Longueur', _b.longueurBrut, (v) => _b.longueurBrut = v),
            ]),
          ]),
          _section(
            'Profil extérieur',
            'De la face libre vers le mandrin. X = diamètre, Z = distance '
                'depuis la face. X et Z ne diminuent jamais.',
            [
              for (var i = 0; i < _b.points.length; i++) _lignePoint(i),
              _boutonAjouter('Ajouter un point', () {
                final dernier = _b.points.last;
                _b.points.add(BrouillonPoint(x: dernier.x, z: dernier.z));
              }),
            ],
          ),
          _section('Gorges', 'Z = flanc côté face libre.', [
            for (var i = 0; i < _b.gorges.length; i++) _ligneGorge(i),
            _boutonAjouter('Ajouter une gorge', () => _b.gorges.add(BrouillonGorge())),
          ]),
          _section('Filetages', 'Profondeur calculée : 0,6134 × pas.', [
            for (var i = 0; i < _b.filetages.length; i++) _ligneFiletage(i),
            _boutonAjouter(
                'Ajouter un filetage', () => _b.filetages.add(BrouillonFiletage())),
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generer,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Générer le G-code'),
      ),
    );
  }

  // ---------- Cartes du haut ----------

  Widget _carteIncertitudes() {
    return Card(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('À vérifier sur le dessin, puis cocher :',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            for (final inc in _b.incertitudes)
              CheckboxListTile(
                value: inc.confirmee,
                onChanged: (v) => setState(() => inc.confirmee = v ?? false),
                title: Text(inc.texte, style: const TextStyle(color: Colors.black87)),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _carteErreurs() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Génération refusée :',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onErrorContainer)),
            const SizedBox(height: 4),
            for (final e in _erreurs)
              Text('• $e',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
          ],
        ),
      ),
    );
  }

  // ---------- Lignes ----------

  Widget _lignePoint(int i) {
    final p = _b.points[i];
    return Padding(
      key: p.cle,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          SizedBox(
              width: 32,
              child: Text('P${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          _champ('Ø X', p.x, (v) => p.x = v),
          _champ('Z', p.z, (v) => p.z = v),
          PopupMenuButton<String>(
            tooltip: 'Actions sur P${i + 1}',
            onSelected: (action) => setState(() {
              if (action == 'inserer') {
                // Nouveau point juste après, aux mêmes cotes : à corriger.
                _b.points.insert(i + 1, BrouillonPoint(x: p.x, z: p.z));
              } else {
                _b.points.removeAt(i);
              }
            }),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'inserer', child: Text('Insérer un point après P${i + 1}')),
              PopupMenuItem(
                  value: 'supprimer',
                  enabled: _b.points.length > 1,
                  child: const Text('Supprimer')),
            ],
          ),
        ]),
        if (i > 0)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4, right: 48),
            child: Row(children: [
              DropdownButton<TypeArc?>(
                value: p.arc ? p.typeArc : null,
                onChanged: (v) => setState(() {
                  p.arc = v != null;
                  if (v != null) p.typeArc = v;
                }),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Droite')),
                  DropdownMenuItem(value: TypeArc.concave, child: Text('Arc concave')),
                  DropdownMenuItem(value: TypeArc.convexe, child: Text('Arc convexe')),
                ],
              ),
              const SizedBox(width: 8),
              if (p.arc) _champ('Rayon', p.rayon, (v) => p.rayon = v),
            ]),
          ),
      ]),
    );
  }

  Widget _ligneGorge(int i) {
    final g = _b.gorges[i];
    return Padding(
      key: g.cle,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        _champ('Ø fond', g.diametreFond, (v) => g.diametreFond = v),
        _champ('Largeur', g.largeur, (v) => g.largeur = v),
        _champ('Z', g.z, (v) => g.z = v),
        _boutonSupprimer(() => _b.gorges.removeAt(i)),
      ]),
    );
  }

  Widget _ligneFiletage(int i) {
    final f = _b.filetages[i];
    return Padding(
      key: f.cle,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        _champ('Ø', f.diametre, (v) => f.diametre = v),
        _champ('Pas', f.pas, (v) => f.pas = v),
        _champ('Z début', f.zDebut, (v) => f.zDebut = v),
        _champ('Z fin', f.zFin, (v) => f.zFin = v),
        _boutonSupprimer(() => _b.filetages.removeAt(i)),
      ]),
    );
  }

  // ---------- Petits widgets réutilisés ----------

  Widget _section(String titre, String? aide, List<Widget> enfants) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: Theme.of(context).textTheme.titleMedium),
            if (aide != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text(aide, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            ...enfants,
          ],
        ),
      ),
    );
  }

  Widget _champ(String label, String valeur, ValueChanged<String> surChangement) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextFormField(
          initialValue: valeur,
          onChanged: surChangement,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _boutonSupprimer(VoidCallback? action) {
    return IconButton(
      icon: const Icon(Icons.delete_outline),
      tooltip: 'Supprimer',
      onPressed: action == null ? null : () => setState(action),
    );
  }

  Widget _boutonAjouter(String texte, VoidCallback action) {
    return TextButton.icon(
      icon: const Icon(Icons.add),
      label: Text(texte),
      onPressed: () => setState(action),
    );
  }
}
