import 'dart:math';
import '../models/match_2d.dart';

/// Authoritative match-space ball model. It owns flight, bounce, spin and
/// loose-ball decay, but never decides the official score.
class BallPhysicsEngine {
  const BallPhysicsEngine();

  BallLaunch launch({
    required Match2DPlayer passer,
    required Match2DPlayer target,
    required double distance,
    bool cross = false,
    bool throughBall = false,
  }) {
    final type = cross
        ? BallPassType.cross
        : throughBall
            ? BallPassType.throughBall
            : distance > 24
                ? BallPassType.lofted
                : BallPassType.ground;
    final quality = (passer.passing * .62 + passer.overall * .18 + passer.dribbling * .10 + passer.physical * .10) / 100;
    final speed = switch (type) {
      BallPassType.ground => 18 + quality * 12,
      BallPassType.throughBall => 20 + quality * 13,
      BallPassType.lofted => 15 + quality * 10,
      BallPassType.cross => 13 + quality * 9,
    };
    final height = switch (type) {
      BallPassType.ground => 0.15,
      BallPassType.throughBall => 0.7,
      BallPassType.lofted => 5.5 + distance.clamp(0, 40) * .05,
      BallPassType.cross => 6.5 + distance.clamp(0, 50) * .06,
    };
    final spin = (passer.dribbling - 50) * .035 + (cross ? 1.8 : 0);
    return BallLaunch(type: type, speed: speed, peakHeight: height, spin: spin);
  }

  BallFlight sample({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required double progress,
    required BallLaunch launch,
  }) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    final smooth = t * t * (3 - 2 * t);
    final dx = endX - startX;
    final dy = endY - startY;
    final distance = sqrt(dx * dx + dy * dy);
    final arc = launch.peakHeight <= .3 ? launch.peakHeight : launch.peakHeight;
    final height = 4 * arc * t * (1 - t) + launch.peakHeight * .12 * sin(pi * t);
    final double vx = distance < .01 ? 0.0 : dx / max(.01, distance) * launch.speed;
    final double vy = distance < .01 ? 0.0 : dy / max(.01, distance) * launch.speed;
    return BallFlight(
      x: startX + dx * smooth,
      y: startY + dy * smooth,
      height: max(0, height),
      velocityX: vx,
      velocityY: vy,
      spin: launch.spin * (1 - t * .45),
      bounce: t >= .98 ? 1 : 0,
      distance: distance,
    );
  }

  LooseBall stepLoose({
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
    required double spin,
    required double bounce,
    double dt = .12,
  }) {
    final nextX = (x + velocityX * dt).clamp(2.5, 97.5).toDouble();
    final nextY = (y + velocityY * dt).clamp(2.5, 97.5).toDouble();
    var nextVx = velocityX * pow(.88, dt / .12).toDouble();
    var nextVy = velocityY * pow(.88, dt / .12).toDouble();
    var nextSpin = spin * pow(.91, dt / .12).toDouble();
    var nextBounce = max(0.0, bounce - .22 * dt / .12).toDouble();
    if (nextX <= 2.6 || nextX >= 97.4) nextVx *= -.55;
    if (nextY <= 2.6 || nextY >= 97.4) nextVy *= -.55;
    nextBounce = min(1.0, nextBounce + .08);
    nextSpin += (nextVx - nextVy) * .001;
    return LooseBall(x: nextX, y: nextY, velocityX: nextVx, velocityY: nextVy, spin: nextSpin, bounce: nextBounce);
  }
}

enum BallPassType { ground, throughBall, lofted, cross }

class BallLaunch {
  final BallPassType type;
  final double speed;
  final double peakHeight;
  final double spin;
  const BallLaunch({required this.type, required this.speed, required this.peakHeight, required this.spin});
}

class BallFlight {
  final double x;
  final double y;
  final double height;
  final double velocityX;
  final double velocityY;
  final double spin;
  final double bounce;
  final double distance;
  const BallFlight({required this.x, required this.y, required this.height, required this.velocityX, required this.velocityY, required this.spin, required this.bounce, required this.distance});
}

class LooseBall {
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;
  final double spin;
  final double bounce;
  const LooseBall({required this.x, required this.y, required this.velocityX, required this.velocityY, required this.spin, required this.bounce});
}
