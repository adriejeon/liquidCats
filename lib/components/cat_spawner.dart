import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../game/liquid_cat_game.dart';
import 'cat_body.dart';

class CatSpawner extends PositionComponent
    with HasGameRef<LiquidCatGame>, DragCallbacks, TapCallbacks {
  CatSpawner();

  final math.Random _random = math.Random();
  int? _nextLevel;
  Vector2? _currentPosition;
  bool _canSpawn = true;
  bool _isDragging = false;
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

    // 컨테이너 상단에 고양이 위치
    // 고양이 하단이 컨테이너 상단에 닿도록 하려면 중심이 반지름만큼 아래에 있어야 함
    if (_nextLevel != null) {
      final radius = CatBody.radiusForLevel(_nextLevel!);
      _spawnY = container.top + radius;
    } else {
      // 기본값 (나중에 업데이트됨)
      _spawnY = container.top + 20;
    }

    // 화면 중앙 X 좌표 계산 (컨테이너 중앙이 아니라 화면 전체 중앙)
    final gameSize = gameRef.size;
    final centerX = gameSize.x / 1.8;
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
    final spritePath = 'cat_${_nextLevel!.toString().padLeft(2, '0')}.png';
    final spriteImage = await gameRef.images.load(spritePath);
    _previewCat
      ..sprite = Sprite(spriteImage)
      ..size = size.clone()
      ..position = Vector2.zero();

    // 고양이 크기에 맞춰 위치 업데이트
    _updateSpawnBounds();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragging = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
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
    super.onDragEnd(event);
    _isDragging = false;
    if (!_canSpawn || _nextLevel == null || _currentPosition == null) return;
    _spawnCat();
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (!_canSpawn || _nextLevel == null || _currentPosition == null) return;
    if (_isDragging) return;

    _spawnCat();
  }

  void _spawnCat() {
    _canSpawn = false;
    final level = _nextLevel!;
    final spawnPos = _currentPosition!.clone();

    gameRef.spawnCat(level, spawnPos, dropSpeed: 0.5);

    _previewCat.sprite = null;
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
    // anchor = Anchor.center이므로 로컬 좌표계의 중심은 (0, 0)
    // 후광을 중심에 그리기 위해 (0, 0) 사용
    canvas.drawCircle(Offset.zero, radius + 10, glowPaint);

    _drawGuideLine(canvas);
  }

  void _drawGuideLine(ui.Canvas canvas) {
    if (_currentPosition == null) return;

    final container = gameRef.glassContainer.containerBounds;
    // 스폰어 위치에서 컨테이너 바닥까지의 가이드라인
    // anchor = Anchor.center이므로 로컬 좌표계의 중심은 (0, 0)
    // 아래쪽으로 그리므로 startY는 0부터 시작
    final startY = 0.0;
    final endY = container.bottom - _spawnY + size.y / 2;

    final linePaint = Paint()
      ..color = Colors.orange.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double currentY = startY;

    while (currentY < endY) {
      canvas.drawLine(
        Offset(0, currentY), // 중심 X는 0
        Offset(0, (currentY + dashWidth).clamp(startY, endY)),
        linePaint,
      );
      currentY += dashWidth + dashSpace;
    }
  }
}
