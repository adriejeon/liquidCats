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
  CatBody({
    required this.level,
    required Vector2 initialPosition,
    double? dropSpeed,
  }) : assert(level >= 1 && level <= 11, 'level must be within 1-11'),
       _initialPosition = initialPosition.clone(),
       _dropSpeed = dropSpeed;

  final int level;
  final Vector2 _initialPosition;
  final double? _dropSpeed;

  static const double _baseRadius = 20.0;
  static const double _radiusStep = 4.0;

  double get radius => _baseRadius + (level - 1) * _radiusStep;

  static double radiusForLevel(int level) {
    return _baseRadius + (level - 1) * _radiusStep;
  }

  late final Sprite _baseSprite;
  Sprite? _blinkSprite;
  SpriteComponent? _sprite;
  // bool _isSquashing = false;  // 더 이상 사용하지 않음
  ScaleEffect? _breathingEffect;
  bool _isMerging = false;
  bool _isRemoved = false;
  final Random _random = Random();
  Timer? _blinkTimer;
  Timer? _blinkHoldTimer;
  bool _isBlinking = false;
  bool _hasContacted = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    renderBody = false;

    final basePath = 'cat_${level.toString().padLeft(2, '0')}.png';
    _baseSprite = Sprite(await gameRef.images.load(basePath));

    if (_shouldBlink) {
      final blinkPath = 'cat_${level.toString().padLeft(2, '0')}_blink.png';
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

    // ★★★ [초기 발사] ★★★
    // 매 프레임(update)마다가 아니라, 태어날 때 '딱 한 번' 강하게 밀어줍니다.
    // 이것만 있으면 충분히 빠릅니다.
    body.linearVelocity = Vector2(0, 2000.0);
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density =
          5.0 // [변경] 1.0은 너무 가벼워서 뜹니다. 5.0으로 무게감 줌.
      ..restitution =
          0.0 // 튀지 않음
      ..friction = 0.5; // 적당한 마찰력

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = _initialPosition
      ..fixedRotation = false
      ..bullet = true
      // ★★★ [핵심] 공기 저항 0.0 (낙하산 제거) ★★★
      // 이 값이 0이어야 중력 가속도를 제대로 받아 빨라집니다.
      ..linearDamping = 0.0
      ..angularDamping = 5.0
      ..userData = this;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);

    // 바닥이나 다른 고양이에 닿는 순간!
    if (!_hasContacted) {
      _hasContacted = true;

      // [변신] 이제 얌전해져라!
      // 저항을 높여서 그 자리에 멈추게 합니다.
      body.linearDamping = 20.0;
      body.angularDamping = 20.0;

      // 마찰력을 높여서 미끄러짐 방지
      body.fixtures.first.friction = 1.0;
    }

    if (other is CatBody) {
      gameRef.queueMerge(this, other);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // ❌ 중요: 여기에 있던 'body.linearVelocity = ...' 코드를 전부 지웠습니다!
    // update에서 속도를 건드리면 물리 엔진과 충돌하여 버벅거립니다.

    // (숨쉬기 효과 등 비주얼 관련 코드만 남김)
    _applyAnimationLogic(dt);
  }

  void _applyAnimationLogic(double dt) {
    final velocity = body.linearVelocity.length;
    final isAtRest = velocity < 0.5;

    // 정지 상태일 때만 숨쉬기 효과 적용
    if (_shouldBreathe) {
      if (isAtRest) {
        if (_breathingEffect == null ||
            (_breathingEffect?.isRemoved ?? false)) {
          _startIdleBreathing();
        }
      } else {
        if (_breathingEffect != null) {
          _stopIdleBreathing();
        }
      }
    }

    if (_shouldBlink) {
      _blinkTimer?.update(dt);
      _blinkHoldTimer?.update(dt);
    }
  }

  // 충돌 시 찌그러지는 효과 제거됨 (꾸깃꾸깃한 효과 방지)
  // void _playSquashEffect() {
  //   final sprite = _sprite;
  //   if (sprite == null || _isSquashing) {
  //     return;
  //   }

  //   _isSquashing = true;
  //   final squashSequence = SequenceEffect([
  //     ScaleEffect.to(
  //       Vector2(1.2, 0.8),
  //       EffectController(duration: 0.08, curve: Curves.easeOut),
  //     ),
  //     ScaleEffect.to(
  //       Vector2(0.9, 1.1),
  //       EffectController(duration: 0.1, curve: Curves.easeOut),
  //     ),
  //     ScaleEffect.to(
  //       Vector2.all(1.0),
  //       EffectController(duration: 0.1, curve: Curves.easeOutBack),
  //     ),
  //   ], onComplete: () => _isSquashing = false);

  //   sprite.add(squashSequence);
  // }

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

    // 아주 미세한 숨쉬기 효과 (1% 크기 변화)
    final effect = ScaleEffect.to(
      Vector2.all(1.01),
      EffectController(
        duration: 2.0,
        reverseDuration: 2.0,
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

  // 더이상 사용하지 않음 - update()에서 직접 처리
  // void _updateIdleBreathing() {
  //   final velocity = body.linearVelocity.length;
  //   final isAtRest = velocity < 0.5;

  //   if (isAtRest) {
  //     if (_breathingEffect != null) {
  //       _stopIdleBreathing();
  //     }
  //   } else {
  //     final isIdle = velocity < 2.0;
  //     if (isIdle) {
  //       if (_breathingEffect == null ||
  //           (_breathingEffect?.isRemoved ?? false)) {
  //         _startIdleBreathing();
  //       }
  //     } else {
  //       if (_breathingEffect != null) {
  //         _stopIdleBreathing();
  //       }
  //     }
  //   }
  // }

  Vector2 get worldCenter {
    if (!isMounted) {
      return _initialPosition.clone();
    }
    try {
      final center = body.worldCenter;
      // NaN이나 Infinity 체크
      if (center.x.isFinite && center.y.isFinite) {
        return center.clone();
      }
    } catch (e) {
      // Body가 제거되었거나 접근할 수 없는 경우
    }
    return _initialPosition.clone();
  }

  bool get isMerging => _isMerging;

  void markMerging() {
    _isMerging = true;
  }

  @override
  bool get isRemoved => _isRemoved;

  @override
  void onRemove() {
    _isRemoved = true;
    super.onRemove();
  }
}
