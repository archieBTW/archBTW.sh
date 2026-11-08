import 'dart:async';
import 'dart:math';
import 'package:archbtw_sh/global/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum OceanItemType {
  krill,
  candy,
  anglerFish,
  coffeeCup,
  crab,
  rowboat,
  sailingShip,
  dessertIsland,
}

class WhaleGame extends StatefulWidget {
  const WhaleGame({super.key});

  @override
  State<WhaleGame> createState() => _WhaleGameState();
}

class _WhaleGameState extends State<WhaleGame>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FocusNode _focusNode = FocusNode();
  final Random _rng = Random();

  final List<String> _playlist = [
    'why_is_it_spicy.m4a',
    'whale_mail.wav',
    'ill_have_the_ribs_please.wav',
    'beached.wav',
    'sos.wav',
    'all_aboard_thats_going_aboard.wav',
    'we_just_need_to_budget_better.wav',
    'is_that_real_wool.m4a',
    'wheres_the_boat.wav',
    'specter.wav',
    'tightrope.wav',
    'i_swear_the_fish_was_this_big.wav',
    'spouted.wav',
    'before_the_before.wav',
  ];

  List<String> _musicQueue = [];
  StreamSubscription? _playerCompleteSubscription;

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _worldTime = 0.0;

  // 3D Ocean Arena bounds (-_worldRadius .. +_worldRadius on horizontal X and Z axes)
  static const double _worldRadius = 1100.0;

  // Whale state on the horizontal sea plane (X = east/west, Z = north/south)
  double _whaleX = 0.0;
  double _whaleZ = 0.0;
  double _whaleHeading = 0.0; // 0 = right/east, pi = left/west, -pi/2 = north, pi/2 = south
  double _whaleSpeed = 0.0;
  double _whaleMass = 10.0;
  double _displayScale = 1.0;
  double _mouthOpen = 0.25;
  double _tailPhase = 0.0;
  double _boostTimer = 0.0;
  double _boostCooldown = 0.0;

  // Level & Collection Goal (No time limit!)
  int _score = 0;
  int _level = 1;
  int _levelCollected = 0;
  int _levelGoal = 10;
  double _celebrationSpoutTimer = 0.0;

  // Input state (Keyboard + Touch Drag anywhere)
  final Set<LogicalKeyboardKey> _keysPressed = {};
  int? _dragPointerId;
  Offset _joystickOrigin = Offset.zero;
  Offset _joystickDelta = Offset.zero;

  // World entities & sea decorations
  final List<_OceanEntity> _entities = [];
  final List<_SwallowingEntity> _swallowing = [];
  final List<_WaterRipple> _ripples = [];
  final List<_SpoutDrop> _spoutDrops = [];
  final List<_FloatingScore> _floatingScores = [];
  late final List<_SeaDecoration> _seaDecorations;
  late final List<_WaveCrest> _waveCrests;

  double get _targetScale =>
      (1.0 + pow((_whaleMass - 10.0) / 24.0, 0.58) * 0.45).clamp(1.0, 4.5);

  int get _unlockedTier {
    if (_displayScale >= 2.35) return 4;
    if (_displayScale >= 1.75) return 3;
    if (_displayScale >= 1.30) return 2;
    return 1;
  }

  String get _sizeTitle {
    switch (_unlockedTier) {
      case 1:
        return 'KRILL GULPER';
      case 2:
        return 'ABYSS PROWLER';
      case 3:
        return 'BOAT SWALLOWER';
      default:
        return 'LEVIATHAN';
    }
  }

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _initSeaEnvironment();
    _spawnInitialWorld();

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _playerCompleteSubscription?.cancel();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _playNextTrack();
    });
    _playNextTrack();
  }

  Future<void> _playNextTrack() async {
    if (_playlist.isEmpty) return;
    if (_musicQueue.isEmpty) {
      _musicQueue = List.of(_playlist)..shuffle();
    }
    final nextSong = _musicQueue.removeAt(0);
    try {
      await _audioPlayer.setSource(AssetSource('music/blubber/$nextSong'));
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Audio Error: $e');
    }
  }

  void _initSeaEnvironment() {
    // Coral reefs, kelp forests, starfish, and sandbars across the seabed
    _seaDecorations = List.generate(75, (i) {
      return _SeaDecoration(
        x: (_rng.nextDouble() * 2 - 1) * _worldRadius,
        z: (_rng.nextDouble() * 2 - 1) * _worldRadius,
        kind: i % 4, // 0: kelp, 1: coral, 2: starfish, 3: sandbar/clam
        scale: 0.75 + _rng.nextDouble() * 0.7,
        phase: _rng.nextDouble() * pi * 2,
        colorIndex: _rng.nextInt(3),
      );
    });

    // Animated whitecap wave crests & seafoam across the surface
    _waveCrests = List.generate(65, (_) {
      return _WaveCrest(
        x: (_rng.nextDouble() * 2 - 1) * _worldRadius,
        z: (_rng.nextDouble() * 2 - 1) * _worldRadius,
        width: 28.0 + _rng.nextDouble() * 36.0,
        phase: _rng.nextDouble() * pi * 2,
      );
    });
  }

  void _resetGame() {
    setState(() {
      _whaleX = 0.0;
      _whaleZ = 0.0;
      _whaleHeading = 0.0;
      _whaleMass = 10.0;
      _displayScale = 1.0;
      _score = 0;
      _level = 1;
      _levelCollected = 0;
      _levelGoal = 10;
      _celebrationSpoutTimer = 0.0;
      _entities.clear();
      _swallowing.clear();
      _ripples.clear();
      _spoutDrops.clear();
      _floatingScores.clear();
      _spawnInitialWorld();
    });
  }

  void _spawnInitialWorld() {
    for (int i = 0; i < 38; i++) {
      _spawnEntityOfType(
        _rng.nextDouble() < 0.72 ? OceanItemType.krill : OceanItemType.candy,
        nearCenter: i < 16,
      );
    }
    for (int i = 0; i < 14; i++) {
      _spawnEntityOfType(
        i.isEven ? OceanItemType.anglerFish : OceanItemType.coffeeCup,
      );
    }
    for (int i = 0; i < 10; i++) {
      _spawnEntityOfType(
        i.isEven ? OceanItemType.crab : OceanItemType.rowboat,
      );
    }
    for (int i = 0; i < 7; i++) {
      _spawnEntityOfType(
        i.isEven ? OceanItemType.sailingShip : OceanItemType.dessertIsland,
      );
    }
  }

  void _spawnEntityOfType(OceanItemType type, {bool nearCenter = false}) {
    final double maxR = nearCenter ? 340.0 : (_worldRadius - 80.0);
    final double minR = nearCenter ? 75.0 : 120.0;
    final double angle = _rng.nextDouble() * pi * 2;
    final double dist = minR + _rng.nextDouble() * (maxR - minR);

    final double x = (_whaleX + cos(angle) * dist).clamp(
      -_worldRadius + 60,
      _worldRadius - 60,
    );
    final double z = (_whaleZ + sin(angle) * dist).clamp(
      -_worldRadius + 60,
      _worldRadius - 60,
    );

    double requiredScale;
    double radius;
    double massGain;
    int points;

    switch (type) {
      case OceanItemType.krill:
        requiredScale = 1.0;
        radius = 15.0;
        massGain = 1.8;
        points = 25;
        break;
      case OceanItemType.candy:
        requiredScale = 1.0;
        radius = 16.0;
        massGain = 2.1;
        points = 40;
        break;
      case OceanItemType.anglerFish:
        requiredScale = 1.30;
        radius = 25.0;
        massGain = 4.4;
        points = 100;
        break;
      case OceanItemType.coffeeCup:
        requiredScale = 1.30;
        radius = 24.0;
        massGain = 4.0;
        points = 90;
        break;
      case OceanItemType.crab:
        requiredScale = 1.75;
        radius = 35.0;
        massGain = 8.2;
        points = 220;
        break;
      case OceanItemType.rowboat:
        requiredScale = 1.75;
        radius = 38.0;
        massGain = 9.5;
        points = 250;
        break;
      case OceanItemType.sailingShip:
        requiredScale = 2.35;
        radius = 54.0;
        massGain = 18.0;
        points = 600;
        break;
      case OceanItemType.dessertIsland:
        requiredScale = 2.35;
        radius = 60.0;
        massGain = 22.0;
        points = 750;
        break;
    }

    final bool mobile =
        type == OceanItemType.krill ||
        type == OceanItemType.anglerFish ||
        type == OceanItemType.crab ||
        type == OceanItemType.rowboat;

    _entities.add(
      _OceanEntity(
        type: type,
        x: x,
        z: z,
        heading: _rng.nextDouble() * pi * 2,
        speed: mobile ? (16.0 + _rng.nextDouble() * 22.0) : 0.0,
        requiredScale: requiredScale,
        radius: radius,
        massGain: massGain,
        points: points,
        bobPhase: _rng.nextDouble() * pi * 2,
        colorVariant: _rng.nextInt(3),
      ),
    );
  }

  void _spawnBlowholeDrops(int count, {bool isLevelUp = false}) {
    final double blowX = _whaleX + cos(_whaleHeading) * (10.0 * _displayScale);
    final double blowZ = _whaleZ + sin(_whaleHeading) * (10.0 * _displayScale);
    for (int i = 0; i < count; i++) {
      final double a = _rng.nextDouble() * pi * 2;
      final double spd = (isLevelUp ? 40.0 : 25.0) +
          _rng.nextDouble() * (isLevelUp ? 95.0 : 55.0);
      _spoutDrops.add(
        _SpoutDrop(
          x: blowX,
          y: 28.0 * _displayScale,
          z: blowZ,
          vx: cos(a) * spd,
          vy: (isLevelUp ? 190.0 : 135.0) + _rng.nextDouble() * 110.0,
          vz: sin(a) * spd,
          life: (isLevelUp ? 0.95 : 0.65) + _rng.nextDouble() * 0.35,
          isCelebration: isLevelUp,
        ),
      );
    }
  }

  void _triggerBoost() {
    if (_boostCooldown > 0) return;
    setState(() {
      _boostTimer = 0.65;
      _boostCooldown = 1.5;
      _spawnBlowholeDrops(18);
    });
    HapticFeedback.lightImpact();
  }

  void _triggerLevelUpSpout() {
    _level++;
    _levelCollected = 0;
    _levelGoal = 10 + (_level - 1) * 4;
    _celebrationSpoutTimer = 2.6;
    _spawnBlowholeDrops(42, isLevelUp: true);

    _ripples.add(
      _WaterRipple(
        x: _whaleX,
        z: _whaleZ,
        radius: 20.0 * _displayScale,
        maxRadius: 110.0 * _displayScale,
        life: 1.2,
      ),
    );
    HapticFeedback.mediumImpact();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _keysPressed.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _triggerBoost();
      }
    } else if (event is KeyUpEvent) {
      _keysPressed.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
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
      if (_boostTimer > 0) _boostTimer = max(0, _boostTimer - dt);
      if (_boostCooldown > 0) _boostCooldown = max(0, _boostCooldown - dt);

      if (_celebrationSpoutTimer > 0) {
        _celebrationSpoutTimer = max(0, _celebrationSpoutTimer - dt);
        // Continuous fountain spray during the level-up spout celebration
        if (_rng.nextDouble() < 0.65) {
          _spawnBlowholeDrops(4, isLevelUp: true);
        }
      }

      _displayScale +=
          (_targetScale - _displayScale) * (dt * 4.5).clamp(0.0, 1.0);

      _updateWhaleMovement(dt);
      _updateEntitiesAndSwallowing(dt);
      _updateEffects(dt);
    });
  }

  void _updateWhaleMovement(double dt) {
    double inputX = 0.0;
    double inputZ = 0.0;

    if (_keysPressed.contains(LogicalKeyboardKey.keyA) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      inputX -= 1.0;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyD) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      inputX += 1.0;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyW) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      inputZ -= 1.0;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyS) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      inputZ += 1.0;
    }

    if (_dragPointerId != null && _joystickDelta.distance > 0.08) {
      inputX = _joystickDelta.dx;
      // Scale Z input to compensate for foreshortened sea plane so screen movement matches finger direction
      inputZ = _joystickDelta.dy / _Whale3DPainter.kSeaTilt;
    }

    final double inputMag = sqrt(inputX * inputX + inputZ * inputZ);
    final double maxSpeed =
        (205.0 + (_displayScale - 1.0) * 34.0) * (_boostTimer > 0 ? 1.65 : 1.0);

    if (inputMag > 0.05) {
      final double targetHeading = atan2(inputZ, inputX);
      double diff = targetHeading - _whaleHeading;
      while (diff > pi) {
        diff -= pi * 2;
      }
      while (diff < -pi) {
        diff += pi * 2;
      }
      _whaleHeading += diff * (dt * 9.5).clamp(0.0, 1.0);
      _whaleSpeed = maxSpeed * inputMag.clamp(0.25, 1.0);
    } else {
      _whaleSpeed *= pow(0.08, dt).toDouble();
    }

    _whaleX += cos(_whaleHeading) * _whaleSpeed * dt;
    _whaleZ += sin(_whaleHeading) * _whaleSpeed * dt;

    final double limit = _worldRadius - 50.0;
    _whaleX = _whaleX.clamp(-limit, limit);
    _whaleZ = _whaleZ.clamp(-limit, limit);

    _tailPhase += dt * (4.5 + (_whaleSpeed / 42.0));

    if (_whaleSpeed > 25.0 && _rng.nextDouble() < 0.35) {
      _ripples.add(
        _WaterRipple(
          x: _whaleX - cos(_whaleHeading) * 34.0 * _displayScale,
          z: _whaleZ - sin(_whaleHeading) * 34.0 * _displayScale,
          radius: 14.0 * _displayScale,
          maxRadius: 58.0 * _displayScale,
          life: 1.0,
        ),
      );
    }
  }

  void _updateEntitiesAndSwallowing(double dt) {
    final double mouthX = _whaleX + cos(_whaleHeading) * (28.0 * _displayScale);
    final double mouthZ = _whaleZ + sin(_whaleHeading) * (28.0 * _displayScale);
    final double swallowRadius = 48.0 * _displayScale;

    bool gulpingAny = false;
    final List<_OceanEntity> newlySwallowed = [];

    for (final e in _entities) {
      if (e.speed > 0) {
        e.x += cos(e.heading) * e.speed * dt;
        e.z += sin(e.heading) * e.speed * dt;
        if (e.x.abs() > _worldRadius - 65 || e.z.abs() > _worldRadius - 65) {
          e.heading += pi + (_rng.nextDouble() - 0.5) * 0.5;
        }
      }

      final double dx = e.x - mouthX;
      final double dz = e.z - mouthZ;
      final double dist = sqrt(dx * dx + dz * dz);

      final bool canEat = _displayScale + 0.02 >= e.requiredScale;

      if (canEat) {
        if (dist < swallowRadius * 1.45) {
          gulpingAny = true;
          final double pullSpeed = 245.0 * _displayScale;
          if (dist > 1.0) {
            e.x -= (dx / dist) * pullSpeed * dt;
            e.z -= (dz / dist) * pullSpeed * dt;
          }
        }
        if (dist < swallowRadius * 0.80) {
          newlySwallowed.add(e);
        }
      } else {
        final double minSep = 32.0 * _displayScale + e.radius * 0.7;
        final double bodyDx = e.x - _whaleX;
        final double bodyDz = e.z - _whaleZ;
        final double bodyDist = sqrt(bodyDx * bodyDx + bodyDz * bodyDz);
        if (bodyDist < minSep && bodyDist > 0.01) {
          final double push = (minSep - bodyDist) * 0.5;
          e.x += (bodyDx / bodyDist) * push;
          e.z += (bodyDz / bodyDist) * push;
        }
      }
    }

    for (final e in newlySwallowed) {
      _entities.remove(e);
      _swallowing.add(_SwallowingEntity(entity: e, progress: 0.0));
      _whaleMass += e.massGain;
      _score += e.points;
      _levelCollected++;

      _floatingScores.add(
        _FloatingScore(
          text: '+${e.points}',
          x: _whaleX,
          y: 35.0 * _displayScale,
          z: _whaleZ,
          life: 0.9,
        ),
      );

      _ripples.add(
        _WaterRipple(
          x: mouthX,
          z: mouthZ,
          radius: 10.0,
          maxRadius: 46.0 * _displayScale,
          life: 0.85,
        ),
      );

      // Check if we reached the collection goal for this level!
      if (_levelCollected >= _levelGoal) {
        _triggerLevelUpSpout();
      }
    }

    for (final s in _swallowing) {
      s.progress += dt * 3.4;
      gulpingAny = true;
    }
    _swallowing.removeWhere((s) => s.progress >= 1.0);

    final double targetMouth = gulpingAny ? 1.0 : 0.25;
    _mouthOpen += (targetMouth - _mouthOpen) * (dt * 10.0).clamp(0.0, 1.0);

    if (_entities.length < 38) {
      final int tier = _unlockedTier;
      if (_rng.nextDouble() < 0.55) {
        _spawnEntityOfType(
          _rng.nextBool() ? OceanItemType.krill : OceanItemType.candy,
        );
      } else if (tier >= 2 && _rng.nextDouble() < 0.5) {
        _spawnEntityOfType(
          _rng.nextBool() ? OceanItemType.anglerFish : OceanItemType.coffeeCup,
        );
      } else if (tier >= 3 && _rng.nextDouble() < 0.5) {
        _spawnEntityOfType(
          _rng.nextBool() ? OceanItemType.crab : OceanItemType.rowboat,
        );
      } else {
        _spawnEntityOfType(
          _rng.nextBool()
              ? OceanItemType.sailingShip
              : OceanItemType.dessertIsland,
        );
      }
    }
  }

  void _updateEffects(double dt) {
    for (final r in _ripples) {
      r.life -= dt * 1.1;
      r.radius += (r.maxRadius - r.radius) * dt * 3.2;
    }
    _ripples.removeWhere((r) => r.life <= 0);

    for (final d in _spoutDrops) {
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.z += d.vz * dt;
      d.vy -= 310.0 * dt;
      d.life -= dt;
    }
    _spoutDrops.removeWhere((d) => d.life <= 0 || d.y < 0);

    for (final fs in _floatingScores) {
      fs.y += 45.0 * dt;
      fs.life -= dt;
    }
    _floatingScores.removeWhere((fs) => fs.life <= 0);
  }

  @override
  Widget build(BuildContext context) {
    final double goalProgress =
        (_levelCollected / max(1, _levelGoal)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF044A7C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF032B4A),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'floppy_whale.sh',
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
            tooltip: 'Reset Ocean',
            onPressed: _resetGame,
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

            return Stack(
              fit: StackFit.expand,
              children: [
                // 3D Isometric/Perspective Ocean Canvas
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    _focusNode.requestFocus();
                    if (_dragPointerId == null) {
                      setState(() {
                        _dragPointerId = event.pointer;
                        _joystickOrigin = event.localPosition;
                        _joystickDelta = Offset.zero;
                      });
                    }
                  },
                  onPointerMove: (event) {
                    if (event.pointer == _dragPointerId) {
                      setState(() {
                        const double maxDrag = 60.0;
                        final Offset raw =
                            event.localPosition - _joystickOrigin;
                        final double dist = raw.distance;
                        if (dist > 0.001) {
                          final double clamped = min(dist, maxDrag);
                          _joystickDelta = (raw / dist) * (clamped / maxDrag);
                        } else {
                          _joystickDelta = Offset.zero;
                        }
                      });
                    }
                  },
                  onPointerUp: (event) {
                    if (event.pointer == _dragPointerId) {
                      setState(() {
                        _dragPointerId = null;
                        _joystickDelta = Offset.zero;
                      });
                    }
                  },
                  onPointerCancel: (event) {
                    if (event.pointer == _dragPointerId) {
                      setState(() {
                        _dragPointerId = null;
                        _joystickDelta = Offset.zero;
                      });
                    }
                  },
                  child: CustomPaint(
                    painter: _Whale3DPainter(
                      worldTime: _worldTime,
                      whaleX: _whaleX,
                      whaleZ: _whaleZ,
                      whaleHeading: _whaleHeading,
                      whaleScale: _displayScale,
                      mouthOpen: _mouthOpen,
                      tailPhase: _tailPhase,
                      celebrationSpoutTimer: _celebrationSpoutTimer,
                      entities: _entities,
                      swallowing: _swallowing,
                      ripples: _ripples,
                      spoutDrops: _spoutDrops,
                      floatingScores: _floatingScores,
                      seaDecorations: _seaDecorations,
                      waveCrests: _waveCrests,
                    ),
                  ),
                ),

                // Top HUD: Score, Size Class, and Level Collection Goal Bar (No Timer)
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF03233C).withValues(alpha: 0.82),
                            border: Border.all(
                              color: kAccentColor.withValues(alpha: 0.85),
                              width: 1.8,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SCORE: $_score  |  SIZE: ${_displayScale.toStringAsFixed(2)}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'JetBrainsMono',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'CLASS: $_sizeTitle (LVL $_level)',
                                style: const TextStyle(
                                  color: kAccentColor,
                                  fontFamily: 'JetBrainsMono',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'GOAL: $_levelCollected/$_levelGoal',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 110,
                                    height: 8,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: goalProgress,
                                        backgroundColor: Colors.white12,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF38BDF8),
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF03233C).withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            isCompact
                                ? 'DRAG ANYWHERE TO SWIM & GULP KRILL'
                                : 'DRAG / WASD / ARROWS: Swim & Gulp  |  SPACE: Spout Boost',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom-Right Spout Boost Button
                Positioned(
                  right: isCompact ? 18 : 28,
                  bottom: isCompact ? 20 : 28,
                  child: GestureDetector(
                    key: const Key('spout_boost_button'),
                    onTap: _triggerBoost,
                    child: Container(
                      width: isCompact ? 76 : 84,
                      height: isCompact ? 76 : 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _boostCooldown > 0
                            ? const Color(0xFF1E3A5F).withValues(alpha: 0.65)
                            : const Color(0xFF0284C7).withValues(alpha: 0.85),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withValues(
                              alpha: _boostCooldown > 0 ? 0.15 : 0.55,
                            ),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SPOUT',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'JetBrainsMono',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'BOOST',
                              style: TextStyle(
                                color: Colors.white70,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _ProjectedPoint {
  final Offset screen;
  final double scale;
  final double depth;

  const _ProjectedPoint({
    required this.screen,
    required this.scale,
    required this.depth,
  });
}

class _Whale3DPainter extends CustomPainter {
  // Horizontal sea-plane foreshortening factor (~36-degree elevated 3D view)
  static const double kSeaTilt = 0.58;

  final double worldTime;
  final double whaleX;
  final double whaleZ;
  final double whaleHeading;
  final double whaleScale;
  final double mouthOpen;
  final double tailPhase;
  final double celebrationSpoutTimer;
  final List<_OceanEntity> entities;
  final List<_SwallowingEntity> swallowing;
  final List<_WaterRipple> ripples;
  final List<_SpoutDrop> spoutDrops;
  final List<_FloatingScore> floatingScores;
  final List<_SeaDecoration> seaDecorations;
  final List<_WaveCrest> waveCrests;

  _Whale3DPainter({
    required this.worldTime,
    required this.whaleX,
    required this.whaleZ,
    required this.whaleHeading,
    required this.whaleScale,
    required this.mouthOpen,
    required this.tailPhase,
    required this.celebrationSpoutTimer,
    required this.entities,
    required this.swallowing,
    required this.ripples,
    required this.spoutDrops,
    required this.floatingScores,
    required this.seaDecorations,
    required this.waveCrests,
  });

  // Consistent 3D Horizontal Sea-Plane Projection:
  // (wx, wz) is the horizontal ocean plane, wy is vertical height above water.
  // Because wy always projects straight up (-dy) and (wx, wz) projects onto the
  // foreshortened horizontal plane, moving in any direction looks like swimming
  // across a flat 3D sea rather than swimming up and down!
  _ProjectedPoint _project(
    Size size,
    double wx,
    double wy,
    double wz,
  ) {
    final double camZoom = 1.0 / (0.88 + (whaleScale - 1.0) * 0.36);
    final double relX = (wx - whaleX) * camZoom;
    final double relZ = (wz - whaleZ) * camZoom;
    final double relY = wy * camZoom;

    // Gentle perspective depth factor across the horizontal plane
    const double focal = 1150.0;
    final double depth = (focal + relZ * 0.35).clamp(400.0, 2600.0);
    final double persp = focal / depth;

    final double sx = size.width * 0.5 + relX * persp;
    final double sy = size.height * 0.52 + (relZ * kSeaTilt - relY) * persp;

    return _ProjectedPoint(
      screen: Offset(sx, sy),
      scale: persp * camZoom,
      depth: depth,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawRichSeaEnvironment(canvas, size);
    _drawWaterRipples(canvas, size);

    // Depth-sorted 3D objects on the horizontal sea surface
    final List<_DepthDrawable> drawables = [];

    for (final e in entities) {
      final p = _project(size, e.x, 0, e.z);
      if (p.screen.dx < -130 ||
          p.screen.dx > size.width + 130 ||
          p.screen.dy < -130 ||
          p.screen.dy > size.height + 130) {
        continue;
      }
      drawables.add(
        _DepthDrawable(
          depth: p.depth,
          draw: (c) => _drawOceanEntity3D(c, size, e, p, swallowFactor: 0.0),
        ),
      );
    }

    for (final s in swallowing) {
      final double mouthX =
          whaleX + cos(whaleHeading) * (28.0 * whaleScale * (1.0 - s.progress * 0.5));
      final double mouthZ =
          whaleZ + sin(whaleHeading) * (28.0 * whaleScale * (1.0 - s.progress * 0.5));
      final double ix = s.entity.x + (mouthX - s.entity.x) * s.progress;
      final double iz = s.entity.z + (mouthZ - s.entity.z) * s.progress;
      final double iy = -16.0 * s.progress;
      final p = _project(size, ix, iy, iz);
      drawables.add(
        _DepthDrawable(
          depth: p.depth - 2.0,
          draw: (c) => _drawOceanEntity3D(
            c,
            size,
            s.entity,
            p,
            swallowFactor: s.progress,
          ),
        ),
      );
    }

    final double breachHop = celebrationSpoutTimer > 0
        ? sin(celebrationSpoutTimer * 7.5).abs() * 14.0 * whaleScale
        : 0.0;
    final whaleProj = _project(size, whaleX, breachHop, whaleZ);
    drawables.add(
      _DepthDrawable(
        depth: whaleProj.depth,
        draw: (c) => _draw3DCartoonWhale(c, size, whaleProj, breachHop),
      ),
    );

    drawables.sort((a, b) => b.depth.compareTo(a.depth));
    for (final d in drawables) {
      d.draw(canvas);
    }

    _drawSpoutDrops(canvas, size);
    _drawFloatingScores(canvas, size);
  }

  void _drawRichSeaEnvironment(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;

    // 1. Vibrant tropical/temperate cartoon ocean water gradient
    final Paint seaGrad = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF03406A),
          Color(0xFF056699),
          Color(0xFF0883B8),
          Color(0xFF045380),
        ],
        stops: [0.0, 0.35, 0.72, 1.0],
      ).createShader(full);
    canvas.drawRect(full, seaGrad);

    // 2. Submerged seabed reefs, swaying kelp, coral & starfish (parallaxes at wy = -48)
    for (final dec in seaDecorations) {
      final p = _project(size, dec.x, -48.0, dec.z);
      if (p.screen.dx < -90 ||
          p.screen.dx > size.width + 90 ||
          p.screen.dy < -90 ||
          p.screen.dy > size.height + 90) {
        continue;
      }
      final double s = p.scale * dec.scale;
      final Offset c = p.screen;

      if (dec.kind == 0) {
        // Swaying underwater kelp fronds
        final Paint kelpPaint = Paint()
          ..color = const Color(0xFF0D9488).withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0 * s
          ..strokeCap = StrokeCap.round;
        for (int frond = -1; frond <= 1; frond++) {
          final double sway = sin(worldTime * 2.2 + dec.phase + frond) * 8.0 * s;
          final Path kPath = Path()
            ..moveTo(c.dx + frond * 8 * s, c.dy)
            ..quadraticBezierTo(
              c.dx + frond * 8 * s + sway,
              c.dy - 18 * s,
              c.dx + frond * 10 * s - sway * 0.5,
              c.dy - 36 * s,
            );
          canvas.drawPath(kPath, kelpPaint);
        }
      } else if (dec.kind == 1) {
        // Submerged coral reef cluster
        final Color coralColor = dec.colorIndex == 0
            ? const Color(0xFFF43F5E)
            : (dec.colorIndex == 1
                ? const Color(0xFFF97316)
                : const Color(0xFFA855F7));
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 38 * s, height: 22 * s),
          Paint()..color = coralColor.withValues(alpha: 0.25),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c + Offset(8 * s, -4 * s),
            width: 22 * s,
            height: 14 * s,
          ),
          Paint()..color = coralColor.withValues(alpha: 0.32),
        );
      } else if (dec.kind == 2) {
        // Seafloor starfish silhouette
        final Path star = Path();
        for (int pIdx = 0; pIdx < 10; pIdx++) {
          final double a = dec.phase + pIdx * pi / 5;
          final double r = (pIdx.isEven ? 14.0 : 6.0) * s;
          final Offset pt = c + Offset(cos(a) * r, sin(a) * r * kSeaTilt);
          if (pIdx == 0) {
            star.moveTo(pt.dx, pt.dy);
          } else {
            star.lineTo(pt.dx, pt.dy);
          }
        }
        star.close();
        canvas.drawPath(
          star,
          Paint()..color = const Color(0xFFFBBF24).withValues(alpha: 0.24),
        );
      } else {
        // Shimmering caustic ring on the water surface
        final double pulse = 1.0 + 0.15 * sin(worldTime * 2.0 + dec.phase);
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: 56 * s * pulse,
            height: 56 * s * kSeaTilt * pulse,
          ),
          Paint()
            ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * s,
        );
      }
    }

    // 3. Animated cartoon ocean wave crests & seafoam on the water plane (wy = 0)
    final Paint wavePaint = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (final wc in waveCrests) {
      final double driftX = wc.x + sin(worldTime * 0.8 + wc.phase) * 18.0;
      final p = _project(size, driftX, 0, wc.z);
      if (p.screen.dx < -80 ||
          p.screen.dx > size.width + 80 ||
          p.screen.dy < -80 ||
          p.screen.dy > size.height + 80) {
        continue;
      }
      final double w = wc.width * p.scale;
      final Offset c = p.screen;
      final Path crest = Path()
        ..moveTo(c.dx - w * 0.5, c.dy)
        ..quadraticBezierTo(c.dx - w * 0.25, c.dy - 5 * p.scale, c.dx, c.dy)
        ..quadraticBezierTo(
          c.dx + w * 0.25,
          c.dy - 5 * p.scale,
          c.dx + w * 0.5,
          c.dy,
        );
      canvas.drawPath(crest, wavePaint);
    }
  }

  void _drawWaterRipples(Canvas canvas, Size size) {
    for (final r in ripples) {
      final p = _project(size, r.x, 0, r.z);
      final double rx = r.radius * p.scale;
      final double ry = rx * kSeaTilt;
      canvas.drawOval(
        Rect.fromCenter(center: p.screen, width: rx * 2, height: ry * 2),
        Paint()
          ..color = Colors.white.withValues(
            alpha: (r.life * 0.45).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  void _drawOceanEntity3D(
    Canvas canvas,
    Size size,
    _OceanEntity e,
    _ProjectedPoint p, {
    required double swallowFactor,
  }) {
    final double s = p.scale * (1.0 - swallowFactor * 0.78);
    if (s <= 0.02) return;

    final double bob = sin(worldTime * 3.2 + e.bobPhase) * 3.0 * s;
    final Offset pos = p.screen + Offset(0, bob);
    final bool isEdible = whaleScale + 0.02 >= e.requiredScale;

    final Paint outline = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.2 * s).clamp(1.2, 3.2);

    // Shadow on the seabed below
    final _ProjectedPoint shadowProj = _project(size, e.x, -26, e.z);
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowProj.screen,
        width: e.radius * 1.6 * s,
        height: e.radius * 1.6 * kSeaTilt * s,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );

    // Horizontal waterline ring showing whether item is currently edible
    if (swallowFactor == 0.0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: p.screen + Offset(0, 3 * s),
          width: e.radius * 2.1 * s,
          height: e.radius * 2.1 * kSeaTilt * s,
        ),
        Paint()
          ..color = isEdible
              ? const Color(0xFF4ADE80).withValues(alpha: 0.42)
              : const Color(0xFFF87171).withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    switch (e.type) {
      case OceanItemType.krill:
        for (int k = 0; k < 3; k++) {
          final Offset offset = Offset(
            (k - 1) * 10 * s,
            (k == 1 ? -4 : 3) * s,
          );
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          final RRect body = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 15 * s, height: 8 * s),
            Radius.circular(4 * s),
          );
          canvas.drawRRect(body, Paint()..color = const Color(0xFFFB7185));
          canvas.drawRRect(body, outline);
          canvas.drawCircle(
            Offset(5 * s, -1.5 * s),
            1.8 * s,
            Paint()..color = Colors.black,
          );
          canvas.restore();
        }
        break;

      case OceanItemType.candy:
        final RRect candyRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 24 * s, height: 14 * s),
          Radius.circular(5 * s),
        );
        canvas.drawRRect(
          candyRect,
          Paint()
            ..color = e.colorVariant == 0
                ? const Color(0xFFE11D48)
                : const Color(0xFFA855F7),
        );
        canvas.drawRRect(candyRect, outline);
        canvas.drawCircle(
          Offset(-4 * s, -2 * s),
          2.5 * s,
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
        break;

      case OceanItemType.anglerFish:
        final RRect fishBody = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 38 * s, height: 26 * s),
          Radius.circular(13 * s),
        );
        canvas.drawRRect(fishBody, Paint()..color = const Color(0xFF312E81));
        canvas.drawRRect(fishBody, outline);
        final Path stalk = Path()
          ..moveTo(8 * s, -11 * s)
          ..quadraticBezierTo(20 * s, -26 * s, 24 * s, -15 * s);
        canvas.drawPath(stalk, outline);
        canvas.drawCircle(
          Offset(24 * s, -15 * s),
          6.5 * s,
          Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.45),
        );
        canvas.drawCircle(
          Offset(24 * s, -15 * s),
          3.5 * s,
          Paint()..color = const Color(0xFFFEF08A),
        );
        canvas.drawCircle(
          Offset(9 * s, -4 * s),
          4.2 * s,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(10 * s, -4 * s),
          2.0 * s,
          Paint()..color = Colors.black,
        );
        break;

      case OceanItemType.coffeeCup:
        final RRect cup = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 26 * s, height: 28 * s),
          Radius.circular(5 * s),
        );
        canvas.drawRRect(cup, Paint()..color = const Color(0xFFEF4444));
        canvas.drawRRect(cup, outline);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -11 * s),
            width: 24 * s,
            height: 8 * s,
          ),
          Paint()..color = const Color(0xFF3E2723),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -11 * s),
            width: 24 * s,
            height: 8 * s,
          ),
          outline,
        );
        break;

      case OceanItemType.crab:
        final RRect shell = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 46 * s, height: 28 * s),
          Radius.circular(14 * s),
        );
        canvas.drawRRect(shell, Paint()..color = const Color(0xFFEA580C));
        canvas.drawRRect(shell, outline);
        canvas.drawCircle(
          Offset(-24 * s, -11 * s),
          8.5 * s,
          Paint()..color = const Color(0xFFDC2626),
        );
        canvas.drawCircle(Offset(-24 * s, -11 * s), 8.5 * s, outline);
        canvas.drawCircle(
          Offset(24 * s, -11 * s),
          8.5 * s,
          Paint()..color = const Color(0xFFDC2626),
        );
        canvas.drawCircle(Offset(24 * s, -11 * s), 8.5 * s, outline);
        canvas.drawCircle(
          Offset(-8 * s, -15 * s),
          4 * s,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(8 * s, -15 * s),
          4 * s,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(-8 * s, -15 * s),
          1.8 * s,
          Paint()..color = Colors.black,
        );
        canvas.drawCircle(
          Offset(8 * s, -15 * s),
          1.8 * s,
          Paint()..color = Colors.black,
        );
        break;

      case OceanItemType.rowboat:
        final Path hull = Path()
          ..moveTo(-34 * s, -6 * s)
          ..lineTo(34 * s, -6 * s)
          ..lineTo(24 * s, 13 * s)
          ..lineTo(-24 * s, 13 * s)
          ..close();
        canvas.drawPath(hull, Paint()..color = const Color(0xFF92400E));
        canvas.drawPath(hull, outline);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -6 * s),
            width: 66 * s,
            height: 15 * s,
          ),
          Paint()..color = const Color(0xFFD97706),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -6 * s),
            width: 66 * s,
            height: 15 * s,
          ),
          outline,
        );
        break;

      case OceanItemType.sailingShip:
        final Path shipHull = Path()
          ..moveTo(-48 * s, 0)
          ..lineTo(48 * s, 0)
          ..lineTo(34 * s, 20 * s)
          ..lineTo(-34 * s, 20 * s)
          ..close();
        canvas.drawPath(shipHull, Paint()..color = const Color(0xFF78350F));
        canvas.drawPath(shipHull, outline);
        canvas.drawLine(
          Offset.zero,
          Offset(0, -54 * s),
          Paint()
            ..color = const Color(0xFF451A03)
            ..strokeWidth = 4 * s,
        );
        final Path sail = Path()
          ..moveTo(0, -50 * s)
          ..quadraticBezierTo(34 * s, -28 * s, 0, -10 * s)
          ..close();
        canvas.drawPath(sail, Paint()..color = Colors.white);
        canvas.drawPath(sail, outline);
        break;

      case OceanItemType.dessertIsland:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, 6 * s),
            width: 92 * s,
            height: 42 * s,
          ),
          Paint()..color = const Color(0xFFFDE68A),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, 6 * s),
            width: 92 * s,
            height: 42 * s,
          ),
          outline,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(0, 4 * s),
            width: 72 * s,
            height: 50 * s,
          ),
          pi,
          pi,
          true,
          Paint()..color = const Color(0xFFF472B6),
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(0, 4 * s),
            width: 72 * s,
            height: 50 * s,
          ),
          pi,
          pi,
          true,
          outline,
        );
        canvas.drawCircle(
          Offset(0, -24 * s),
          8.5 * s,
          Paint()..color = const Color(0xFFE11D48),
        );
        canvas.drawCircle(Offset(0, -24 * s), 8.5 * s, outline);
        break;
    }

    canvas.restore();
  }

  void _draw3DCartoonWhale(
    Canvas canvas,
    Size size,
    _ProjectedPoint whaleProj,
    double breachHop,
  ) {
    final double s = whaleProj.scale * whaleScale;
    final Offset center = whaleProj.screen;

    // Deep 3D shadow on the ocean floor beneath the whale
    final _ProjectedPoint shadowProj = _project(size, whaleX, -32, whaleZ);
    canvas.save();
    canvas.translate(shadowProj.screen.dx, shadowProj.screen.dy);
    canvas.rotate(whaleHeading);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 115 * s, height: 64 * s),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(whaleHeading);

    const Color whaleBlue = Color(0xFF1D4ED8);
    const Color whaleHighlight = Color(0xFF60A5FA);
    const Color whaleBelly = Color(0xFFE0F2FE);
    const Color mawDark = Color(0xFF090D16);
    const Color tonguePink = Color(0xFFFB7185);

    final Paint outline = Paint()
      ..color = const Color(0xFF0B132B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.8 * s).clamp(1.8, 4.2)
      ..strokeJoin = StrokeJoin.round;

    // Animated swishing tail fluke behind body
    final double tailWag = sin(tailPhase) * 14.0 * s;
    final Path tailPath = Path()
      ..moveTo(-42 * s, 0)
      ..quadraticBezierTo(-64 * s, tailWag * 0.5, -78 * s, tailWag - 18 * s)
      ..quadraticBezierTo(-70 * s, tailWag, -82 * s, tailWag)
      ..quadraticBezierTo(-70 * s, tailWag, -78 * s, tailWag + 18 * s)
      ..quadraticBezierTo(-64 * s, tailWag * 0.5, -42 * s, 0)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = whaleBlue);
    canvas.drawPath(tailPath, outline);

    // Side pectoral flippers
    final Path leftFlipper = Path()
      ..moveTo(-6 * s, -24 * s)
      ..quadraticBezierTo(-22 * s, -48 * s, -4 * s, -44 * s)
      ..quadraticBezierTo(8 * s, -34 * s, 6 * s, -22 * s)
      ..close();
    final Path rightFlipper = Path()
      ..moveTo(-6 * s, 24 * s)
      ..quadraticBezierTo(-22 * s, 48 * s, -4 * s, 44 * s)
      ..quadraticBezierTo(8 * s, 34 * s, 6 * s, -22 * s)
      ..close();
    canvas.drawPath(leftFlipper, Paint()..color = whaleBlue);
    canvas.drawPath(leftFlipper, outline);
    canvas.drawPath(rightFlipper, Paint()..color = whaleBlue);
    canvas.drawPath(rightFlipper, outline);

    // Plump 3D shaded cartoon whale body
    final RRect bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 106 * s, height: 64 * s),
      Radius.circular(32 * s),
    );
    final Paint bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.35),
        radius: 0.95,
        colors: const [whaleHighlight, whaleBlue, Color(0xFF1E3A8A)],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Light pleated ventral belly grooves near front
    canvas.drawArc(
      Rect.fromCenter(center: Offset(8 * s, 0), width: 82 * s, height: 54 * s),
      -0.65,
      1.3,
      false,
      Paint()..color = whaleBelly.withValues(alpha: 0.85),
    );
    canvas.drawRRect(bodyRect, outline);

    // Gaping Hole-Buster Whale Mouth Vortex at the front!
    final double mawWidth = (28.0 + mouthOpen * 16.0) * s;
    final double mawHeight = (34.0 + mouthOpen * 18.0) * s;
    final Rect mawRect = Rect.fromCenter(
      center: Offset(32 * s, 0),
      width: mawWidth,
      height: mawHeight,
    );

    canvas.drawOval(mawRect, Paint()..color = mawDark);

    for (int ring = 1; ring <= 2; ring++) {
      canvas.drawOval(
        mawRect.deflate(ring * 5.0 * s),
        Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s,
      );
    }

    canvas.drawArc(
      mawRect.deflate(3 * s),
      0.4,
      2.3,
      false,
      Paint()..color = tonguePink,
    );
    canvas.drawOval(mawRect, outline);

    // Expressive cartoon whale eyes on either side of the head
    void drawWhaleEye(Offset eyePos) {
      canvas.drawCircle(eyePos, 6.2 * s, Paint()..color = Colors.white);
      canvas.drawCircle(eyePos, 6.2 * s, outline);
      canvas.drawCircle(
        eyePos + Offset(1.8 * s, 0),
        3.0 * s,
        Paint()..color = Colors.black,
      );
      canvas.drawCircle(
        eyePos + Offset(2.5 * s, -1.2 * s),
        1.1 * s,
        Paint()..color = Colors.white,
      );
    }

    drawWhaleEye(Offset(14 * s, -22 * s));
    drawWhaleEye(Offset(14 * s, 22 * s));

    // Dorsal blowhole on top of head with specular shine
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-4 * s, -4 * s),
        width: 9 * s,
        height: 5 * s,
      ),
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-18 * s, -12 * s),
        width: 26 * s,
        height: 10 * s,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );

    canvas.restore();

    // Celebratory Level-Up Water Spout Fountain Animation shooting up from blowhole!
    if (celebrationSpoutTimer > 0) {
      final Offset blowholeWorldScreen = center +
          Offset(
            (-4 * cos(whaleHeading) + 4 * sin(whaleHeading)) * s,
            (-4 * sin(whaleHeading) - 4 * cos(whaleHeading)) * s,
          );
      _drawCelebrationSpoutGeyser(canvas, blowholeWorldScreen, s);
    }
  }

  void _drawCelebrationSpoutGeyser(
    Canvas canvas,
    Offset blowholePos,
    double s,
  ) {
    final double pulse = 0.85 + 0.15 * sin(worldTime * 18.0);
    final double spoutHeight = 95.0 * s * pulse;
    final Offset topCenter = blowholePos - Offset(0, spoutHeight);

    // Subtle rainbow arc in the mist when spouting!
    final Rect rainbowRect = Rect.fromCenter(
      center: blowholePos - Offset(0, spoutHeight * 0.45),
      width: 90 * s,
      height: 55 * s,
    );
    final List<Color> rainbowColors = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF38BDF8),
    ];
    for (int i = 0; i < rainbowColors.length; i++) {
      canvas.drawArc(
        rainbowRect.inflate(i * 3.5 * s),
        pi + 0.3,
        pi - 0.6,
        false,
        Paint()
          ..color = rainbowColors[i].withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * s
          ..strokeCap = StrokeCap.round,
      );
    }

    // Central pressurized water column shooting straight up from blowhole
    final Path columnPath = Path()
      ..moveTo(blowholePos.dx - 4 * s, blowholePos.dy)
      ..quadraticBezierTo(
        blowholePos.dx - 7 * s,
        blowholePos.dy - spoutHeight * 0.6,
        topCenter.dx - 22 * s,
        topCenter.dy,
      )
      ..quadraticBezierTo(
        topCenter.dx,
        topCenter.dy - 16 * s,
        topCenter.dx + 22 * s,
        topCenter.dy,
      )
      ..quadraticBezierTo(
        blowholePos.dx + 7 * s,
        blowholePos.dy - spoutHeight * 0.6,
        blowholePos.dx + 4 * s,
        blowholePos.dy,
      )
      ..close();

    canvas.drawPath(
      columnPath,
      Paint()..color = const Color(0xFFE0F2FE).withValues(alpha: 0.92),
    );
    canvas.drawPath(
      columnPath,
      Paint()
        ..color = const Color(0xFF0284C7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s,
    );

    // Twin curling fountain arches at the top of the geyser
    final Paint archPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 * s
      ..strokeCap = StrokeCap.round;

    for (final double side in [-1.0, 1.0]) {
      final Path arch = Path()
        ..moveTo(topCenter.dx, topCenter.dy)
        ..quadraticBezierTo(
          topCenter.dx + side * 34 * s,
          topCenter.dy - 18 * s,
          topCenter.dx + side * 48 * s,
          topCenter.dy + 26 * s,
        );
      canvas.drawPath(arch, archPaint);
    }
  }

  void _drawSpoutDrops(Canvas canvas, Size size) {
    for (final d in spoutDrops) {
      final p = _project(size, d.x, d.y, d.z);
      final Paint dropPaint = Paint()
        ..color = (d.isCelebration
                ? const Color(0xFF7DD3FC)
                : const Color(0xFFE0F2FE))
            .withValues(alpha: d.life.clamp(0.0, 1.0));
      canvas.drawCircle(
        p.screen,
        ((d.isCelebration ? 5.0 : 4.0) * p.scale).clamp(1.8, 7.0),
        dropPaint,
      );
    }
  }

  void _drawFloatingScores(Canvas canvas, Size size) {
    for (final fs in floatingScores) {
      final p = _project(size, fs.x, fs.y, fs.z);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: fs.text,
          style: TextStyle(
            color: const Color(0xFF4ADE80).withValues(
              alpha: fs.life.clamp(0.0, 1.0),
            ),
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p.screen - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SeaDecoration {
  final double x;
  final double z;
  final int kind;
  final double scale;
  final double phase;
  final int colorIndex;

  const _SeaDecoration({
    required this.x,
    required this.z,
    required this.kind,
    required this.scale,
    required this.phase,
    required this.colorIndex,
  });
}

class _WaveCrest {
  final double x;
  final double z;
  final double width;
  final double phase;

  const _WaveCrest({
    required this.x,
    required this.z,
    required this.width,
    required this.phase,
  });
}

class _DepthDrawable {
  final double depth;
  final void Function(Canvas canvas) draw;

  _DepthDrawable({required this.depth, required this.draw});
}

class _OceanEntity {
  final OceanItemType type;
  double x;
  double z;
  double heading;
  final double speed;
  final double requiredScale;
  final double radius;
  final double massGain;
  final int points;
  final double bobPhase;
  final int colorVariant;

  _OceanEntity({
    required this.type,
    required this.x,
    required this.z,
    required this.heading,
    required this.speed,
    required this.requiredScale,
    required this.radius,
    required this.massGain,
    required this.points,
    required this.bobPhase,
    required this.colorVariant,
  });
}

class _SwallowingEntity {
  final _OceanEntity entity;
  double progress;

  _SwallowingEntity({required this.entity, required this.progress});
}

class _WaterRipple {
  final double x;
  final double z;
  double radius;
  final double maxRadius;
  double life;

  _WaterRipple({
    required this.x,
    required this.z,
    required this.radius,
    required this.maxRadius,
    required this.life,
  });
}

class _SpoutDrop {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  double life;
  final bool isCelebration;

  _SpoutDrop({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.life,
    this.isCelebration = false,
  });
}

class _FloatingScore {
  final String text;
  final double x;
  double y;
  final double z;
  double life;

  _FloatingScore({
    required this.text,
    required this.x,
    required this.y,
    required this.z,
    required this.life,
  });
}
