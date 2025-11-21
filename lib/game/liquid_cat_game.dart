import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/cat_body.dart';
import '../components/cat_spawner.dart';
import '../components/glass_container.dart';

class LiquidCatGame extends Forge2DGame {
  // [수정] 중력을 3,000으로 설정합니다.
  // 너무 높으면(5만, 10만) 뚫고 지나가고, 너무 낮으면 느립니다.
  // 3,000 ~ 5,000 사이가 황금비율입니다.
  LiquidCatGame() : super(gravity: Vector2(0, 3000.0), zoom: 1.0);
  late final GlassContainer _glassContainer;
  late final CatSpawner _catSpawner;
  final List<_MergeRequest> _mergeQueue = [];

  GlassContainer get glassContainer => _glassContainer;

  int score = 0;

  @override
  Color backgroundColor() => const Color(0xFFF4EFE6);

  @override
  Future<void> onLoad() async {
    // [핵심 수정] 정밀도 설정을 여기서 합니다.
    // world.physicsWorld... 가 아니라 게임 클래스의 속성을 직접 변경합니다.
    // velocityIterations = 20; // 충돌 계산 정밀도 높임 (떨림 방지)
    // positionIterations = 10; // 위치 계산 정밀도 높임 (겹침 방지)

    await super.onLoad();

    camera.viewfinder.anchor = Anchor.topLeft;

    _glassContainer = GlassContainer();
    await add(_glassContainer);

    _catSpawner = CatSpawner();
    await add(_catSpawner);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _processMergeQueue();
  }

  void spawnCat(int level, Vector2 position, {double? dropSpeed}) {
    add(CatBody(level: level, initialPosition: position, dropSpeed: dropSpeed));
  }

  void queueMerge(CatBody a, CatBody b) {
    if (a == b || a.level != b.level) return;
    if (a.isRemoved || b.isRemoved || a.isMerging || b.isMerging) return;

    if (a.level >= 11) {
      a.markMerging();
      b.markMerging();
      _removeCats(a, b);
      _addScore(5000);
      return;
    }

    _mergeQueue.add(_MergeRequest(a, b));
  }

  void _processMergeQueue() {
    if (_mergeQueue.isEmpty) return;
    final pending = List<_MergeRequest>.from(_mergeQueue);
    _mergeQueue.clear();
    for (final request in pending) {
      _resolveMerge(request);
    }
  }

  void _resolveMerge(_MergeRequest request) {
    final a = request.a;
    final b = request.b;

    if (!a.isMounted || !b.isMounted) return;
    if (a.isRemoved || b.isRemoved || a.isMerging || b.isMerging) return;
    if (a.level != b.level) return;

    // update()는 World가 잠겨있지 않을 때 호출되므로 안전하게 처리 가능
    // 하지만 안전을 위해 try-catch로 감싸기
    try {
      if (a.level >= 11) {
        a.markMerging();
        b.markMerging();
        _removeCats(a, b);
        _addScore(5000);
        return;
      }

      a.markMerging();
      b.markMerging();

      final midpoint = (a.worldCenter + b.worldCenter)..scale(0.5);

      _removeCats(a, b);
      spawnCat(a.level + 1, midpoint);
      _addScore((a.level + 1) * 120);
    } catch (e) {
      // World가 잠겨있거나 Body가 제거된 경우 다음 프레임에 다시 시도
      _mergeQueue.add(request);
    }
  }

  void _removeCats(CatBody a, CatBody b) {
    a.removeFromParent();
    b.removeFromParent();
  }

  void _addScore(int amount) {
    score += amount;
  }
}

class _MergeRequest {
  _MergeRequest(this.a, this.b);
  final CatBody a;
  final CatBody b;
}
