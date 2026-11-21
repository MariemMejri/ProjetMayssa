import 'package:flutter/material.dart';

import 'ecrans/ecran_photo.dart';

void main() => runApp(const AppGcode());

class AppGcode extends StatelessWidget {
  const AppGcode({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo → G-code',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.blueGrey,
          brightness: Brightness.dark,
          useMaterial3: true),
      home: const EcranPhoto(),
    );
  }
}
