import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/cat_body.dart';
import '../components/cat_spawner.dart';
import '../components/glass_container.dart';

class LiquidCatGame extends Forge2DGame {
  // [1] 중력 설정: 충분히 빠르게 떨어지도록 20,000으로 설정
  LiquidCatGame() : super(gravity: Vector2(0, 20000.0), zoom: 1.0);
  late final GlassContainer _glassContainer;
  late final CatSpawner _catSpawner;
  final List<_MergeRequest> _mergeQueue = [];

  GlassContainer get glassContainer => _glassContainer;

  int score = 0;

  @override
  Color backgroundColor() => const Color(0xFFF4EFE6);

  @override
  Future<void> onLoad() async {
    // super.onLoad()는 내부적으로 world를 초기화합니다.
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.topLeft;

    _glassContainer = GlassContainer();
    await add(_glassContainer);

    _catSpawner = CatSpawner();
    await add(_catSpawner);
  }

  @override
  void update(double dt) {
    // [속도 증가] for loop로 물리 엔진을 3번 더 실행하여 4배 속도
    // 1번 기본 + 3번 추가 = 총 4번 실행 = 4배 속도
    for (int i = 0; i < 3; i++) {
      world.physicsWorld.stepDt(dt);
      _processMergeQueue(); // 중간중간 합체 로직도 실행
    }

    // 마지막으로 원래의 update 호출 (화면 그리기)
    super.update(dt);
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
