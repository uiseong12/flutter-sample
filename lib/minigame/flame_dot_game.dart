import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

enum FlameMode { herb, smith, haggling, courier, dance, garden }

class DotFlameGame extends FlameGame with HasCollisionDetection {
  DotFlameGame({
    required this.mode,
    required this.onTick,
    required this.onScore,
    required this.onCombo,
    required this.onFail,
    required this.onDone,
    this.durationSec = 20,
  });

  final FlameMode mode;
  final void Function(int secLeft) onTick;
  final void Function(int score) onScore;
  final void Function(int combo) onCombo;
  final VoidCallback onFail;
  final void Function(int finalScore, int finalCombo) onDone;
  final int durationSec;

  late final World _world;
  late final DotPlayer _player;
  late final JoystickComponent _joystick;

  final Random _rng = Random();
  final List<PositionComponent> _targets = [];
  final List<PositionComponent> _hazards = [];

  double _timer = 0;
  int _score = 0;
  int _combo = 0;

  double _smithMeter = 0.3;
  bool _smithForward = true;
  double _marketCursor = 0.1;
  bool _marketForward = true;
  int _danceNeed = 0;

  @override
  Color backgroundColor() => const Color(0xFF15131D);

  @override
  Future<void> onLoad() async {
    _world = World();
    camera = CameraComponent.withFixedResolution(world: _world, width: 448, height: 256);
    await addAll([camera, _world]);

    _buildTileMap();
    await _spawnActors();

    final knob = CircleComponent(radius: 22, paint: Paint()..color = const Color(0xAAE9D7A1));
    final bg = CircleComponent(radius: 38, paint: Paint()..color = const Color(0x664C3A2A));
    _joystick = JoystickComponent(knob: knob, background: bg, margin: const EdgeInsets.only(left: 20, bottom: 20));
    camera.viewport.add(_joystick);

    camera.viewport.add(
      HudButtonComponent(
        button: RectangleComponent(
          size: Vector2(62, 62),
          paint: Paint()..color = const Color(0xAA7E67FF),
          children: [TextComponent(text: '액션', anchor: Anchor.center, position: Vector2(31, 31), textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 12)))],
        ),
        buttonDown: RectangleComponent(size: Vector2(62, 62), paint: Paint()..color = const Color(0xCC6A56DF)),
        margin: const EdgeInsets.only(right: 24, bottom: 20),
        onPressed: _action,
      ),
    );

    _timer = durationSec.toDouble();
    onTick(_timer.ceil());
  }

  void _buildTileMap() {
    const tile = 32.0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 14; x++) {
        _world.add(
          RectangleComponent(
            position: Vector2(x * tile, y * tile),
            size: Vector2(tile - 1, tile - 1),
            paint: Paint()..color = (x + y).isEven ? const Color(0x223B5A49) : const Color(0x22293B33),
          ),
        );
      }
    }
  }

  Future<void> _spawnActors() async {
    _player = DotPlayer();
    _player.position = Vector2(120, 120);
    _world.add(_player);
    camera.follow(_player);

    if (mode == FlameMode.herb || mode == FlameMode.garden || mode == FlameMode.courier) {
      for (int i = 0; i < 8; i++) {
        final t = _collectible(const Color(0xFF7DE37B));
        _targets.add(t);
        _world.add(t);
      }
      for (int i = 0; i < 5; i++) {
        final h = _collectible(const Color(0xFFE07070));
        _hazards.add(h);
        _world.add(h);
      }
    }
  }

  PositionComponent _collectible(Color color) {
    final p = CircleComponent(
      radius: 8,
      paint: Paint()..color = color,
      position: Vector2(40 + _rng.nextDouble() * 360, 30 + _rng.nextDouble() * 180),
      anchor: Anchor.center,
    );
    p.add(CircleHitbox());
    return p;
  }

  void _addScore(int s) {
    _combo += 1;
    _score += s + (_combo ~/ 3);
    onScore(_score);
    onCombo(_combo);
    if (_combo % 3 == 0) {
      _world.add(
        ParticleSystemComponent(
          particle: Particle.generate(
            count: 14,
            lifespan: 0.45,
            generator: (i) => AcceleratedParticle(
              acceleration: Vector2(0, 30),
              speed: Vector2((_rng.nextDouble() - 0.5) * 140, -90 - _rng.nextDouble() * 60),
              position: _player.position.clone(),
              child: CircleParticle(radius: 2 + _rng.nextDouble() * 2, paint: Paint()..color = const Color(0xCCB38CFF)),
            ),
          ),
        ),
      );
    }
  }

  void _fail() {
    _combo = 0;
    onCombo(_combo);
    onFail();
  }

  void _action() {
    if (mode == FlameMode.smith) {
      final d = (_smithMeter - 0.5).abs();
      if (d < 0.06) {
        _addScore(4);
      } else if (d < 0.15) {
        _addScore(2);
      } else {
        _fail();
      }
      return;
    }

    if (mode == FlameMode.haggling) {
      final target = 0.55;
      final d = (_marketCursor - target).abs();
      if (d < 0.07) {
        _addScore(4);
      } else if (d < 0.14) {
        _addScore(2);
      } else {
        _fail();
      }
      return;
    }

    if (mode == FlameMode.dance) {
      final tap = _rng.nextInt(4);
      if (tap == _danceNeed) {
        _addScore(3);
      } else {
        _fail();
      }
      _danceNeed = _rng.nextInt(4);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _player.velocity = _joystick.relativeDelta * 120;

    _timer -= dt;
    if (_timer <= 0) {
      onDone(_score, _combo);
      pauseEngine();
      return;
    }
    onTick(_timer.ceil());

    if (mode == FlameMode.smith) {
      _smithMeter += (_smithForward ? 1 : -1) * dt * 0.9;
      if (_smithMeter >= 1) {
        _smithMeter = 1;
        _smithForward = false;
      }
      if (_smithMeter <= 0) {
        _smithMeter = 0;
        _smithForward = true;
      }
    }

    if (mode == FlameMode.haggling) {
      _marketCursor += (_marketForward ? 1 : -1) * dt * 1.1;
      if (_marketCursor >= 1) {
        _marketCursor = 1;
        _marketForward = false;
      }
      if (_marketCursor <= 0) {
        _marketCursor = 0;
        _marketForward = true;
      }
    }

    if (mode == FlameMode.herb || mode == FlameMode.garden || mode == FlameMode.courier) {
      for (final t in List<PositionComponent>.from(_targets)) {
        if (t.position.distanceTo(_player.position) < 16) {
          _addScore(2);
          t.removeFromParent();
          _targets.remove(t);
        }
      }
      for (final h in _hazards) {
        if (h.position.distanceTo(_player.position) < 14) {
          _fail();
        }
      }
    }
  }
}

class DotPlayer extends PositionComponent with CollisionCallbacks {
  DotPlayer() : super(size: Vector2(24, 36), anchor: Anchor.center);

  Vector2 velocity = Vector2.zero();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
    position.x = position.x.clamp(16, 432);
    position.y = position.y.clamp(16, 240);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(Rect.fromLTWH(-8, -14, 16, 22), Paint()..color = const Color(0xFF7E67FF));
    canvas.drawRect(Rect.fromLTWH(-7, -23, 14, 10), Paint()..color = const Color(0xFFF4D2B0));
  }
}
