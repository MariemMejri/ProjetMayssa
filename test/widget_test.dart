// Test de l'appli : l'exemple se charge, la génération est refusée tant que
// l'incertitude n'est pas cochée, puis le G-code s'affiche.

import 'package:demo5/ecrans/ecran_piece.dart';
import 'package:demo5/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Écran photo -> saisie à la main', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AppGcode());
    await tester.pumpAndSettle();

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);

    await tester.tap(find.text('Saisir les cotes à la main'));
    await tester.pumpAndSettle();
    expect(find.text('Cotes de la pièce'), findsOneWidget);
  });

  testWidgets('Exemple -> refus -> cocher -> G-code', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EcranPiece()));

    // L'incertitude de l'exemple est affichée, non cochée.
    expect(find.text('Diamètre du brut non coté, 60 supposé'), findsOneWidget);

    // Générer sans cocher : refus.
    await tester.tap(find.text('Générer le G-code'));
    await tester.pumpAndSettle();
    expect(find.text('Génération refusée :'), findsOneWidget);
    expect(find.textContaining('Incertitude non confirmée'), findsOneWidget);

    // Cocher puis générer : écran G-code.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Générer le G-code'));
    await tester.pumpAndSettle();

    expect(find.text('O0001.nc'), findsOneWidget);
    expect(find.textContaining('G71 P10 Q20'), findsOneWidget);
    expect(find.textContaining('Programme NON vérifié'), findsOneWidget);

    // Retour pour modifier.
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Cotes de la pièce'), findsOneWidget);
  });
}
