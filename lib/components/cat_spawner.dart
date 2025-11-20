import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../game/liquid_cat_game.dart';
import 'cat_body.dart';

class CatSpawner extends PositionComponent
    with HasGameRef<LiquidCatGame>, DragCallbacks {
  CatSpawner();

  final math.Random _random = math.Random();
  int? _nextLevel;
  Vector2? _currentPosition;
  bool _canSpawn = true;
  double _containerLeft = 0;
  double _containerRight = 0;
  double _spawnY = 0;
  late final SpriteComponent _previewCat;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    priority = 50;
    _previewCat = SpriteComponent(
      anchor: Anchor.center,
      position: Vector2.zero(),
      size: Vector2.zero(),
      priority: 1,
    );
    await add(_previewCat);
    _updateSpawnBounds();
    await _prepareNextCat();
  }

  void _updateSpawnBounds() {
    final container = gameRef.glassContainer.containerBounds;
    _containerLeft = container.left;
    _containerRight = container.right;
    _spawnY = container.top + 80;

    final centerX = (container.left + container.right) / 2;
    _currentPosition = Vector2(centerX, _spawnY);
    position = _currentPosition!;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateSpawnBounds();
  }

  Future<void> _prepareNextCat() async {
    _nextLevel = _random.nextInt(3) + 1;
    final radius = CatBody.radiusForLevel(_nextLevel!);
    size = Vector2.all(radius * 2);
    final spritePath =
        'images/cat_${_nextLevel!.toString().padLeft(2, '0')}.png';
    final spriteImage = await gameRef.images.load(spritePath);
    _previewCat
      ..sprite = Sprite(spriteImage)
      ..size = size.clone()
      ..position = Vector2.zero();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_canSpawn || _nextLevel == null) return;

    final newX = event.canvasEndPosition.x;
    final radius = CatBody.radiusForLevel(_nextLevel!);
    final clampedX = newX.clamp(
      _containerLeft + radius,
      _containerRight - radius,
    );

    _currentPosition = Vector2(clampedX, _spawnY);
    position = _currentPosition!;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!_canSpawn || _nextLevel == null || _currentPosition == null) return;

    _spawnCat();
  }

  void _spawnCat() {
    _canSpawn = false;
    final level = _nextLevel!;
    final spawnPos = _currentPosition!.clone();

    gameRef.spawnCat(level, spawnPos);

    _previewCat..sprite = null;
    _nextLevel = null;

    Future.delayed(const Duration(milliseconds: 500), () async {
      _canSpawn = true;
      await _prepareNextCat();
      _updateSpawnBounds();
    });
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);

    if (_nextLevel == null || _currentPosition == null) return;

    final radius = size.x / 2;

    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(radius, radius), radius + 10, glowPaint);

    _drawGuideLine(canvas);
  }

  void _drawGuideLine(ui.Canvas canvas) {
    if (_currentPosition == null) return;

    final container = gameRef.glassContainer.containerBounds;
    final startY = _spawnY + size.y / 2 + 10;
    final endY = container.bottom;

    final linePaint = Paint()
      ..color = Colors.orange.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double currentY = startY;

    while (currentY < endY) {
      canvas.drawLine(
        Offset(size.x / 2, currentY - _spawnY + size.y / 2),
        Offset(
          size.x / 2,
          (currentY + dashWidth).clamp(startY, endY) - _spawnY + size.y / 2,
        ),
        linePaint,
      );
      currentY += dashWidth + dashSpace;
    }
  }
}
