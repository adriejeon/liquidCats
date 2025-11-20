import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/liquid_cat_game.dart';
import 'overlays/evolution_bar.dart';

final LiquidCatGame _game = LiquidCatGame();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiquidCatApp());
}

class LiquidCatApp extends StatelessWidget {
  const LiquidCatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Cat Merge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5F4B3A)),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: GameWidget(
          game: _game,
          overlayBuilderMap: {
            'evolutionBar': (context, game) => const EvolutionBar(),
          },
          initialActiveOverlays: const ['evolutionBar'],
        ),
      ),
    );
  }
}
