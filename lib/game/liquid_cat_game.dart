import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/cat_body.dart';
import '../components/cat_spawner.dart';
import '../components/glass_container.dart';

class LiquidCatGame extends Forge2DGame {
  // [핵심 변경] 중력을 1000 ~ 2000 사이로 아주 낮춥니다.
  // "쌓여있을 때의 안정성"을 위해서입니다.
LiquidCatGame() : super(gravity: Vector2(0, 1000.0), zoom: 1.0);
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