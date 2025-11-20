import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/timer.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/animation.dart';

import '../game/liquid_cat_game.dart';

class CatBody extends BodyComponent<LiquidCatGame>
    with ContactCallbacks, HasGameRef<LiquidCatGame> {
  CatBody({required this.level, required Vector2 initialPosition})
    : assert(level >= 1 && level <= 11, 'level must be within 1-11'),
      _initialPosition = initialPosition.clone();

  final int level;
  final Vector2 _initialPosition;

  static const double _baseRadius = 18;
  static const double _radiusStep = 4;

  double get radius => _baseRadius + (level - 1) * _radiusStep;

  static double radiusForLevel(int level) {
    return _baseRadius + (level - 1) * _radiusStep;
  }

  late final Sprite _baseSprite;
  Sprite? _blinkSprite;
  SpriteComponent? _sprite;
  bool _isSquashing = false;
  ScaleEffect? _breathingEffect;
  bool _isMerging = false;
  bool _isRemoved = false;
  final Random _random = Random();
  Timer? _blinkTimer;
  Timer? _blinkHoldTimer;
  bool _isBlinking = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    renderBody = false;

    final basePath = 'images/cat_${level.toString().padLeft(2, '0')}.png';
    _baseSprite = Sprite(await gameRef.images.load(basePath));

    if (_shouldBlink) {
      final blinkPath =
          'images/cat_${level.toString().padLeft(2, '0')}_blink.png';
      _blinkSprite = Sprite(await gameRef.images.load(blinkPath));
    }

    _sprite = SpriteComponent(
      sprite: _baseSprite,
      size: Vector2.all(radius * 2),
      anchor: Anchor.center,
      priority: 0,
    );

    add(_sprite!);
    _applyIdleEffects();
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density = 0.8
      ..friction = 0.25
      ..restitution = 0.35;

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = _initialPosition
      ..linearDamping = 0.2
      ..angularDamping = 2.0
      ..userData = this;

    final body = world.createBody(bodyDef)..createFixture(fixtureDef);
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);
    _playSquashEffect();

    if (other is CatBody) {
      gameRef.queueMerge(this, other);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_shouldBreathe) {
      _updateIdleBreathing();
    }
    if (_shouldBlink) {
      _blinkTimer?.update(dt);
      _blinkHoldTimer?.update(dt);
    }
  }

  void _playSquashEffect() {
    final sprite = _sprite;
    if (sprite == null || _isSquashing) {
      return;
    }

    _isSquashing = true;
    final squashSequence = SequenceEffect([
      ScaleEffect.to(
        Vector2(1.2, 0.8),
        EffectController(duration: 0.08, curve: Curves.easeOut),
      ),
      ScaleEffect.to(
        Vector2(0.9, 1.1),
        EffectController(duration: 0.1, curve: Curves.easeOut),
      ),
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.1, curve: Curves.easeOutBack),
      ),
    ], onComplete: () => _isSquashing = false);

    sprite.add(squashSequence);
  }

  bool get _shouldBlink => level == 9 || level == 10;
  bool get _shouldBreathe => level <= 8 || !_shouldBlink;

  void _applyIdleEffects() {
    if (_shouldBlink) {
      _startBlinkLoop();
    } else if (_shouldBreathe) {
      _startIdleBreathing();
    }
  }

  void _startBlinkLoop() {
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    final nextDelay = 1.5 + _random.nextDouble() * 2.5;
    _blinkTimer = Timer(
      nextDelay,
      onTick: () {
        _triggerBlink();
        _scheduleNextBlink();
      },
    )..start();
  }

  void _triggerBlink() {
    final sprite = _sprite;
    if (sprite == null || _blinkSprite == null || _isBlinking) {
      return;
    }

    _isBlinking = true;
    sprite.sprite = _blinkSprite;
    _blinkHoldTimer = Timer(
      0.12,
      onTick: () {
        sprite.sprite = _baseSprite;
        _isBlinking = false;
      },
    )..start();
  }

  void _startIdleBreathing() {
    if (_sprite == null || _breathingEffect != null) {
      return;
    }

    final effect = ScaleEffect.to(
      Vector2.all(1.02),
      EffectController(
        duration: 1.4,
        reverseDuration: 1.4,
        infinite: true,
        curve: Curves.easeInOut,
      ),
    );
    _breathingEffect = effect;
    _sprite!.add(effect);
  }

  void _stopIdleBreathing() {
    _breathingEffect?.removeFromParent();
    _breathingEffect = null;
    _sprite?.scale = Vector2.all(1.0);
  }

  void _updateIdleBreathing() {
    final currentBody = body;
    if (currentBody == null) {
      return;
    }

    final isIdle = currentBody.linearVelocity.length2 < 5.0;
    if (isIdle) {
      if (_breathingEffect == null || (_breathingEffect?.isRemoved ?? false)) {
        _startIdleBreathing();
      }
    } else {
      if (_breathingEffect != null) {
        _stopIdleBreathing();
      }
    }
  }

  Vector2 get worldCenter {
    final currentBody = body;
    if (currentBody == null) {
      return _initialPosition.clone();
    }
    return currentBody.worldCenter.clone();
  }

  bool get isMerging => _isMerging;

  void markMerging() {
    _isMerging = true;
  }

  bool get isRemoved => _isRemoved;

  @override
  void onRemove() {
    _isRemoved = true;
    super.onRemove();
  }
}
