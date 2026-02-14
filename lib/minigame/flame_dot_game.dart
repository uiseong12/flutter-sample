import 'dart:math';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';

import 'flame/components.dart';
import 'flame/models.dart';
import 'flame/scenes.dart';

export 'flame/models.dart' show FlameMode;

class DotFlameGame extends FlameGame {
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
  late final DotPlayerComponent _player;
  late final JoystickComponent _joystick;
  late final GameScene _scene;

  final Random _rng = Random();

  double _timer = 0;
  int _score = 0;
  int _combo = 0;

  @override
  Color backgroundColor() => const Color(0xFF15131D);

  @override
  Future<void> onLoad() async {
    _world = World();
    camera = CameraComponent.withFixedResolution(world: _world, width: 448, height: 256);
    await addAll([camera, _world]);

    _player = DotPlayerComponent()..position = Vector2(120, 120);
    _world.add(_player);
    camera.follow(_player);

    _scene = _createScene();
    await _loadTiledMap(_scene.mapName);
    await _scene.setup();

    _setupControls();

    _timer = durationSec.toDouble();
    onTick(_timer.ceil());
  }

  GameScene _createScene() {
    switch (mode) {
      case FlameMode.herb:
        return HerbScene(world: _world, player: _player, rng: _rng, addScore: _addScore, fail: _fail);
      case FlameMode.smith:
        return SmithScene(world: _world, player: _player, rng: _rng, addScore: _addScore, fail: _fail);
      case FlameMode.haggling:
        return HagglingScene(world: _world, player: _player, rng: _rng, addScore: _addScore, fail: _fail);
      case FlameMode.courier:
        return CourierScene(world: _world, player: _player, rng: _rng, addScore: _addScore, fail: _fail);
      case FlameMode.dance:
        return DanceScene(world: _world, player: _player, rng: _rng, addScore: _addScore, fail: _fail);
      case FlameMode.garden:
        return GardenScene(world: _world, player: _player, rng: _rng, addScore: _addScore, fail: _fail);
    }
  }

  Future<void> _loadTiledMap(String mapName) async {
    final tiled = await TiledComponent.load('$mapName.tmx', Vector2.all(32));
    _world.add(tiled);
  }

  void _setupControls() {
    final knob = CircleComponent(radius: 20, paint: Paint()..color = const Color(0xAAE9D7A1));
    final bg = CircleComponent(radius: 36, paint: Paint()..color = const Color(0x664C3A2A));
    _joystick = JoystickComponent(knob: knob, background: bg, margin: const EdgeInsets.only(left: 20, bottom: 20));
    camera.viewport.add(_joystick);

    camera.viewport.add(
      HudButtonComponent(
        button: RectangleComponent(
          size: Vector2(62, 62),
          paint: Paint()..color = const Color(0xAA7E67FF),
          children: [
            TextComponent(
              text: '액션',
              anchor: Anchor.center,
              position: Vector2(31, 31),
              textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        buttonDown: RectangleComponent(size: Vector2(62, 62), paint: Paint()..color = const Color(0xCC6A56DF)),
        margin: const EdgeInsets.only(right: 24, bottom: 20),
        onPressed: _scene.onAction,
      ),
    );
  }

  void _addScore(int s) {
    _combo += 1;
    _score += s + (_combo ~/ 3);
    onScore(_score);
    onCombo(_combo);
    if (_combo % 3 == 0) {
      _world.add(ParticleSystemComponent(particle: quickPurpleBurst(_rng, _player.position)));
    }
  }

  void _fail() {
    _combo = 0;
    onCombo(_combo);
    onFail();
  }

  @override
  void update(double dt) {
    super.update(dt);

    _player.velocity = _joystick.relativeDelta * 120;
    _scene.update(dt);

    _timer -= dt;
    if (_timer <= 0) {
      onDone(_score, _combo);
      pauseEngine();
      return;
    }
    onTick(_timer.ceil());
  }
}
