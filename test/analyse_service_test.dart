// Tests de l'envoi de la photo, avec un faux serveur (pas de réseau, pas d'IA).

import 'dart:convert';
import 'dart:typed_data';

import 'package:demo5/services/analyse_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final image = Uint8List.fromList([1, 2, 3]);

Future<Object> appeler(MockClient serveur, {String adresse = 'http://serveur:8000'}) async {
  try {
    return await analyserPhoto(
        adresseServeur: adresse, image: image, nomFichier: 'dessin.jpg', client: serveur);
  } on ErreurAnalyse catch (e) {
    return e;
  }
}

http.Response json(Object corps, int code) => http.Response.bytes(
    utf8.encode(jsonEncode(corps)), code,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('succès : photo envoyée en multipart, JSON converti en Piece', () async {
    late http.Request recue;
    final serveur = MockClient((req) async {
      recue = req;
      return json({
        'brut': {'diametre': 60, 'longueur': 100},
        'points': [
          {'nom': 'P1', 'x': 0, 'z': 0},
          {'nom': 'P2', 'x': 44, 'z': 0},
        ],
        'gorges': [],
        'filetages': [],
        'incertitudes': ['Diamètre du brut non coté, 60 supposé'],
      }, 200);
    });

    final piece = await appeler(serveur);

    expect(recue.url.toString(), 'http://serveur:8000/analyser');
    expect(recue.headers['content-type'], startsWith('multipart/form-data'));
    expect(recue.body, contains('name="photo"; filename="dessin.jpg"'));
    expect(piece, isNot(isA<ErreurAnalyse>()));
  });

  test('pièce non tournée : message du serveur affiché', () async {
    final serveur = MockClient((_) async =>
        json({'erreur': 'Ce dessin n\'est pas une pièce tournée : plaque.'}, 422));
    final r = await appeler(serveur);
    expect(r, isA<ErreurAnalyse>());
    expect((r as ErreurAnalyse).message, contains('pas une pièce tournée'));
  });

  test('erreur serveur sans JSON', () async {
    final serveur = MockClient((_) async => http.Response('oups', 500));
    final r = await appeler(serveur) as ErreurAnalyse;
    expect(r.message, contains('code 500'));
  });

  test('serveur injoignable', () async {
    final serveur = MockClient((_) async => throw http.ClientException('Connection refused'));
    final r = await appeler(serveur) as ErreurAnalyse;
    expect(r.message, contains('Serveur injoignable'));
  });

  test('adresse invalide', () async {
    final serveur = MockClient((_) async => http.Response('', 200));
    final r = await appeler(serveur, adresse: '192.168.1.20') as ErreurAnalyse;
    expect(r.message, contains('Adresse du serveur invalide'));
  });

  test('réponse illisible', () async {
    final serveur = MockClient((_) async => http.Response('{"brut": 3}', 200));
    final r = await appeler(serveur) as ErreurAnalyse;
    expect(r.message, contains('illisible'));
  });
}
