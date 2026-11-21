// Envoie la photo au serveur et renvoie la Piece lue par l'IA.
// Toutes les erreurs deviennent une ErreurAnalyse avec un message en français.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../gcode/piece.dart';

class ErreurAnalyse implements Exception {
  final String message;
  const ErreurAnalyse(this.message);

  @override
  String toString() => message;
}

MediaType _typeImage(String nomFichier) {
  final ext = nomFichier.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => MediaType('image', 'png'),
    'webp' => MediaType('image', 'webp'),
    'heic' => MediaType('image', 'heic'),
    'heif' => MediaType('image', 'heif'),
    _ => MediaType('image', 'jpeg'),
  };
}

/// [client] permet de remplacer le réseau dans les tests.
Future<Piece> analyserPhoto({
  required String adresseServeur,
  required Uint8List image,
  required String nomFichier,
  http.Client? client,
  Duration delai = const Duration(seconds: 90),
}) async {
  final Uri uri;
  try {
    uri = Uri.parse(adresseServeur.trim()).resolve('/analyser');
    if (!uri.hasScheme || uri.host.isEmpty) throw const FormatException();
  } on FormatException {
    throw ErreurAnalyse('Adresse du serveur invalide : « $adresseServeur »');
  }

  final requete = http.MultipartRequest('POST', uri)
    ..files.add(http.MultipartFile.fromBytes('photo', image,
        filename: nomFichier, contentType: _typeImage(nomFichier)));

  final c = client ?? http.Client();
  final http.Response reponse;
  try {
    reponse = await http.Response.fromStream(await c.send(requete).timeout(delai));
  } on TimeoutException {
    throw const ErreurAnalyse('Le serveur ne répond pas (délai dépassé). Réessaie.');
  } on http.ClientException catch (e) {
    throw ErreurAnalyse('Serveur injoignable à $adresseServeur. Vérifie qu\'il est '
        'lancé et que le téléphone est sur le même Wi-Fi.\n(${e.message})');
  } finally {
    if (client == null) c.close();
  }

  final corps = utf8.decode(reponse.bodyBytes);

  if (reponse.statusCode != 200) {
    String message;
    try {
      message = (jsonDecode(corps) as Map)['erreur'] as String;
    } catch (_) {
      message = 'Erreur du serveur (code ${reponse.statusCode}).';
    }
    throw ErreurAnalyse(message);
  }

  try {
    return Piece.fromJson(jsonDecode(corps) as Map<String, dynamic>);
  } catch (e) {
    throw ErreurAnalyse('Réponse du serveur illisible : $e');
  }
}
