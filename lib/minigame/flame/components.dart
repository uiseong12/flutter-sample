import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class DotPlayerComponent extends PositionComponent with CollisionCallbacks {
  DotPlayerComponent() : super(size: Vector2(22, 30), anchor: Anchor.center);

  Vector2 velocity = Vector2.zero();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(-7, -10, 14, 18), Paint()..color = const Color(0xFF7E67FF));
    canvas.drawRect(Rect.fromLTWH(-6, -17, 12, 9), Paint()..color = const Color(0xFFF4D2B0));
  }
}

class ItemComponent extends CircleComponent with CollisionCallbacks {
  ItemComponent({required Color color, required Vector2 position})
      : super(radius: 6, paint: Paint()..color = color, position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(CircleHitbox());
  }
}
