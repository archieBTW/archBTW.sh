import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const Color kCrimsonRed = Color(0xFFD90429);
const Color kDarkBlood = Color(0xFF780000);
const Color kNoseGlow = Color(0xFFFF1E42);
const Color kSnowWhite = Color(0xFFF0F4F8);
const Color kSnowShadow = Color(0xFFBCCCDC);
const Color kNightTop = Color(0xFF050814);
const Color kNightBottom = Color(0xFF101B38);

const List<String> kReindeerNames = [
  'DASHER',
  'DANCER',
  'PRANCER',
  'VIXEN',
  'COMET',
  'CUPID',
  'DONNER',
  'BLITZEN',
];

const List<String> kLyricQuotes = [
  'Rudolph snapped. Clapped back a little too hard.',
  'Antlers covered in stains of their enemies.',
  'Herbivores turned predatory. Chewing on the melody.',
  'Please don\'t make light of a nose that\'s glowing.',
  'Hooves thrown up but they still lied down.',
  'He marked their names in crimson red. "A check for you and for you, an X."',
  'Bloody snow melted off Santa\'s faux white collar.',
  'Now there\'s 8 or 9 deer on a beatup hauler.',
  'Twelve-gauged pecks from my favorite pigeon.',
  'Picked last for games and he drew some bad cards.',
  'The moon grins down onto the snowcapped trees.',
  'The next day, the crosses lined the horizon.',
];

class SantasInvadersGame extends StatefulWidget {
  const SantasInvadersGame({super.key});

  @override
  State<SantasInvadersGame> createState() => _SantasInvadersGameState();
}

class _SantasInvadersGameState extends State<SantasInvadersGame>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _rng = Random();

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _worldTime = 0.0;

  // Normalized world coordinates:
  // X: 0.0 (left) to 1.0 (right)
  // Y: 0.0 (top) to 1.0 (bottom), ground is at Y = 0.80
  static const double _groundY = 0.80;
  static const double _gravity = 1.95;

  // Platforms (xMin, xMax, y)
  final List<_Platform> _platforms = const [
    _Platform(xMin: 0.08, xMax: 0.34, y: 0.63),
    _Platform(xMin: 0.66, xMax: 0.92, y: 0.63),
    _Platform(xMin: 0.32, xMax: 0.68, y: 0.47),
  ];

  // Rudolph state
  double _playerX = 0.22;
  double _playerY = _groundY;
  double _playerVy = 0.0;
  bool _facingRight = true;
  double _aimAngle = 0.0; // radians, 0 = right, pi = left, -pi/2 = up
  bool _isGrounded = true;
  int _jumpsRemaining = 2;
  double _walkCycle = 0.0;
  double _muzzleFlashTimer = 0.0;
  double _fireCooldown = 0.0;
  double _recoilOffset = 0.0;

  // Input states (Keyboard)
  final Set<LogicalKeyboardKey> _keysPressed = {};
  bool _mouseShooting = false;

  // Input states (Touch Joystick & Buttons)
  int? _joystickPointerId;
  Offset _joystickCenter = Offset.zero;
  Offset _joystickDelta = Offset.zero; // normalized -1..1
  int? _shootButtonPointerId;
  int? _jumpButtonPointerId;

  // Game stats & lyric feed
  int _score = 0;
  int _kills = 0;
  int _combo = 0;
  double _comboTimer = 0.0;
  String _activeLyric = 'The moon grins down onto the snowcapped trees.';
  double _lyricFlash = 0.0;

  // Entities
  final List<_Bullet> _bullets = [];
  final List<_ReindeerTarget> _reindeer = [];
  final List<_BloodParticle> _bloodParticles = [];
  final List<_SnowStain> _snowStains = [];
  final List<_ShellCasing> _shells = [];
  final List<_FloatingText> _floatingTexts = [];
  final List<_HorizonCross> _horizonCrosses = [];
  late final List<_Snowflake> _snowflakes;
  late final List<_Star> _stars;

  double _spawnTimer = 0.0;

  // Audio playlist (Santa's Cookies EP)
  final List<String> _playlist = [
    'rudolph_spoke_in_class_today.wav',
    'who_you_calling_a_ho_ho.wav',
    'oh_christmas_tree.wav',
    'must_be_a_south_pole_elf.wav',
  ];
  List<String> _musicQueue = [];
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();

    _snowflakes = List.generate(
      70,
      (_) => _Snowflake(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        radius: 1.2 + _rng.nextDouble() * 2.5,
        speedY: 0.04 + _rng.nextDouble() * 0.08,
        drift: (_rng.nextDouble() - 0.5) * 0.03,
        phase: _rng.nextDouble() * pi * 2,
      ),
    );

    _stars = List.generate(
      45,
      (_) => _Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.52,
        size: 0.8 + _rng.nextDouble() * 1.8,
        twinklePhase: _rng.nextDouble() * pi * 2,
      ),
    );

    _seedInitialReindeer();

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _playNextTrack();
    });
    // Start with Rudolph Spoke in Class Today, then shuffle the rest
    _musicQueue = List.of(_playlist);
    _playNextTrack();
  }

  Future<void> _playNextTrack() async {
    if (_playlist.isEmpty) return;
    if (_musicQueue.isEmpty) {
      _musicQueue = List.of(_playlist)..shuffle();
    }
    final nextSong = _musicQueue.removeAt(0);
    try {
      await _audioPlayer.setSource(AssetSource('music/santas_cookies/$nextSong'));
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Audio Error: $e');
    }
  }

  void _seedInitialReindeer() {
    _reindeer.clear();
    for (int i = 0; i < 5; i++) {
      _spawnReindeer(initialSpread: true);
    }
  }

  void _resetAll() {
    setState(() {
      _score = 0;
      _kills = 0;
      _combo = 0;
      _comboTimer = 0.0;
      _playerX = 0.22;
      _playerY = _groundY;
      _playerVy = 0.0;
      _facingRight = true;
      _bullets.clear();
      _bloodParticles.clear();
      _snowStains.clear();
      _shells.clear();
      _floatingTexts.clear();
      _horizonCrosses.clear();
      _activeLyric = 'The moon grins down onto the snowcapped trees.';
      _seedInitialReindeer();
    });
  }

  void _spawnReindeer({bool initialSpread = false}) {
    if (_reindeer.length >= 9) return;

    final name = kReindeerNames[_rng.nextInt(kReindeerNames.length)];
    final bool isPrancingSky = _rng.nextDouble() < 0.22;
    final bool fromLeft = _rng.nextBool();

    double startX;
    if (initialSpread) {
      startX = 0.38 + _rng.nextDouble() * 0.55;
    } else {
      startX = fromLeft ? -0.06 : 1.06;
    }

    double targetY = _groundY;
    if (isPrancingSky) {
      targetY = 0.20 + _rng.nextDouble() * 0.22;
    } else if (_rng.nextDouble() < 0.45) {
      final p = _platforms[_rng.nextInt(_platforms.length)];
      targetY = p.y;
      if (initialSpread) {
        startX = p.xMin + _rng.nextDouble() * (p.xMax - p.xMin);
      }
    }

    final double baseSpeed = 0.055 + _rng.nextDouble() * 0.065;
    final double dir = initialSpread
        ? (_rng.nextBool() ? 1.0 : -1.0)
        : (fromLeft ? 1.0 : -1.0);

    _reindeer.add(
      _ReindeerTarget(
        name: name,
        x: startX,
        y: targetY,
        vx: dir * baseSpeed,
        vy: 0.0,
        isFlying: isPrancingSky,
        hp: 3,
        maxHp: 3,
        furVariant: _rng.nextInt(3),
        legPhase: _rng.nextDouble() * pi * 2,
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _keysPressed.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.keyZ ||
          event.logicalKey == LogicalKeyboardKey.keyK) {
        _triggerJump();
      }
    } else if (event is KeyUpEvent) {
      _keysPressed.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  void _triggerJump() {
    final bool holdingDown =
        _keysPressed.contains(LogicalKeyboardKey.keyS) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        _joystickDelta.dy > 0.55;

    // Drop through platform if holding down on an elevated platform
    if (holdingDown && _isGrounded && _playerY < _groundY - 0.02) {
      setState(() {
        _playerY += 0.03;
        _isGrounded = false;
      });
      return;
    }

    if (_jumpsRemaining > 0) {
      setState(() {
        _playerVy = -0.78;
        _isGrounded = false;
        _jumpsRemaining--;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _fireWeapon() {
    if (_fireCooldown > 0) return;
    _fireCooldown = 0.11; // rapid fire Contra rifle
    _muzzleFlashTimer = 0.06;
    _recoilOffset = 0.012;

    // Gun barrel tip position in normalized coordinates
    final double cosA = cos(_aimAngle);
    final double sinA = sin(_aimAngle);
    final double muzzleX = _playerX + cosA * 0.038;
    final double muzzleY = (_playerY - 0.055) + sinA * 0.038;

    // Slight spread for rapid machine-gun feel
    final double spread = (_rng.nextDouble() - 0.5) * 0.06;
    final double shotAngle = _aimAngle + spread;
    const double bulletSpeed = 1.35;

    _bullets.add(
      _Bullet(
        x: muzzleX,
        y: muzzleY,
        vx: cos(shotAngle) * bulletSpeed,
        vy: sin(shotAngle) * bulletSpeed,
      ),
    );

    // Eject brass shell casing
    _shells.add(
      _ShellCasing(
        x: _playerX,
        y: _playerY - 0.06,
        vx: (_facingRight ? -1 : 1) * (0.08 + _rng.nextDouble() * 0.08),
        vy: -0.25 - _rng.nextDouble() * 0.12,
        rotation: _rng.nextDouble() * pi,
      ),
    );
    if (_shells.length > 35) {
      _shells.removeAt(0);
    }

    // Scare nearby reindeer when gunfire rings out
    for (final r in _reindeer) {
      if ((r.x - _playerX).abs() < 0.45) {
        r.panicTimer = 2.0;
      }
    }
  }

  void _onTick(Duration elapsed) {
    final double dt = _lastElapsed == Duration.zero
        ? 0.016
        : ((elapsed - _lastElapsed).inMicroseconds / 1000000.0).clamp(
            0.001,
            0.05,
          );
    _lastElapsed = elapsed;

    setState(() {
      _worldTime += dt;
      if (_muzzleFlashTimer > 0) _muzzleFlashTimer = max(0, _muzzleFlashTimer - dt);
      if (_fireCooldown > 0) _fireCooldown = max(0, _fireCooldown - dt);
      if (_recoilOffset > 0) _recoilOffset = max(0, _recoilOffset - dt * 0.09);
      if (_lyricFlash > 0) _lyricFlash = max(0, _lyricFlash - dt);

      if (_comboTimer > 0) {
        _comboTimer -= dt;
        if (_comboTimer <= 0) {
          _combo = 0;
        }
      }

      _updatePlayer(dt);
      _updateBulletsAndCollisions(dt);
      _updateReindeer(dt);
      _updateParticles(dt);
      _updateSnowflakes(dt);

      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnReindeer();
        _spawnTimer = _reindeer.length < 4 ? 0.55 : 1.15;
      }
    });
  }

  void _updatePlayer(double dt) {
    // Combine keyboard and virtual joystick input
    double moveX = 0.0;
    double aimX = 0.0;
    double aimY = 0.0;

    if (_keysPressed.contains(LogicalKeyboardKey.keyA) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      moveX -= 1.0;
      aimX -= 1.0;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyD) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      moveX += 1.0;
      aimX += 1.0;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyW) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      aimY -= 1.0;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyS) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      aimY += 1.0;
    }

    if (_joystickPointerId != null && _joystickDelta.distance > 0.14) {
      if (_joystickDelta.dx.abs() > 0.22) {
        moveX = _joystickDelta.dx.clamp(-1.0, 1.0);
      }
      aimX = _joystickDelta.dx;
      aimY = _joystickDelta.dy;
    }

    if (moveX < -0.05) _facingRight = false;
    if (moveX > 0.05) _facingRight = true;

    // 8-way Contra snapping for aim
    if (aimX.abs() > 0.15 || aimY.abs() > 0.15) {
      // Prevent aiming straight down when standing on ground
      if (_isGrounded && aimY > 0.4 && aimX.abs() < 0.35) {
        _aimAngle = _facingRight ? 0.0 : pi;
      } else {
        final double rawAngle = atan2(aimY, aimX);
        // Snap to 8 directions (multiples of pi / 4)
        final double step = pi / 4;
        _aimAngle = (rawAngle / step).round() * step;
      }
    } else {
      _aimAngle = _facingRight ? 0.0 : pi;
    }

    // Horizontal movement
    const double playerSpeed = 0.36;
    _playerX += moveX * playerSpeed * dt;
    _playerX = _playerX.clamp(0.05, 0.95);

    if (moveX.abs() > 0.05 && _isGrounded) {
      _walkCycle += dt * 14.0;
    } else if (_isGrounded) {
      _walkCycle = 0.0;
    }

    // Vertical movement & platform collisions
    final double prevY = _playerY;
    _playerVy += _gravity * dt;
    _playerY += _playerVy * dt;
    _isGrounded = false;

    // Check landing on elevated platforms when falling
    if (_playerVy >= 0) {
      for (final p in _platforms) {
        if (_playerX >= p.xMin &&
            _playerX <= p.xMax &&
            prevY <= p.y + 0.008 &&
            _playerY >= p.y) {
          _playerY = p.y;
          _playerVy = 0.0;
          _isGrounded = true;
          _jumpsRemaining = 2;
          break;
        }
      }
    }

    // Ground collision
    if (_playerY >= _groundY) {
      _playerY = _groundY;
      _playerVy = 0.0;
      _isGrounded = true;
      _jumpsRemaining = 2;
    }

    // Check shooting input (Keyboard or Touch Shoot button or Mouse hold)
    final bool wantsShoot =
        _shootButtonPointerId != null ||
        _mouseShooting ||
        _keysPressed.contains(LogicalKeyboardKey.keyJ) ||
        _keysPressed.contains(LogicalKeyboardKey.keyX) ||
        _keysPressed.contains(LogicalKeyboardKey.keyF) ||
        _keysPressed.contains(LogicalKeyboardKey.enter) ||
        _keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        _keysPressed.contains(LogicalKeyboardKey.shiftRight);

    if (wantsShoot) {
      _fireWeapon();
    }
  }

  void _updateBulletsAndCollisions(double dt) {
    final List<_Bullet> bulletsToRemove = [];
    final List<_ReindeerTarget> killedReindeer = [];

    for (final b in _bullets) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;

      if (b.x < -0.05 || b.x > 1.05 || b.y < -0.05 || b.y > 1.0) {
        bulletsToRemove.add(b);
        continue;
      }

      // Check collision with any reindeer (they have no weapons and cannot hurt Rudolph)
      for (final r in _reindeer) {
        if (r.hp <= 0) continue;
        final double hitCenterX = r.x;
        final double hitCenterY = r.y - 0.042;
        final double dx = b.x - hitCenterX;
        final double dy = b.y - hitCenterY;

        if (dx.abs() < 0.046 && dy.abs() < 0.048) {
          bulletsToRemove.add(b);
          r.hp--;
          r.hitFlash = 0.18;
          r.panicTimer = 3.0;
          // Boost fleeing speed when shot
          if (r.vx.abs() < 0.14) {
            final double fleeDir = (r.x >= _playerX) ? 1.0 : -1.0;
            r.vx = fleeDir * (0.14 + _rng.nextDouble() * 0.05);
          }

          _score += 100;
          _spawnBloodBurst(
            x: b.x,
            y: b.y,
            count: r.hp <= 0 ? 38 : 14,
            bulletVx: b.vx,
            bulletVy: b.vy,
            isFatal: r.hp <= 0,
          );

          if (r.hp <= 0) {
            killedReindeer.add(r);
            _onReindeerKilled(r);
          } else {
            _floatingTexts.add(
              _FloatingText(
                text: '+100',
                x: r.x,
                y: r.y - 0.08,
                color: Colors.white,
                life: 0.65,
              ),
            );
          }
          break;
        }
      }
    }

    _bullets.removeWhere((b) => bulletsToRemove.contains(b));
    _reindeer.removeWhere((r) => killedReindeer.contains(r));
  }

  void _onReindeerKilled(_ReindeerTarget r) {
    _kills++;
    _combo++;
    _comboTimer = 3.2;

    final int killBonus = 500 * _combo;
    _score += killBonus;

    final String quote = kLyricQuotes[_kills % kLyricQuotes.length];
    _activeLyric = quote;
    _lyricFlash = 1.0;

    _floatingTexts.add(
      _FloatingText(
        text: '✖ ${r.name} +$killBonus',
        x: r.x.clamp(0.1, 0.9),
        y: r.y - 0.09,
        color: kCrimsonRed,
        life: 1.25,
        isBold: true,
      ),
    );

    // Add a blood stain directly below if near ground/platform
    _addSnowStainAt(r.x, r.isFlying ? _groundY : r.y, radius: 0.038);

    // Add a little cross on the distant snow ridge ("The next day, the crosses lined the horizon")
    if (_horizonCrosses.length < 24) {
      _horizonCrosses.add(
        _HorizonCross(
          x: (0.08 + (_kills * 0.073 + _rng.nextDouble() * 0.03) % 0.84),
          tilt: (_rng.nextDouble() - 0.5) * 0.18,
        ),
      );
    }

    HapticFeedback.mediumImpact();
  }

  void _spawnBloodBurst({
    required double x,
    required double y,
    required int count,
    required double bulletVx,
    required double bulletVy,
    required bool isFatal,
  }) {
    for (int i = 0; i < count; i++) {
      final double angle = _rng.nextDouble() * pi * 2;
      final double speed = 0.06 + _rng.nextDouble() * (isFatal ? 0.42 : 0.24);
      _bloodParticles.add(
        _BloodParticle(
          x: x,
          y: y,
          vx: cos(angle) * speed + bulletVx * 0.12,
          vy: sin(angle) * speed - 0.14 + bulletVy * 0.08,
          radius: isFatal
              ? (2.2 + _rng.nextDouble() * 4.5)
              : (1.8 + _rng.nextDouble() * 3.0),
          life: 0.55 + _rng.nextDouble() * 0.55,
          isChunk: isFatal && i < 5,
        ),
      );
    }
  }

  void _addSnowStainAt(double x, double y, {double radius = 0.022}) {
    _snowStains.add(
      _SnowStain(
        x: x.clamp(0.02, 0.98),
        y: y,
        radiusX: radius * (0.8 + _rng.nextDouble() * 0.6),
        radiusY: radius * 0.32,
      ),
    );
    if (_snowStains.length > 70) {
      _snowStains.removeAt(0);
    }
  }

  void _updateReindeer(double dt) {
    for (final r in _reindeer) {
      if (r.hitFlash > 0) r.hitFlash = max(0, r.hitFlash - dt);
      if (r.panicTimer > 0) r.panicTimer = max(0, r.panicTimer - dt);

      final double speedMult = r.panicTimer > 0 ? 1.55 : 1.0;
      r.x += r.vx * speedMult * dt;
      r.legPhase += dt * (r.panicTimer > 0 ? 16.0 : 9.5);

      if (r.isFlying) {
        // Prancing wave motion in the night sky
        r.y += sin(_worldTime * 3.5 + r.legPhase * 0.2) * 0.04 * dt;
      } else {
        // Occasional joyful/panicked hop
        if (r.vy == 0 && _rng.nextDouble() < (r.panicTimer > 0 ? 0.03 : 0.008)) {
          r.vy = -0.36;
        }
        if (r.vy != 0 || r.y < r.baseY) {
          r.vy += _gravity * 0.75 * dt;
          r.y += r.vy * dt;
          if (r.y >= r.baseY) {
            r.y = r.baseY;
            r.vy = 0.0;
          }
        }
      }

      // Keep on platform or turn around at edges
      if (!r.isFlying && r.baseY < _groundY - 0.02) {
        final platform = _platforms.firstWhere(
          (p) => (p.y - r.baseY).abs() < 0.03,
          orElse: () => const _Platform(xMin: 0.05, xMax: 0.95, y: _groundY),
        );
        if (r.x < platform.xMin + 0.02) {
          r.x = platform.xMin + 0.02;
          r.vx = r.vx.abs();
        } else if (r.x > platform.xMax - 0.02) {
          r.x = platform.xMax - 0.02;
          r.vx = -r.vx.abs();
        }
      } else {
        // Wrap or bounce at screen edges
        if (r.x < -0.08 && r.vx < 0) {
          r.vx = r.vx.abs();
        } else if (r.x > 1.08 && r.vx > 0) {
          r.vx = -r.vx.abs();
        }
      }
    }
  }

  void _updateParticles(double dt) {
    for (final p in _bloodParticles) {
      final double prevY = p.y;
      p.x += p.vx * dt;
      p.vy += _gravity * 0.85 * dt;
      p.y += p.vy * dt;
      p.life -= dt;

      // Check if blood droplet hits a platform or the snow ground
      for (final plat in _platforms) {
        if (p.vy > 0 &&
            p.x >= plat.xMin &&
            p.x <= plat.xMax &&
            prevY <= plat.y &&
            p.y >= plat.y) {
          _addSnowStainAt(p.x, plat.y, radius: 0.015);
          p.life = 0;
          break;
        }
      }
      if (p.y >= _groundY && p.life > 0) {
        _addSnowStainAt(p.x, _groundY, radius: 0.018);
        p.life = 0;
      }
    }
    _bloodParticles.removeWhere((p) => p.life <= 0);

    for (final s in _shells) {
      s.x += s.vx * dt;
      s.vy += _gravity * dt;
      s.y += s.vy * dt;
      s.rotation += dt * 10.0;
      if (s.y >= _groundY) {
        s.y = _groundY;
        s.vx *= 0.4;
        s.vy = 0;
      }
    }

    for (final ft in _floatingTexts) {
      ft.y -= 0.065 * dt;
      ft.life -= dt;
    }
    _floatingTexts.removeWhere((ft) => ft.life <= 0);
  }

  void _updateSnowflakes(double dt) {
    for (final flake in _snowflakes) {
      flake.y += flake.speedY * dt;
      flake.x += (flake.drift + sin(_worldTime + flake.phase) * 0.01) * dt;
      if (flake.y > 1.0) {
        flake.y = -0.02;
        flake.x = _rng.nextDouble();
      }
      if (flake.x < 0) flake.x += 1.0;
      if (flake.x > 1.0) flake.x -= 1.0;
    }
  }

  void _updateJoystickVector(Offset localPos, double maxRadius) {
    final Offset raw = localPos - _joystickCenter;
    final double dist = raw.distance;
    if (dist <= 0.001) {
      _joystickDelta = Offset.zero;
      return;
    }
    final double clampedDist = min(dist, maxRadius);
    final Offset dir = raw / dist;
    _joystickDelta = dir * (clampedDist / maxRadius);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNightTop,
      appBar: AppBar(
        backgroundColor: const Color(0xFF060B19),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'rudolph_spoke.sh',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'JetBrainsMono',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Reset Snowfield',
            onPressed: _resetAll,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) => _handleKeyEvent(_focusNode, event),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 700;
            final double joystickSize = isCompact ? 118.0 : 128.0;
            final double joystickRadius = joystickSize / 2;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Main Cartoon Game Canvas (supports click/hold to aim & shoot on desktop)
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    _focusNode.requestFocus();
                    // Allow clicking/tapping canvas outside controls to aim & shoot
                    final double normX = event.localPosition.dx / constraints.maxWidth;
                    final double normY = event.localPosition.dy / constraints.maxHeight;
                    if (normY < 0.75) {
                      _facingRight = normX >= _playerX;
                      _aimAngle = atan2(
                        normY - (_playerY - 0.055),
                        normX - _playerX,
                      );
                      _mouseShooting = true;
                      _fireWeapon();
                    }
                  },
                  onPointerMove: (event) {
                    if (_mouseShooting) {
                      final double normX =
                          event.localPosition.dx / constraints.maxWidth;
                      final double normY =
                          event.localPosition.dy / constraints.maxHeight;
                      _facingRight = normX >= _playerX;
                      _aimAngle = atan2(
                        normY - (_playerY - 0.055),
                        normX - _playerX,
                      );
                    }
                  },
                  onPointerUp: (_) => _mouseShooting = false,
                  onPointerCancel: (_) => _mouseShooting = false,
                  child: CustomPaint(
                    painter: _RudolphContraPainter(
                      worldTime: _worldTime,
                      playerX: _playerX,
                      playerY: _playerY,
                      facingRight: _facingRight,
                      aimAngle: _aimAngle,
                      walkCycle: _walkCycle,
                      isGrounded: _isGrounded,
                      muzzleFlashTimer: _muzzleFlashTimer,
                      recoilOffset: _recoilOffset,
                      kills: _kills,
                      platforms: _platforms,
                      bullets: _bullets,
                      reindeer: _reindeer,
                      bloodParticles: _bloodParticles,
                      snowStains: _snowStains,
                      shells: _shells,
                      floatingTexts: _floatingTexts,
                      horizonCrosses: _horizonCrosses,
                      snowflakes: _snowflakes,
                      stars: _stars,
                    ),
                  ),
                ),

                // Top HUD: Score, Crimson Checkmarks, and Lyric Ticker
                Positioned(
                  top: 10,
                  left: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                border: Border.all(
                                  color: kCrimsonRed.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'POINTS: $_score',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'JetBrainsMono',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'MARKED IN CRIMSON: $_kills${_combo > 1 ? "  (${_combo}x COMBO!)" : ""}',
                                    style: const TextStyle(
                                      color: kCrimsonRed,
                                      fontFamily: 'JetBrainsMono',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isCompact)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Text(
                                  'WASD/ARROWS: Move & Aim | SPACE: Jump | J/X/CLICK: Shoot',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(4),
                              border: Border(
                                left: BorderSide(
                                  color: _lyricFlash > 0
                                      ? kNoseGlow
                                      : Colors.white38,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              '// "$_activeLyric"',
                              style: TextStyle(
                                color: _lyricFlash > 0
                                    ? Colors.white
                                    : Colors.white70,
                                fontFamily: 'JetBrainsMono',
                                fontStyle: FontStyle.italic,
                                fontSize: isCompact ? 11 : 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Contra-style Touch Controls: Left Virtual Joystick + Right JUMP & SHOOT buttons
                Positioned(
                  left: isCompact ? 16 : 28,
                  bottom: isCompact ? 16 : 24,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      if (_joystickPointerId == null) {
                        setState(() {
                          _joystickPointerId = event.pointer;
                          _joystickCenter = Offset(joystickRadius, joystickRadius);
                          _updateJoystickVector(
                            event.localPosition,
                            joystickRadius * 0.68,
                          );
                        });
                      }
                    },
                    onPointerMove: (event) {
                      if (event.pointer == _joystickPointerId) {
                        setState(() {
                          _updateJoystickVector(
                            event.localPosition,
                            joystickRadius * 0.68,
                          );
                        });
                      }
                    },
                    onPointerUp: (event) {
                      if (event.pointer == _joystickPointerId) {
                        setState(() {
                          _joystickPointerId = null;
                          _joystickDelta = Offset.zero;
                        });
                      }
                    },
                    onPointerCancel: (event) {
                      if (event.pointer == _joystickPointerId) {
                        setState(() {
                          _joystickPointerId = null;
                          _joystickDelta = Offset.zero;
                        });
                      }
                    },
                    child: SizedBox(
                      key: const Key('virtual_joystick'),
                      width: joystickSize,
                      height: joystickSize,
                      child: CustomPaint(
                        painter: _JoystickPainter(
                          delta: _joystickDelta,
                          isActive: _joystickPointerId != null,
                        ),
                      ),
                    ),
                  ),
                ),

                // Right-side JUMP and SHOOT arcade buttons
                Positioned(
                  right: isCompact ? 16 : 28,
                  bottom: isCompact ? 18 : 26,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // JUMP Button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, right: 14),
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) {
                            _jumpButtonPointerId = event.pointer;
                            _triggerJump();
                          },
                          onPointerUp: (event) {
                            if (event.pointer == _jumpButtonPointerId) {
                              setState(() => _jumpButtonPointerId = null);
                            }
                          },
                          onPointerCancel: (event) {
                            if (event.pointer == _jumpButtonPointerId) {
                              setState(() => _jumpButtonPointerId = null);
                            }
                          },
                          child: _ArcadeControlButton(
                            key: const Key('jump_button'),
                            label: 'JUMP',
                            subLabel: 'SPACE',
                            color: const Color(0xFF1D4ED8),
                            isPressed: _jumpButtonPointerId != null,
                            size: isCompact ? 68 : 74,
                          ),
                        ),
                      ),
                      // SHOOT Button (Hold for auto-fire)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) {
                            setState(() => _shootButtonPointerId = event.pointer);
                            _fireWeapon();
                          },
                          onPointerUp: (event) {
                            if (event.pointer == _shootButtonPointerId) {
                              setState(() => _shootButtonPointerId = null);
                            }
                          },
                          onPointerCancel: (event) {
                            if (event.pointer == _shootButtonPointerId) {
                              setState(() => _shootButtonPointerId = null);
                            }
                          },
                          child: _ArcadeControlButton(
                            key: const Key('shoot_button'),
                            label: 'SHOOT',
                            subLabel: 'FIRE',
                            color: kCrimsonRed,
                            isPressed: _shootButtonPointerId != null,
                            size: isCompact ? 76 : 82,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArcadeControlButton extends StatelessWidget {
  final String label;
  final String subLabel;
  final Color color;
  final bool isPressed;
  final double size;

  const _ArcadeControlButton({
    super.key,
    required this.label,
    required this.subLabel,
    required this.color,
    required this.isPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isPressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPressed
              ? color.withValues(alpha: 0.85)
              : color.withValues(alpha: 0.55),
          border: Border.all(
            color: Colors.white.withValues(alpha: isPressed ? 0.95 : 0.65),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isPressed ? 0.65 : 0.3),
              blurRadius: isPressed ? 14 : 8,
              spreadRadius: isPressed ? 2 : 0,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                subLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset delta;
  final bool isActive;

  _JoystickPainter({required this.delta, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;

    // Outer base circle
    final Paint baseFill = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final Paint baseBorder = Paint()
      ..color = Colors.white.withValues(alpha: isActive ? 0.75 : 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawCircle(center, radius - 2, baseFill);
    canvas.drawCircle(center, radius - 2, baseBorder);

    // 8-direction tick marks
    final Paint tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final double a = i * (pi / 4);
      final Offset p1 = center + Offset(cos(a), sin(a)) * (radius * 0.58);
      final Offset p2 = center + Offset(cos(a), sin(a)) * (radius * 0.80);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Thumbstick knob
    final Offset knobPos = center + delta * (radius * 0.52);
    final Paint stemPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, knobPos, stemPaint);

    final Paint knobFill = Paint()
      ..color = isActive
          ? kCrimsonRed.withValues(alpha: 0.9)
          : const Color(0xFF475569).withValues(alpha: 0.85);
    final Paint knobBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(knobPos, radius * 0.34, knobFill);
    canvas.drawCircle(knobPos, radius * 0.34, knobBorder);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.delta != delta || oldDelegate.isActive != isActive;
}

class _RudolphContraPainter extends CustomPainter {
  final double worldTime;
  final double playerX;
  final double playerY;
  final bool facingRight;
  final double aimAngle;
  final double walkCycle;
  final bool isGrounded;
  final double muzzleFlashTimer;
  final double recoilOffset;
  final int kills;
  final List<_Platform> platforms;
  final List<_Bullet> bullets;
  final List<_ReindeerTarget> reindeer;
  final List<_BloodParticle> bloodParticles;
  final List<_SnowStain> snowStains;
  final List<_ShellCasing> shells;
  final List<_FloatingText> floatingTexts;
  final List<_HorizonCross> horizonCrosses;
  final List<_Snowflake> snowflakes;
  final List<_Star> stars;

  _RudolphContraPainter({
    required this.worldTime,
    required this.playerX,
    required this.playerY,
    required this.facingRight,
    required this.aimAngle,
    required this.walkCycle,
    required this.isGrounded,
    required this.muzzleFlashTimer,
    required this.recoilOffset,
    required this.kills,
    required this.platforms,
    required this.bullets,
    required this.reindeer,
    required this.bloodParticles,
    required this.snowStains,
    required this.shells,
    required this.floatingTexts,
    required this.horizonCrosses,
    required this.snowflakes,
    required this.stars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawNightSkyAndStars(canvas, size);
    _drawGrinningMoon(canvas, size);
    _drawDistantMountainsAndCrosses(canvas, size);
    _drawSnowcappedTreesAndGingerbread(canvas, size);
    _drawMainSnowGround(canvas, size);
    _drawPlatforms(canvas, size);
    _drawSnowBloodStains(canvas, size);
    _drawShellCasings(canvas, size);

    // Draw unarmed target reindeer
    for (final r in reindeer) {
      _drawCartoonReindeerTarget(canvas, size, r);
    }

    // Draw playable Rudolph commando
    _drawRudolphCommando(canvas, size);

    // Draw bullets & blood particles
    _drawBullets(canvas, size);
    _drawBloodParticles(canvas, size);
    _drawFloatingTexts(canvas, size);
    _drawSnowfall(canvas, size);
  }

  void _drawNightSkyAndStars(Canvas canvas, Size size) {
    final Rect skyRect = Offset.zero & size;
    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kNightTop, kNightBottom, Color(0xFF1B2A4A)],
        stops: [0.0, 0.55, 0.85],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final Paint starPaint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      final double alpha = 0.45 + 0.55 * sin(worldTime * 2.2 + s.twinklePhase).abs();
      starPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        starPaint,
      );
    }
  }

  void _drawGrinningMoon(Canvas canvas, Size size) {
    // "The moon grins down onto the snowcapped trees."
    final Offset moonCenter = Offset(size.width * 0.80, size.height * 0.16);
    final double moonRadius = min(size.width, size.height) * 0.085;

    // Outer lunar glow
    for (int i = 3; i >= 1; i--) {
      final Paint glowPaint = Paint()
        ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.06 * i);
      canvas.drawCircle(moonCenter, moonRadius * (1.0 + i * 0.35), glowPaint);
    }

    // Moon body with cartoon outline
    final Paint moonFill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.25),
        radius: 0.9,
        colors: const [Color(0xFFFFFAE5), Color(0xFFFDE68A), Color(0xFFF59E0B)],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: moonRadius));
    final Paint outlinePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(moonCenter, moonRadius, moonFill);
    canvas.drawCircle(moonCenter, moonRadius, outlinePaint);

    // Subtle moon craters
    final Paint craterPaint = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.22);
    canvas.drawCircle(
      moonCenter + Offset(-moonRadius * 0.42, -moonRadius * 0.35),
      moonRadius * 0.16,
      craterPaint,
    );
    canvas.drawCircle(
      moonCenter + Offset(moonRadius * 0.48, -moonRadius * 0.12),
      moonRadius * 0.12,
      craterPaint,
    );

    // Mischievous cartoon eyes looking down at the snowfield
    final Paint eyeWhite = Paint()..color = Colors.white;
    final Paint pupilPaint = Paint()..color = const Color(0xFF0F172A);
    final Offset leftEye = moonCenter + Offset(-moonRadius * 0.28, -moonRadius * 0.12);
    final Offset rightEye = moonCenter + Offset(moonRadius * 0.22, -moonRadius * 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: leftEye,
        width: moonRadius * 0.28,
        height: moonRadius * 0.22,
      ),
      eyeWhite,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: rightEye,
        width: moonRadius * 0.28,
        height: moonRadius * 0.22,
      ),
      eyeWhite,
    );
    canvas.drawCircle(
      leftEye + Offset(-moonRadius * 0.03, moonRadius * 0.04),
      moonRadius * 0.07,
      pupilPaint,
    );
    canvas.drawCircle(
      rightEye + Offset(-moonRadius * 0.03, moonRadius * 0.04),
      moonRadius * 0.07,
      pupilPaint,
    );

    // Angry/sly brow line
    final Paint browPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      leftEye + Offset(-moonRadius * 0.15, -moonRadius * 0.13),
      leftEye + Offset(moonRadius * 0.12, -moonRadius * 0.06),
      browPaint,
    );
    canvas.drawLine(
      rightEye + Offset(-moonRadius * 0.12, -moonRadius * 0.06),
      rightEye + Offset(moonRadius * 0.15, -moonRadius * 0.13),
      browPaint,
    );

    // Wide cartoon grin with teeth
    final Path grinPath = Path()
      ..moveTo(moonCenter.dx - moonRadius * 0.52, moonCenter.dy + moonRadius * 0.12)
      ..quadraticBezierTo(
        moonCenter.dx,
        moonCenter.dy + moonRadius * 0.65,
        moonCenter.dx + moonRadius * 0.52,
        moonCenter.dy + moonRadius * 0.10,
      )
      ..quadraticBezierTo(
        moonCenter.dx,
        moonCenter.dy + moonRadius * 0.35,
        moonCenter.dx - moonRadius * 0.52,
        moonCenter.dy + moonRadius * 0.12,
      )
      ..close();

    canvas.drawPath(grinPath, Paint()..color = Colors.white);
    canvas.drawPath(grinPath, outlinePaint);

    // Grin teeth dividers
    final Paint toothLine = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.5;
    for (int t = -2; t <= 2; t++) {
      final double tx = moonCenter.dx + t * moonRadius * 0.15;
      canvas.drawLine(
        Offset(tx, moonCenter.dy + moonRadius * 0.22),
        Offset(tx, moonCenter.dy + moonRadius * 0.37),
        toothLine,
      );
    }
  }

  void _drawDistantMountainsAndCrosses(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.68;

    // Distant snow-covered mountain range
    final Path mountainPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, horizonY)
      ..lineTo(size.width * 0.14, size.height * 0.50)
      ..lineTo(size.width * 0.29, horizonY - 10)
      ..lineTo(size.width * 0.48, size.height * 0.45)
      ..lineTo(size.width * 0.66, horizonY - 5)
      ..lineTo(size.width * 0.84, size.height * 0.52)
      ..lineTo(size.width, horizonY - 12)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      mountainPath,
      Paint()..color = const Color(0xFF1E2D4D),
    );

    // Rolling mid-ground snow hills
    final Path hillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, horizonY + 8)
      ..quadraticBezierTo(
        size.width * 0.25,
        horizonY - 22,
        size.width * 0.52,
        horizonY + 6,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        horizonY - 20,
        size.width,
        horizonY + 4,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      hillPath,
      Paint()..color = const Color(0xFF334E68),
    );

    // "The next day, the crosses lined the horizon."
    final Paint crossPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final c in horizonCrosses) {
      final double cx = c.x * size.width;
      final double cy = horizonY - 6;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(c.tilt);
      canvas.drawLine(const Offset(0, 4), const Offset(0, -18), crossPaint);
      canvas.drawLine(const Offset(-6, -11), const Offset(6, -11), crossPaint);
      canvas.restore();
    }
  }

  void _drawSnowcappedTreesAndGingerbread(Canvas canvas, Size size) {
    final double groundPx = size.height * 0.80;

    // Distant gingerbread house silhouette with billowing chimney ("Gingerbread house with a chimney that billows")
    final double houseX = size.width * 0.11;
    final double houseY = groundPx - 36;
    final Paint housePaint = Paint()..color = const Color(0xFF5C3A21);
    final Paint outline = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Chimney smoke puffs
    for (int i = 0; i < 4; i++) {
      final double puffProgress = ((worldTime * 0.4 + i * 0.25) % 1.0);
      final Offset puffCenter = Offset(
        houseX + 18 + sin(worldTime * 2 + i) * 6,
        houseY - 18 - puffProgress * 38,
      );
      canvas.drawCircle(
        puffCenter,
        5 + puffProgress * 9,
        Paint()..color = Colors.white.withValues(alpha: (1 - puffProgress) * 0.28),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(houseX + 13, houseY - 16, 9, 18),
      housePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(houseX - 18, houseY, 38, 36),
      housePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(houseX - 18, houseY, 38, 36),
      outline,
    );
    // Warm glowing window
    canvas.drawRect(
      Rect.fromLTWH(houseX - 6, houseY + 10, 12, 12),
      Paint()..color = const Color(0xFFFBBF24),
    );
    // Snow-frosted roof
    final Path roofSnow = Path()
      ..moveTo(houseX - 24, houseY + 3)
      ..lineTo(houseX + 1, houseY - 18)
      ..lineTo(houseX + 26, houseY + 3)
      ..close();
    canvas.drawPath(roofSnow, Paint()..color = kSnowWhite);
    canvas.drawPath(roofSnow, outline);

    // Snowcapped pine trees across the background
    final List<double> treePositions = [0.04, 0.21, 0.37, 0.54, 0.72, 0.91];
    for (int i = 0; i < treePositions.length; i++) {
      final double tx = treePositions[i] * size.width;
      final double scale = (i.isEven ? 1.0 : 0.82);
      _drawSingleSnowTree(canvas, Offset(tx, groundPx), 68 * scale);
    }
  }

  void _drawSingleSnowTree(Canvas canvas, Offset base, double height) {
    final Paint trunkPaint = Paint()..color = const Color(0xFF4A2C11);
    final Paint pinePaint = Paint()..color = const Color(0xFF14532D);
    final Paint snowCapPaint = Paint()..color = kSnowWhite;
    final Paint outline = Paint()
      ..color = const Color(0xFF0B132B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRect(
      Rect.fromCenter(
        center: base - Offset(0, height * 0.1),
        width: height * 0.16,
        height: height * 0.22,
      ),
      trunkPaint,
    );

    for (int tier = 0; tier < 3; tier++) {
      final double tierBottom = base.dy - height * (0.18 + tier * 0.24);
      final double tierTop = tierBottom - height * 0.36;
      final double halfWidth = height * (0.38 - tier * 0.07);

      final Path foliage = Path()
        ..moveTo(base.dx, tierTop)
        ..lineTo(base.dx - halfWidth, tierBottom)
        ..lineTo(base.dx + halfWidth, tierBottom)
        ..close();
      canvas.drawPath(foliage, pinePaint);
      canvas.drawPath(foliage, outline);

      // Thick cartoon snow cap on top of each pine tier
      final Path snowCap = Path()
        ..moveTo(base.dx, tierTop)
        ..lineTo(base.dx - halfWidth * 0.58, tierTop + (tierBottom - tierTop) * 0.52)
        ..quadraticBezierTo(
          base.dx,
          tierTop + (tierBottom - tierTop) * 0.66,
          base.dx + halfWidth * 0.58,
          tierTop + (tierBottom - tierTop) * 0.52,
        )
        ..close();
      canvas.drawPath(snowCap, snowCapPaint);
    }
  }

  void _drawMainSnowGround(Canvas canvas, Size size) {
    final double groundY = size.height * 0.80;

    // Deep snowbank fill
    final Rect snowRect = Rect.fromLTWH(0, groundY, size.width, size.height - groundY);
    final Paint snowPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kSnowWhite, Color(0xFFD9E2EC), Color(0xFF9FB3C8)],
      ).createShader(snowRect);
    canvas.drawRect(snowRect, snowPaint);

    // Cartoon wavy snowdrift ridge line
    final Path driftPath = Path()..moveTo(0, groundY);
    for (double x = 0; x <= size.width; x += size.width / 8) {
      driftPath.quadraticBezierTo(
        x + size.width / 16,
        groundY - 5,
        x + size.width / 8,
        groundY,
      );
    }
    canvas.drawPath(
      driftPath,
      Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawPlatforms(Canvas canvas, Size size) {
    final Paint rockPaint = Paint()..color = const Color(0xFF334155);
    final Paint snowTopPaint = Paint()..color = kSnowWhite;
    final Paint outline = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (final p in platforms) {
      final double left = p.xMin * size.width;
      final double right = p.xMax * size.width;
      final double top = p.y * size.height;
      final double width = right - left;

      // Icy rock base
      final RRect baseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, 18),
        const Radius.circular(8),
      );
      canvas.drawRRect(baseRect, rockPaint);
      canvas.drawRRect(baseRect, outline);

      // Thick snow blanket on top of the ledge
      final RRect snowCap = RRect.fromRectAndRadius(
        Rect.fromLTWH(left - 3, top - 4, width + 6, 11),
        const Radius.circular(6),
      );
      canvas.drawRRect(snowCap, snowTopPaint);
      canvas.drawRRect(snowCap, outline);
    }
  }

  void _drawSnowBloodStains(Canvas canvas, Size size) {
    for (final stain in snowStains) {
      final Offset center = Offset(
        stain.x * size.width,
        stain.y * size.height + 2,
      );
      final Rect oval = Rect.fromCenter(
        center: center,
        width: stain.radiusX * size.width,
        height: stain.radiusY * size.height + 4,
      );
      canvas.drawOval(
        oval,
        Paint()..color = kCrimsonRed.withValues(alpha: 0.82),
      );
      canvas.drawOval(
        oval.deflate(2),
        Paint()..color = kDarkBlood.withValues(alpha: 0.65),
      );
    }
  }

  void _drawShellCasings(Canvas canvas, Size size) {
    final Paint brassPaint = Paint()..color = const Color(0xFFF59E0B);
    for (final s in shells) {
      canvas.save();
      canvas.translate(s.x * size.width, s.y * size.height);
      canvas.rotate(s.rotation);
      canvas.drawRect(
        const Rect.fromLTWH(-3, -1.5, 6, 3),
        brassPaint,
      );
      canvas.restore();
    }
  }

  void _drawCartoonReindeerTarget(
    Canvas canvas,
    Size size,
    _ReindeerTarget r,
  ) {
    final double cx = r.x * size.width;
    final double cy = r.y * size.height;
    final bool movingRight = r.vx >= 0;
    final bool panicked = r.panicTimer > 0;

    // Fur palette variations so each reindeer looks distinct and detailed
    final List<Color> coatColors = [
      const Color(0xFF8D5524),
      const Color(0xFFA0522D),
      const Color(0xFF6F4E37),
    ];
    final Color mainCoat = r.hitFlash > 0
        ? kCrimsonRed
        : coatColors[r.furVariant % coatColors.length];
    const Color bellyCream = Color(0xFFF3E5AB);
    const Color darkHoof = Color(0xFF1F1610);
    const Color antlerTan = Color(0xFFD2B48C);

    final Paint coatPaint = Paint()..color = mainCoat;
    final Paint bellyPaint = Paint()..color = bellyCream;
    final Paint outline = Paint()
      ..color = const Color(0xFF1A110B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(cx, cy);

    // Shadow on snow
    if (!r.isFlying) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 0), width: 48, height: 10),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
    }

    canvas.save();
    if (!movingRight) {
      canvas.scale(-1, 1);
    }

    // Animated 4-legged deer gallop/walk cycle
    final double swing = sin(r.legPhase) * (panicked ? 11.0 : 7.0);
    final double swingOpp = cos(r.legPhase) * (panicked ? 11.0 : 7.0);

    void drawDeerLeg(Offset hip, double angleOffset, bool isBackLayer) {
      final Paint legPaint = Paint()
        ..color = isBackLayer
            ? Color.lerp(mainCoat, Colors.black, 0.25)!
            : mainCoat
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round;
      final Offset knee = hip + Offset(angleOffset * 0.45, 11);
      final Offset hoof = knee + Offset(angleOffset * 0.65, 11);
      canvas.drawLine(hip, knee, legPaint);
      canvas.drawLine(knee, hoof, legPaint);

      // Cloven hoof
      final Path hoofPath = Path()
        ..moveTo(hoof.dx - 3, hoof.dy - 2)
        ..lineTo(hoof.dx + 4, hoof.dy - 2)
        ..lineTo(hoof.dx + 5, hoof.dy + 3)
        ..lineTo(hoof.dx - 3, hoof.dy + 3)
        ..close();
      canvas.drawPath(hoofPath, Paint()..color = darkHoof);
    }

    // Back legs
    drawDeerLeg(const Offset(-14, -22), swingOpp, true);
    drawDeerLeg(const Offset(12, -22), -swing, true);

    // Fluffy white deer tail
    final Path tailPath = Path()
      ..moveTo(-20, -32)
      ..quadraticBezierTo(-32, -40, -28, -26)
      ..quadraticBezierTo(-24, -22, -18, -26)
      ..close();
    canvas.drawPath(tailPath, bellyPaint);
    canvas.drawPath(tailPath, outline);

    // Reindeer torso (sleek cartoon deer body with cream underbelly and spots)
    final RRect bodyRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(-2, -29), width: 42, height: 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRRect, coatPaint);

    // Cream underbelly trim
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(-2, -23), width: 34, height: 10),
      0,
      pi,
      false,
      bellyPaint,
    );

    // White fawn spots on back
    final Paint spotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(const Offset(-12, -33), 2.5, spotPaint);
    canvas.drawCircle(const Offset(-5, -35), 2.0, spotPaint);
    canvas.drawCircle(const Offset(-9, -29), 1.8, spotPaint);
    canvas.drawRRect(bodyRRect, outline);

    // Front legs
    drawDeerLeg(const Offset(-12, -22), swing, false);
    drawDeerLeg(const Offset(14, -22), -swingOpp, false);

    // Long reindeer neck & festive red/green jingle bell collar
    final Path neckPath = Path()
      ..moveTo(8, -33)
      ..lineTo(18, -50)
      ..lineTo(26, -46)
      ..lineTo(18, -24)
      ..close();
    canvas.drawPath(neckPath, coatPaint);
    canvas.drawPath(neckPath, outline);

    // Festive collar + gold jingle bells
    final Paint collarPaint = Paint()
      ..color = const Color(0xFFB91C1C)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(10, -36), const Offset(21, -30), collarPaint);
    canvas.drawCircle(
      const Offset(16, -32),
      3.2,
      Paint()..color = const Color(0xFFFACC15),
    );

    // Multi-pronged branching antlers (unmistakably a reindeer!)
    final Paint antlerPaint = Paint()
      ..color = antlerTan
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint antlerOutline = Paint()
      ..color = const Color(0xFF1A110B)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Path antlers = Path()
      // Back antler beam + tines
      ..moveTo(19, -54)
      ..lineTo(11, -72)
      ..moveTo(15, -63)
      ..lineTo(7, -66)
      ..moveTo(13, -68)
      ..lineTo(18, -75)
      // Front antler beam + tines
      ..moveTo(22, -54)
      ..lineTo(20, -75)
      ..moveTo(21, -64)
      ..lineTo(28, -68)
      ..moveTo(20, -70)
      ..lineTo(14, -77);
    canvas.drawPath(antlers, antlerOutline);
    canvas.drawPath(antlers, antlerPaint);

    // Reindeer ear
    final Path earPath = Path()
      ..moveTo(16, -50)
      ..quadraticBezierTo(6, -56, 9, -46)
      ..close();
    canvas.drawPath(earPath, coatPaint);
    canvas.drawPath(earPath, outline);

    // Reindeer head & elongated snout
    final Path headPath = Path()
      ..moveTo(14, -52)
      ..quadraticBezierTo(24, -58, 29, -50)
      ..lineTo(39, -47)
      ..quadraticBezierTo(41, -41, 34, -39)
      ..lineTo(18, -41)
      ..close();
    canvas.drawPath(headPath, coatPaint);
    canvas.drawPath(headPath, outline);

    // Dark reindeer nose (non-glowing)
    canvas.drawCircle(
      const Offset(38, -45),
      3.2,
      Paint()..color = darkHoof,
    );

    // Expressive cartoon eye (wide-eyed panic when Rudolph shoots!)
    final Offset eyeCenter = const Offset(25, -48);
    canvas.drawCircle(
      eyeCenter,
      panicked ? 4.4 : 3.4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      eyeCenter,
      panicked ? 4.4 : 3.4,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(
      eyeCenter + Offset(panicked ? -0.5 : 0.8, 0),
      panicked ? 1.6 : 1.8,
      Paint()..color = Colors.black,
    );

    // Open shocked mouth & sweat drop when panicked
    if (panicked) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(31, -41), width: 6, height: 4),
        Paint()..color = const Color(0xFF7F1D1D),
      );
    }

    canvas.restore(); // restore flip

    // Name tag + HP bar above reindeer
    final TextPainter nameTp = TextPainter(
      text: TextSpan(
        text: r.name,
        style: TextStyle(
          color: panicked ? const Color(0xFFFCA5A5) : Colors.white,
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nameTp.paint(canvas, Offset(-nameTp.width / 2, -88));

    // Mini health bar if damaged
    if (r.hp < r.maxHp) {
      const double barW = 30;
      canvas.drawRect(
        const Rect.fromLTWH(-barW / 2, -74, barW, 4),
        Paint()..color = Colors.black54,
      );
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, -74, barW * (r.hp / r.maxHp), 4),
        Paint()..color = kCrimsonRed,
      );
    }

    canvas.restore();
  }

  void _drawRudolphCommando(Canvas canvas, Size size) {
    final double cx = playerX * size.width;
    final double cy = playerY * size.height;

    const Color rudolphCoat = Color(0xFF9A5B25);
    const Color bellyCream = Color(0xFFF5E6C4);
    const Color darkHoof = Color(0xFF1A110B);
    const Color antlerColor = Color(0xFFE6CCB2);

    final Paint coatPaint = Paint()..color = rudolphCoat;
    final Paint bellyPaint = Paint()..color = bellyCream;
    final Paint outline = Paint()
      ..color = const Color(0xFF140C06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(cx, cy);

    // Ground shadow
    if (isGrounded) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 0), width: 54, height: 12),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
    }

    canvas.save();
    if (!facingRight) {
      canvas.scale(-1, 1);
    }

    final double legSwing = isGrounded ? sin(walkCycle) * 10.0 : 8.0;

    // Hind reindeer legs in heroic action stance
    void drawRudolphLeg(Offset hip, double swingOffset, bool isBack) {
      final Paint legP = Paint()
        ..color = isBack
            ? Color.lerp(rudolphCoat, Colors.black, 0.22)!
            : rudolphCoat
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round;
      final Offset knee = hip + Offset(swingOffset * 0.5, 12);
      final Offset hoof = knee + Offset(swingOffset * 0.7, 12);
      canvas.drawLine(hip, knee, legP);
      canvas.drawLine(knee, hoof, legP);
      canvas.drawRect(
        Rect.fromCenter(center: hoof, width: 8, height: 5),
        Paint()..color = darkHoof,
      );
    }

    drawRudolphLeg(const Offset(-12, -24), -legSwing, true);
    drawRudolphLeg(const Offset(10, -24), legSwing, true);

    // Fluffy white tail
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-23, -34), width: 12, height: 8),
      bellyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-23, -34), width: 12, height: 8),
      outline,
    );

    // Muscular reindeer lower body + upright commando chest
    final RRect lowerBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(-3, -30), width: 40, height: 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(lowerBody, coatPaint);
    canvas.drawRRect(lowerBody, outline);

    drawRudolphLeg(const Offset(-9, -24), legSwing, false);

    // Upright chest & neck
    final Path chestPath = Path()
      ..moveTo(-6, -34)
      ..lineTo(6, -58)
      ..lineTo(20, -54)
      ..lineTo(15, -26)
      ..close();
    canvas.drawPath(chestPath, coatPaint);
    canvas.drawPath(
      Path()
        ..moveTo(8, -54)
        ..lineTo(19, -52)
        ..lineTo(15, -30)
        ..lineTo(6, -32)
        ..close(),
      bellyPaint,
    );
    canvas.drawPath(chestPath, outline);

    // Tactical ammo bandolier across Rudolph's chest
    final Paint strapPaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 5.0;
    canvas.drawLine(const Offset(-3, -32), const Offset(15, -52), strapPaint);
    for (int b = 0; b < 4; b++) {
      final double t = b / 3.0;
      final Offset shellPos = Offset(-1 + t * 14, -34 - t * 16);
      canvas.drawCircle(
        shellPos,
        2.2,
        Paint()..color = const Color(0xFFFBBF24),
      );
    }

    // Large branching reindeer antlers ("Antlers covered in stains of their enemies")
    final Path antlerPath = Path()
      ..moveTo(7, -64)
      ..lineTo(-5, -86)
      ..moveTo(1, -74)
      ..lineTo(-9, -77)
      ..moveTo(-2, -80)
      ..lineTo(5, -88)
      ..moveTo(12, -64)
      ..lineTo(11, -89)
      ..moveTo(11, -75)
      ..lineTo(20, -80)
      ..moveTo(11, -82)
      ..lineTo(4, -90);

    canvas.drawPath(
      antlerPath,
      Paint()
        ..color = const Color(0xFF140C06)
        ..strokeWidth = 5.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      antlerPath,
      Paint()
        ..color = antlerColor
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Crimson blood stains on Rudolph's antlers when kills > 0
    if (kills > 0) {
      final Paint bloodAntler = Paint()
        ..color = kCrimsonRed
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final Path stainedTips = Path()
        ..moveTo(-1, -79)
        ..lineTo(-5, -86)
        ..moveTo(11, -81)
        ..lineTo(11, -89)
        ..moveTo(15, -77)
        ..lineTo(20, -80);
      canvas.drawPath(stainedTips, bloodAntler);
    }

    // Rudolph's head, ear, and Contra red commando headband with trailing tails
    final Path headbandTails = Path()
      ..moveTo(2, -60)
      ..quadraticBezierTo(-14, -64 + sin(worldTime * 12) * 4, -24, -56)
      ..moveTo(2, -57)
      ..quadraticBezierTo(-12, -57 + cos(worldTime * 12) * 4, -21, -50);
    canvas.drawPath(
      headbandTails,
      Paint()
        ..color = kCrimsonRed
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final Path headPath = Path()
      ..moveTo(3, -62)
      ..quadraticBezierTo(14, -68, 21, -60)
      ..lineTo(34, -56)
      ..quadraticBezierTo(36, -49, 27, -47)
      ..lineTo(8, -49)
      ..close();
    canvas.drawPath(headPath, coatPaint);
    canvas.drawPath(headPath, outline);

    // Red Contra headband across forehead
    canvas.drawLine(
      const Offset(4, -60),
      const Offset(21, -59),
      Paint()
        ..color = kCrimsonRed
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Fierce cartoon commando eye with angry brow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(17, -56), width: 7, height: 5.5),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(18.5, -56),
      2.0,
      Paint()..color = Colors.black,
    );
    canvas.drawLine(
      const Offset(13, -60),
      const Offset(21, -57),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2.2,
    );

    // Glowing Red Nose ("Please don't make light of a nose that's glowing")
    const Offset nosePos = Offset(34, -54);
    for (int g = 3; g >= 1; g--) {
      canvas.drawCircle(
        nosePos,
        4.5 + g * 4.5,
        Paint()..color = kNoseGlow.withValues(alpha: 0.14 * g),
      );
    }
    canvas.drawCircle(nosePos, 4.8, Paint()..color = const Color(0xFFFF002B));
    canvas.drawCircle(
      nosePos + const Offset(-1.2, -1.2),
      1.6,
      Paint()..color = Colors.white,
    );

    canvas.restore(); // restore horizontal flip so gun rotates accurately in world space

    // Draw Contra Heavy Assault Rifle / Twelve-Gauge aimed along aimAngle
    canvas.save();
    final double recoilPx = recoilOffset * size.width;
    canvas.translate(
      -cos(aimAngle) * recoilPx,
      -42 - sin(aimAngle) * recoilPx,
    );
    canvas.rotate(aimAngle);
    if (!facingRight) {
      canvas.scale(1, -1);
    }

    // Gun stock, receiver, barrel, and magazine
    final Paint gunMetal = Paint()..color = const Color(0xFF1E293B);
    final Paint gunHighlight = Paint()..color = const Color(0xFF64748B);
    // Stock
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -3, 14, 7),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF451A03),
    );
    // Receiver body
    canvas.drawRect(const Rect.fromLTWH(-2, -5, 22, 8), gunMetal);
    canvas.drawRect(const Rect.fromLTWH(0, -4, 18, 2.5), gunHighlight);
    // Curved banana magazine
    final Path magPath = Path()
      ..moveTo(6, 3)
      ..lineTo(12, 3)
      ..lineTo(15, 13)
      ..lineTo(8, 13)
      ..close();
    canvas.drawPath(magPath, Paint()..color = const Color(0xFF0F172A));
    // Heavy barrel + barrel shroud
    canvas.drawRect(const Rect.fromLTWH(20, -4, 16, 4.5), gunMetal);
    canvas.drawRect(
      const Rect.fromLTWH(20, -5, 18, 9),
      outline..strokeWidth = 1.6,
    );

    // Front hoof gripping the rifle handguard
    canvas.drawCircle(
      const Offset(14, 2),
      4.2,
      Paint()..color = darkHoof,
    );

    // Bright cartoon muzzle flash when firing
    if (muzzleFlashTimer > 0) {
      final Path flashPath = Path()
        ..moveTo(36, -2)
        ..lineTo(54, -10)
        ..lineTo(47, -2)
        ..lineTo(58, 0)
        ..lineTo(47, 3)
        ..lineTo(53, 10)
        ..close();
      canvas.drawPath(
        flashPath,
        Paint()..color = const Color(0xFFFef08a),
      );
      canvas.drawCircle(
        const Offset(39, -1),
        6,
        Paint()..color = Colors.white,
      );
    }

    canvas.restore();
    canvas.restore();
  }

  void _drawBullets(Canvas canvas, Size size) {
    for (final b in bullets) {
      final Offset pos = Offset(b.x * size.width, b.y * size.height);
      final double angle = atan2(b.vy, b.vx);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);

      // Glowing Contra energy/tracer shell
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, -3.2, 18, 6.4),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.45),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6, -2, 12, 4),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFFEF08A),
      );
      canvas.restore();
    }
  }

  void _drawBloodParticles(Canvas canvas, Size size) {
    for (final p in bloodParticles) {
      final Offset pos = Offset(p.x * size.width, p.y * size.height);
      final Paint bloodPaint = Paint()
        ..color = (p.isChunk ? kDarkBlood : kCrimsonRed).withValues(
          alpha: p.life.clamp(0.0, 1.0),
        );
      canvas.drawCircle(pos, p.radius, bloodPaint);
    }
  }

  void _drawFloatingTexts(Canvas canvas, Size size) {
    for (final ft in floatingTexts) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withValues(alpha: ft.life.clamp(0.0, 1.0)),
            fontFamily: 'JetBrainsMono',
            fontWeight: ft.isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: ft.isBold ? 14 : 12,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(ft.x * size.width - tp.width / 2, ft.y * size.height),
      );
    }
  }

  void _drawSnowfall(Canvas canvas, Size size) {
    final Paint snowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78);
    for (final f in snowflakes) {
      canvas.drawCircle(
        Offset(f.x * size.width, f.y * size.height),
        f.radius,
        snowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Platform {
  final double xMin;
  final double xMax;
  final double y;

  const _Platform({
    required this.xMin,
    required this.xMax,
    required this.y,
  });
}

class _Bullet {
  double x;
  double y;
  final double vx;
  final double vy;

  _Bullet({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });
}

class _ReindeerTarget {
  final String name;
  double x;
  double y;
  final double baseY;
  double vx;
  double vy;
  final bool isFlying;
  int hp;
  final int maxHp;
  final int furVariant;
  double legPhase;
  double hitFlash = 0.0;
  double panicTimer = 0.0;

  _ReindeerTarget({
    required this.name,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isFlying,
    required this.hp,
    required this.maxHp,
    required this.furVariant,
    required this.legPhase,
  }) : baseY = y;
}

class _BloodParticle {
  double x;
  double y;
  double vx;
  double vy;
  final double radius;
  double life;
  final bool isChunk;

  _BloodParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.life,
    this.isChunk = false,
  });
}

class _SnowStain {
  final double x;
  final double y;
  final double radiusX;
  final double radiusY;

  _SnowStain({
    required this.x,
    required this.y,
    required this.radiusX,
    required this.radiusY,
  });
}

class _ShellCasing {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;

  _ShellCasing({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
  });
}

class _FloatingText {
  final String text;
  final double x;
  double y;
  final Color color;
  double life;
  final bool isBold;

  _FloatingText({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    required this.life,
    this.isBold = false,
  });
}

class _HorizonCross {
  final double x;
  final double tilt;

  _HorizonCross({required this.x, required this.tilt});
}

class _Snowflake {
  double x;
  double y;
  final double radius;
  final double speedY;
  final double drift;
  final double phase;

  _Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedY,
    required this.drift,
    required this.phase,
  });
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double twinklePhase;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinklePhase,
  });
}
