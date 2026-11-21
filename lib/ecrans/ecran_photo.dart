// Écrans 1 et 2 : prendre/choisir la photo, puis analyse par le serveur.
// En cas de succès : écran de vérification des cotes.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/analyse_service.dart';
import '../services/config_serveur.dart';
import 'ecran_piece.dart';

class EcranPhoto extends StatefulWidget {
  const EcranPhoto({super.key});

  @override
  State<EcranPhoto> createState() => _EcranPhotoState();
}

class _EcranPhotoState extends State<EcranPhoto> {
  String _adresse = adresseServeurParDefaut;
  Uint8List? _image;
  String _nomFichier = 'dessin.jpg';
  bool _enCours = false;
  String? _erreur;

  /// Incrémenté à chaque analyse ou annulation : une réponse arrivée
  /// après une annulation est ignorée.
  int _jeton = 0;

  @override
  void initState() {
    super.initState();
    lireAdresseServeur().then((a) {
      if (mounted) setState(() => _adresse = a);
    });
  }

  Future<void> _choisir(ImageSource source) async {
    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: source,
        // Assez grand pour lire les cotes, assez léger pour l'envoi.
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );
    } catch (e) {
      setState(() => _erreur = 'Impossible d\'ouvrir '
          '${source == ImageSource.camera ? 'l\'appareil photo' : 'la galerie'} : $e');
      return;
    }
    if (photo == null) return; // l'utilisateur a annulé

    final octets = await photo.readAsBytes();
    setState(() {
      _image = octets;
      _nomFichier = photo!.name;
      _erreur = null;
    });
    await _analyser();
  }

  Future<void> _analyser() async {
    final jeton = ++_jeton;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final piece = await analyserPhoto(
        adresseServeur: _adresse,
        image: _image!,
        nomFichier: _nomFichier,
      );
      if (!mounted || jeton != _jeton) return;
      setState(() => _enCours = false);
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranPiece(pieceInitiale: piece),
      ));
    } on ErreurAnalyse catch (e) {
      if (!mounted || jeton != _jeton) return;
      setState(() {
        _enCours = false;
        _erreur = e.message;
      });
    }
  }

  void _annuler() => setState(() {
        _jeton++;
        _enCours = false;
      });

  Future<void> _modifierAdresse() async {
    final controleur = TextEditingController(text: _adresse);
    final adresse = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adresse du serveur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controleur,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.20:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Émulateur Android : http://10.0.2.2:8000\n'
                'Téléphone : l\'IP du PC sur le même Wi-Fi (commande ipconfig).'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controleur.text),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    controleur.dispose();
    if (adresse == null || adresse.trim().isEmpty) return;
    await enregistrerAdresseServeur(adresse);
    if (mounted) setState(() => _adresse = adresse.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo du dessin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Adresse du serveur',
            onPressed: _enCours ? null : _modifierAdresse,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('Conseils'),
                  subtitle: const Text(
                      'Dessin à plat, bien éclairé, sans reflet, entier dans le cadre.'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _image == null
                      ? Center(
                          child: Icon(Icons.image_outlined,
                              size: 64, color: theme.colorScheme.outline))
                      : Image.memory(_image!, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              if (_enCours) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('Analyse du dessin… (5 à 20 s)')),
                  TextButton(onPressed: _annuler, child: const Text('Annuler')),
                ]),
              ],
              if (_erreur != null)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_erreur!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                        if (_image != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: _analyser, child: const Text('Réessayer')),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: const Text('Prendre une photo'),
                onPressed: _enCours ? null : () => _choisir(ImageSource.camera),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choisir dans la galerie'),
                onPressed: _enCours ? null : () => _choisir(ImageSource.gallery),
              ),
              TextButton(
                onPressed: _enCours
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const EcranPiece(),
                        )),
                child: const Text('Saisir les cotes à la main'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
