// Adresse du serveur d'analyse, modifiable dans l'appli et enregistrée.
// Par défaut : 10.0.2.2 = le PC vu depuis l'émulateur Android.
// Sur un vrai téléphone : l'IP du PC sur le Wi-Fi, ex. http://192.168.1.20:8000
// (ou à la compilation : flutter run --dart-define=SERVEUR=http://...).

import 'package:shared_preferences/shared_preferences.dart';

const String adresseServeurParDefaut =
    String.fromEnvironment('SERVEUR', defaultValue: 'http://10.0.2.2:8000');

const String _cle = 'adresse_serveur';

Future<String> lireAdresseServeur() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_cle) ?? adresseServeurParDefaut;
}

Future<void> enregistrerAdresseServeur(String adresse) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cle, adresse.trim());
}
