import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import 'components.dart';
import 'models.dart';

typedef AddScore = void Function(int value);
typedef Fail = void Function();

abstract class GameScene {
  GameScene({required this.world, required this.player, required this.rng, required this.addScore, required this.fail});

  final World world;
  final DotPlayerComponent player;
  final Random rng;
  final AddScore addScore;
  final Fail fail;

  Future<void> setup();
  void update(double dt) {}
  void onAction() {}
  String get mapName;
}

class HerbScene extends GameScene {
  HerbScene({required super.world, required super.player, required super.rng, required super.addScore, required super.fail});

  @override
  String get mapName => 'herb';

  final _items = <ItemComponent>[];
  final _hazards = <ItemComponent>[];

  @override
  Future<void> setup() async {
    for (int i = 0; i < 9; i++) {
      final c = ItemComponent(color: const Color(0xFF7DE37B), position: Vector2(40 + rng.nextDouble() * 360, 30 + rng.nextDouble() * 180));
      _items.add(c);
      world.add(c);
    }
    for (int i = 0; i < 5; i++) {
      final h = ItemComponent(color: const Color(0xFFE07070), position: Vector2(40 + rng.nextDouble() * 360, 30 + rng.nextDouble() * 180));
      _hazards.add(h);
      world.add(h);
    }
  }

  @override
  void update(double dt) {
    for (final c in List<ItemComponent>.from(_items)) {
      if (c.position.distanceTo(player.position) < 16) {
        addScore(2);
        c.removeFromParent();
        _items.remove(c);
      }
    }
    for (final h in _hazards) {
      if (h.position.distanceTo(player.position) < 14) {
        fail();
      }
    }
  }
}

class SmithScene extends GameScene {
  SmithScene({required super.world, required super.player, required super.rng, required super.addScore, required super.fail});

  @override
  String get mapName => 'smith';

  double meter = 0.3;
  bool forward = true;

  @override
  Future<void> setup() async {}

  @override
  void update(double dt) {
    meter += (forward ? 1 : -1) * dt * 0.9;
    if (meter >= 1) {
      meter = 1;
      forward = false;
    }
    if (meter <= 0) {
      meter = 0;
      forward = true;
    }
  }

  @override
  void onAction() {
    final d = (meter - 0.5).abs();
    if (d < 0.06) {
      addScore(4);
    } else if (d < 0.14) {
      addScore(2);
    } else {
      fail();
    }
  }
}

class HagglingScene extends GameScene {
  HagglingScene({required super.world, required super.player, required super.rng, required super.addScore, required super.fail});

  @override
  String get mapName => 'haggling';

  double cursor = 0.1;
  bool forward = true;

  @override
  Future<void> setup() async {}

  @override
  void update(double dt) {
    cursor += (forward ? 1 : -1) * dt * 1.1;
    if (cursor >= 1) {
      cursor = 1;
      forward = false;
    }
    if (cursor <= 0) {
      cursor = 0;
      forward = true;
    }
  }

  @override
  void onAction() {
    final d = (cursor - 0.55).abs();
    if (d < 0.07) {
      addScore(4);
    } else if (d < 0.14) {
      addScore(2);
    } else {
      fail();
    }
  }
}

class CourierScene extends HerbScene {
  CourierScene({required super.world, required super.player, required super.rng, required super.addScore, required super.fail});
  @override
  String get mapName => 'courier';
}

class DanceScene extends GameScene {
  DanceScene({required super.world, required super.player, required super.rng, required super.addScore, required super.fail});
  @override
  String get mapName => 'dance';
  int need = 0;

  @override
  Future<void> setup() async {
    need = rng.nextInt(4);
  }

  @override
  void onAction() {
    final tap = rng.nextInt(4);
    if (tap == need) {
      addScore(3);
    } else {
      fail();
    }
    need = rng.nextInt(4);
  }
}

class GardenScene extends HerbScene {
  GardenScene({required super.world, required super.player, required super.rng, required super.addScore, required super.fail});
  @override
  String get mapName => 'garden';
}

Particle quickPurpleBurst(Random rng, Vector2 pos) {
  return Particle.generate(
    count: 12,
    lifespan: 0.4,
    generator: (_) => AcceleratedParticle(
      acceleration: Vector2(0, 24),
      speed: Vector2((rng.nextDouble() - 0.5) * 120, -70 - rng.nextDouble() * 60),
      position: pos.clone(),
      child: CircleParticle(radius: 2 + rng.nextDouble() * 2, paint: Paint()..color = const Color(0xCCB38CFF)),
    ),
  );
}
