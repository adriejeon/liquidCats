import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../game/liquid_cat_game.dart';

class GlassContainer extends Component with HasGameRef<LiquidCatGame> {
  GlassContainer();

  late final _GlassLayer _backgroundLayer;
  late final _GlassLayer _foregroundLayer;
  GlassWalls? _walls;
  ui.Rect _containerRect = ui.Rect.zero;
  ui.Rect get containerBounds => _containerRect;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _backgroundLayer = _GlassLayer(priority: -1, painter: _paintBackground);
    _foregroundLayer = _GlassLayer(priority: 100, painter: _paintForeground);

    await add(_backgroundLayer);
    await add(_foregroundLayer);
    _updateLayout(gameRef.size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateLayout(size);
  }

  void _updateLayout(Vector2 gameSize) {
    if (gameSize.isZero()) {
      return;
    }

    final width = gameSize.x * 0.65;
    final height = gameSize.y * 0.7;
    final left = (gameSize.x - width) / 2;
    final top = gameSize.y * 0.15;
    _containerRect = ui.Rect.fromLTWH(left, top, width, height);

    _backgroundLayer.updateLayout(_containerRect, gameSize);
    _foregroundLayer.updateLayout(_containerRect, gameSize);

    _walls ??= GlassWalls(containerRect: _containerRect);
    if (_walls!.isMounted) {
      _walls!.updateContainer(_containerRect);
    } else {
      add(_walls!);
    }
  }

  void _paintBackground(ui.Canvas canvas, ui.Rect rect) {
    final radius = ui.Radius.circular(rect.width * 0.12);
    final glassRect = ui.RRect.fromRectAndRadius(rect.deflate(6), radius);

    final innerSheenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(0.08);

    canvas.drawRRect(glassRect, innerSheenPaint);
  }

  void _paintForeground(ui.Canvas canvas, ui.Rect rect) {
    final radius = ui.Radius.circular(rect.width * 0.12);
    final outline = ui.RRect.fromRectAndRadius(rect, radius);

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(outline, outlinePaint);

    final highlightPath = ui.Path()
      ..moveTo(rect.left + rect.width * 0.12, rect.top + rect.height * 0.08)
      ..quadraticBezierTo(
        rect.left,
        rect.top + rect.height * 0.4,
        rect.left + rect.width * 0.15,
        rect.top + rect.height * 0.75,
      )
      ..lineTo(rect.left + rect.width * 0.2, rect.top + rect.height * 0.7)
      ..quadraticBezierTo(
        rect.left + rect.width * 0.08,
        rect.top + rect.height * 0.4,
        rect.left + rect.width * 0.22,
        rect.top + rect.height * 0.12,
      )
      ..close();

    final highlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(rect.left, rect.top),
        ui.Offset(rect.left + rect.width * 0.25, rect.bottom),
        [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.0)],
      );

    canvas.drawPath(highlightPath, highlightPaint);
  }
}

class _GlassLayer extends PositionComponent {
  _GlassLayer({required super.priority, required this.painter}) {
    anchor = Anchor.topLeft;
    position = Vector2.zero();
  }

  final void Function(ui.Canvas canvas, ui.Rect rect) painter;
  ui.Rect _rect = ui.Rect.zero;

  void updateLayout(ui.Rect rect, Vector2 gameSize) {
    _rect = rect;
    size = gameSize.clone();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (_rect.width == 0 || _rect.height == 0) {
      return;
    }
    painter(canvas, _rect);
  }
}

class GlassWalls extends BodyComponent<LiquidCatGame> {
  GlassWalls({required ui.Rect containerRect})
    : _containerRect = containerRect {
    renderBody = false;
  }

  ui.Rect _containerRect;
  static const double _wallThicknessFactor = 0.04;

  @override
  Body createBody() {
    final bodyDef = BodyDef()..type = BodyType.static;
    final body = world.createBody(bodyDef);
    _applyFixtures(body);
    return body;
  }

  void updateContainer(ui.Rect rect) {
    _containerRect = rect;
    final currentBody = body;
    if (currentBody == null) {
      return;
    }
    final fixtures = currentBody.fixtures.toList();
    for (final fixture in fixtures) {
      currentBody.destroyFixture(fixture);
    }
    _applyFixtures(currentBody);
  }

  void _applyFixtures(Body targetBody) {
    final wallThickness = _containerRect.width * _wallThicknessFactor;
    final bottomThickness = wallThickness * 0.9;
    final extendedHeight = _containerRect.height + wallThickness;

    _createBoxFixture(
      targetBody,
      width: _containerRect.width,
      height: bottomThickness,
      center: Vector2(
        _containerRect.center.dx,
        _containerRect.bottom + bottomThickness / 2,
      ),
    );

    _createBoxFixture(
      targetBody,
      width: wallThickness,
      height: extendedHeight,
      center: Vector2(
        _containerRect.left - wallThickness / 2,
        _containerRect.center.dy + wallThickness * 0.2,
      ),
    );

    _createBoxFixture(
      targetBody,
      width: wallThickness,
      height: extendedHeight,
      center: Vector2(
        _containerRect.right + wallThickness / 2,
        _containerRect.center.dy + wallThickness * 0.2,
      ),
    );
  }

  void _createBoxFixture(
    Body body, {
    required double width,
    required double height,
    required Vector2 center,
  }) {
    final shape = PolygonShape()..setAsBox(width / 2, height / 2, center, 0);

    final fixtureDef = FixtureDef(shape)
      ..friction = 0.6
      ..restitution = 0.1;

    body.createFixture(fixtureDef);
  }
}
