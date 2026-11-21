// Écran G-code : programme, rappel de sécurité permanent, copier / partager.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class EcranGcode extends StatelessWidget {
  final String gcode;
  final String nomFichier;

  const EcranGcode({super.key, required this.gcode, required this.nomFichier});

  Future<void> _copier(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: gcode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('G-code copié dans le presse-papiers')));
  }

  Future<void> _partager(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/$nomFichier');
      await fichier.writeAsString(gcode);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(fichier.path, mimeType: 'text/plain')],
        subject: nomFichier,
      ));
    } catch (e) {
      messager.showSnackBar(SnackBar(content: Text('Partage impossible : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(nomFichier),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copier',
            onPressed: () => _copier(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Rappel permanent (ne défile pas avec le programme).
          Container(
            width: double.infinity,
            color: Colors.amber.shade200,
            padding: const EdgeInsets.all(12),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.black87),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Programme NON vérifié. Simuler d\'abord (NC Viewer, CIMCO…), '
                    'puis sur la machine : marche à vide, bloc par bloc, rapide réduit.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                gcode,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Partager .nc'),
                  onPressed: () => _partager(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
