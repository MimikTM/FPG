import 'dart:math';
import '../models/match_2d.dart';

/// Owns gameplay movement feel: acceleration, braking, turning inertia and
/// fatigue-aware top speed. It does not decide possession or match outcome.
class PlayerMovementEngine {
  const PlayerMovementEngine();

  void apply(Match2DPlayer player, double targetX, double targetY, {
    double urgency = .1,
    double dt = .12,
  }) {
    final dx = targetX - player.x;
    final dy = targetY - player.y;
    final distance = sqrt(dx * dx + dy * dy);
    final staminaFactor = (.62 + player.stamina / 100 * .38).clamp(.62, 1.0);
    final speedFactor = (0.72 + player.pace / 100 * .48).clamp(.72, 1.20);
    final desiredSpeed = (urgency * 12.0 * staminaFactor * speedFactor).clamp(0.25, 2.4);
    final desiredX = distance < .01 ? 0.0 : dx / distance * desiredSpeed;
    final desiredY = distance < .01 ? 0.0 : dy / distance * desiredSpeed;

    final acceleration = (distance > 8 ? .22 : .30) * (dt / .12).clamp(.5, 1.8);
    player.velocityX += (desiredX - player.velocityX) * acceleration;
    player.velocityY += (desiredY - player.velocityY) * acceleration;

    if (distance < 1.5) {
      final brake = (.38 + (1.5 - distance) * .16).clamp(.38, .62);
      player.velocityX *= 1 - brake;
      player.velocityY *= 1 - brake;
    }

    final speed = sqrt(player.velocityX * player.velocityX + player.velocityY * player.velocityY);
    if (speed > .01) {
      final desiredFacing = atan2(player.velocityY, player.velocityX);
      player.facingAngle = _approachAngle(player.facingAngle, desiredFacing,
          (0.16 + player.pace / 100 * .10) * (dt / .12).clamp(.5, 1.8));
    }

    player.x = (player.x + player.velocityX * dt).clamp(3.0, 97.0).toDouble();
    player.y = (player.y + player.velocityY * dt).clamp(3.0, 97.0).toDouble();

    final usedSpeed = speed;
    if (usedSpeed > 1.0 && player.stamina > 0) {
      final drainChance = (.012 + usedSpeed * .004).clamp(.012, .035);
      // Caller supplies its existing match RNG; movement itself remains
      // deterministic and drains via a continuous fractional accumulator.
      player.staminaAccumulator += drainChance * dt / .12;
      if (player.staminaAccumulator >= 1) {
        player.stamina = max(0, player.stamina - player.staminaAccumulator.floor());
        player.staminaAccumulator %= 1;
      }
    } else if (player.stamina < 100) {
      player.staminaAccumulator -= .004 * dt / .12;
      if (player.staminaAccumulator <= -1) {
        player.stamina = min(100, player.stamina + 1);
        player.staminaAccumulator += 1;
      }
    }
  }

  void stop(Match2DPlayer player, {double dt = .12}) {
    final damping = (0.28 * (dt / .12).clamp(.5, 1.8)).clamp(.18, .48);
    player.velocityX *= 1 - damping;
    player.velocityY *= 1 - damping;
  }

  double _approachAngle(double current, double target, double maxStep) {
    var delta = (target - current + pi) % (2 * pi) - pi;
    if (delta > maxStep) delta = maxStep;
    if (delta < -maxStep) delta = -maxStep;
    return current + delta;
  }
}
