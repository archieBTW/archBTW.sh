import 'dart:async';
import 'dart:math';

import 'package:archbtw_sh/games/gamepad_poller.dart';
import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/global/site_music_controller.dart';
import 'package:archbtw_sh/widgets/in_game_music_hud.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum OkcPowerupType {
  pill,
  guitar,
  spider,
  pigeon,
}

enum OkcZombieKind {
  walker,
  runner,
  brute,
}

enum OkcAttackKind {
  none,
  punch,
  kick,
  chord,
}

class OkcPlatform {
  final double xMin;
  final double xMax;
  final double elevation; // height above street ground (virtual world px)
  final int style; // 0: brick ledge, 1: steel girder fire escape, 2: streetcar canopy

  const OkcPlatform({
    required this.xMin,
    required this.xMax,
    required this.elevation,
    this.style = 0,
  });
}

class OkcBuilding {
  final double x;
  final double width;
  final double height;
  final Color color;
  final Color trimColor;
  final String? neonSign;
  final Color neonColor;
  final int windowRows;
  final int windowCols;
  final bool isBrick;

  const OkcBuilding({
    required this.x,
    required this.width,
    required this.height,
    required this.color,
    required this.trimColor,
    this.neonSign,
    required this.neonColor,
    required this.windowRows,
    required this.windowCols,
    required this.isBrick,
  });
}

class OkcZombie {
  final int id;
  final OkcZombieKind kind;
  double x;
  double y; // elevation above ground
  double vx;
  double vy;
  int hp;
  final int maxHp;
  bool facingRight;
  double walkPhase;
  double hurtTimer;
  double attackCooldown;
  final double patrolMinX;
  final double patrolMaxX;

  OkcZombie({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.vx,
    this.vy = 0.0,
    required this.hp,
    required this.maxHp,
    this.facingRight = false,
    this.walkPhase = 0.0,
    this.hurtTimer = 0.0,
    this.attackCooldown = 0.0,
    required this.patrolMinX,
    required this.patrolMaxX,
  });
}

class OkcPowerupItem {
  final int id;
  final OkcPowerupType type;
  double x;
  double y; // elevation above ground
  final double baseY;
  double bobPhase;
  bool collected;

  OkcPowerupItem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.bobPhase,
    this.collected = false,
  }) : baseY = y;
}

class OkcChordProjectile {
  double x;
  double y;
  final double vx;
  final double vy;
  final String chordName;
  double life;
  final Color color;
  final Set<int> hitZombieIds = {};

  OkcChordProjectile({
    required this.x,
    required this.y,
    required this.vx,
    this.vy = 0.0,
    required this.chordName,
    this.life = 1.4,
    required this.color,
  });
}

class OkcParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final Color color;
  final double size;

  OkcParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
    this.size = 5.0,
  }) : maxLife = life;
}

class OkcFloatingPopup {
  double x;
  double y;
  final String text;
  final Color color;
  double life;

  OkcFloatingPopup({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.life = 1.25,
  });
}

class OkcLevelMap {
  final int level;
  final int seed;
  final String districtName;
  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color neonAccent;
  final double levelLength;
  final double tortieCatX;
  final double catFoodX;
  final double gooseSpawnX;
  final List<OkcPlatform> platforms;
  final List<Offset> webAnchors; // (worldX, elevationY)
  final List<OkcBuilding> buildings;

  const OkcLevelMap({
    required this.level,
    required this.seed,
    required this.districtName,
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.neonAccent,
    required this.levelLength,
    required this.tortieCatX,
    required this.catFoodX,
    required this.gooseSpawnX,
    required this.platforms,
    required this.webAnchors,
    required this.buildings,
  });
}

class OkcBeatEmUpGame extends StatefulWidget {
  const OkcBeatEmUpGame({super.key});

  @override
  State<OkcBeatEmUpGame> createState() => OkcBeatEmUpGameState();
}

class OkcBeatEmUpGameState extends State<OkcBeatEmUpGame>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _masterRng = Random();

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _worldTime = 0.0;

  // Physics constants (virtual 8-bit world coordinates; y=0 is street ground, y>0 is up)
  static const double _gravity = 1320.0;
  static const double _baseMoveSpeed = 265.0;
  static const double _gooseSpeedMultiplier = 1.32;
  static const double _baseJumpVelocity = 575.0;
  static const double _gooseJumpMultiplier = 1.18;

  // Combined tracklist from "life's lemons" and "blubber", shuffled!
  static const List<String> _lemonsAndBlubberTracks = [
    // life's lemons
    'lemons/it_seemed_like_a_good_idea_at_the_time.m4a',
    'lemons/elixir.m4a',
    'lemons/third_times_a_charm.m4a',
    'lemons/i_may_not_be_a_smart_man_but_i_know_what_love_is.m4a',
    'lemons/almost_intelligent.m4a',
    'lemons/midnight_oil.m4a',
    'lemons/crosstops.m4a',
    'lemons/and_thats_how_it_happened.m4a',
    'lemons/c_u_next_tuesday.m4a',
    'lemons/drinking_outta_cups.m4a',
    'lemons/you_call_this_mercy.m4a',
    'lemons/florence.m4a',
    'lemons/lets_take_it_apart_and_put_it_back_together.m4a',
    // blubber
    'blubber/why_is_it_spicy.m4a',
    'blubber/whale_mail.m4a',
    'blubber/ill_have_the_ribs_please.m4a',
    'blubber/beached.m4a',
    'blubber/sos.m4a',
    'blubber/all_aboard_thats_going_aboard.m4a',
    'blubber/we_just_need_to_budget_better.m4a',
    'blubber/is_that_real_wool.m4a',
    'blubber/i_dont_like_you_very_much.m4a',
    'blubber/wheres_the_boat.m4a',
    'blubber/specter.m4a',
    'blubber/tightrope.m4a',
    'blubber/i_swear_the_fish_was_this_big.m4a',
    'blubber/spouted.m4a',
    'blubber/before_the_before.m4a',
  ];

  late List<String> _playlist;
  int _currentTrackIndex = 0;
  bool _isMusicPlaying = true;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  // Level & Procedural Map state
  int _level = 1;
  int _mapSeed = 405;
  int _mapGenerationCount = 0;
  late OkcLevelMap _currentMap;

  // Player (archBTW) state
  double _playerX = 160.0;
  double _playerY = 0.0;
  double _playerVx = 0.0;
  double _playerVy = 0.0;
  bool _facingRight = true;
  bool _isGrounded = true;
  int _jumpsRemaining = 2;
  double _walkCycle = 0.0;

  int _health = 100;
  static const int _maxHealth = 100;
  int _lives = 3;
  int _score = 0;
  int _zombiesDefeated = 0;
  int _combo = 0;
  double _comboTimer = 0.0;
  double _invulnerableTimer = 0.0;
  double _screenShakeTimer = 0.0;
  bool _isGameOver = false;

  // Combat state (Punch, Kick, Guitar Chords)
  OkcAttackKind _currentAttack = OkcAttackKind.none;
  double _attackTimer = 0.0;
  double _attackCooldown = 0.0;
  int _chordCycleIndex = 0;
  static const List<String> _powerChords = [
    'E5',
    'A5',
    'D5',
    'G5',
    'C#5',
    'F#5',
  ];

  // Powerup states
  bool _hasGuitar = false; // "Fireflower" style equipped purple PRS guitar
  bool _hasSpiderPower = false; // Enables swinging from overhead webs

  // Spider Web-Swinging state
  bool _isWebSwinging = false;
  Offset? _activeWebAnchor; // (worldX, elevationY)
  double _webRopeLength = 135.0;
  double _webAngle = 0.0; // radians from vertical down
  double _webAngularVel = 0.0;
  double _webSwingTimer = 0.0;

  // Goose (White Pitbull/Corgi Mix — Yoshi-style mount)
  bool _isRidingGoose = false;
  double _gooseX = 310.0;
  double _gooseY = 0.0;
  double _gooseVx = 0.0;
  bool _gooseFacingRight = true;
  double _gooseRemountCooldown = 0.0;
  double _gooseChompTimer = 0.0;
  double _gooseWalkCycle = 0.0;

  // Tortie Cat (start of level) & Cat Food (end of level)
  bool _hasCatFood = false;
  bool _tortieCatFed = false;
  double _levelClearBannerTimer = 0.0;

  // Entities in current level
  final List<OkcZombie> _zombies = [];
  final List<OkcPowerupItem> _powerups = [];
  final List<OkcChordProjectile> _chordProjectiles = [];
  final List<OkcParticle> _particles = [];
  final List<OkcFloatingPopup> _popups = [];
  int _nextEntityId = 1;

  // Camera & Viewport Scaling
  double _cameraX = 0.0;
  double _lastWorldScale = 1.0;

  // Input state: Keyboard + Touch Joystick/Buttons + Gamepad Controller
  final Set<LogicalKeyboardKey> _keysPressed = {};
  int? _joystickPointerId;
  Offset _joystickCenter = Offset.zero;
  Offset _joystickDelta = Offset.zero;

  bool _touchJumpHeld = false;
  bool _touchPunchHeld = false;
  bool _touchKickHeld = false;
  bool _touchChordHeld = false;
  bool _touchWebHeld = false;

  GamepadInputState _gamepadState = GamepadInputState.disconnected;
  GamepadInputState _prevGamepadState = GamepadInputState.disconnected;
  GamepadInputState? _injectedGamepadState;

  // Public getters for inspection and testing
  int get level => _level;
  int get mapSeed => _mapSeed;
  int get mapGenerationCount => _mapGenerationCount;
  String get currentDistrict => _currentMap.districtName;
  OkcLevelMap get currentMap => _currentMap;
  int get health => _health;
  int get maxHealth => _maxHealth;
  int get lives => _lives;
  int get score => _score;
  int get zombiesDefeated => _zombiesDefeated;
  bool get isRidingGoose => _isRidingGoose;
  bool get hasGuitar => _hasGuitar;
  bool get hasSpiderPower => _hasSpiderPower;
  bool get isWebSwinging => _isWebSwinging;
  bool get hasCatFood => _hasCatFood;
  bool get tortieCatFed => _tortieCatFed;
  bool get isGameOver => _isGameOver;
  double get playerX => _playerX;
  double get playerY => _playerY;
  double get gooseX => _gooseX;
  double get gooseY => _gooseY;
  double get tortieCatX => _currentMap.tortieCatX;
  double get catFoodX => _currentMap.catFoodX;
  double get worldScale => _lastWorldScale;
  List<String> get playlist => List.unmodifiable(_playlist);
  OkcAttackKind get currentAttack => _currentAttack;
  List<OkcZombie> get zombies => _zombies;
  List<OkcPowerupItem> get powerups => _powerups;
  List<OkcChordProjectile> get chordProjectiles => _chordProjectiles;
  bool get isControllerConnected => _gamepadState.connected;

  @override
  void initState() {
    super.initState();
    _playlist = List<String>.from(_lemonsAndBlubberTracks)..shuffle(_masterRng);
    _generateAndLoadLevel(1, seed: 40501);
    _setupAudioPlayer();

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    SiteMusicController.instance.exitGame();
    _ticker.dispose();
    _focusNode.dispose();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    SiteMusicController.instance.enterGame();
    configureBackgroundAudioContext();
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _playNextTrack();
    });
    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isMusicPlaying = state == PlayerState.playing;
        });
      }
    });
    _playTrackAt(0);
  }

  Future<void> _playTrackAt(int index) async {
    if (_playlist.isEmpty) return;
    int wrapped = index;
    if (wrapped >= _playlist.length) {
      // Re-shuffle when completing a pass through the shuffled playlist
      _playlist.shuffle(_masterRng);
      wrapped = 0;
    } else if (wrapped < 0) {
      wrapped = (_playlist.length + (wrapped % _playlist.length)) %
          _playlist.length;
    }
    if (mounted) {
      setState(() {
        _currentTrackIndex = wrapped;
        _isMusicPlaying = true;
      });
    }
    final String trackRelPath = _playlist[wrapped];
    try {
      await _audioPlayer.setSource(AssetSource('music/$trackRelPath'));
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Audio Error: $e');
    }
  }

  Future<void> _playNextTrack() async {
    await _playTrackAt(_currentTrackIndex + 1);
  }

  Future<void> _playPreviousTrack() async {
    await _playTrackAt(_currentTrackIndex - 1);
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isMusicPlaying) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isMusicPlaying = false);
      } else {
        await _audioPlayer.resume();
        if (mounted) setState(() => _isMusicPlaying = true);
      }
    } catch (e) {
      debugPrint('Audio Toggle Error: $e');
    }
  }

  // --- Procedural 8-Bit Downtown OKC Map Generator ---
  static const List<String> _okcDistricts = [
    'BRICKTOWN CANAL // OKC',
    'FILM ROW & SHERIDAN // OKC',
    'MIDTOWN & AUTO ALLEY // OKC',
    'DEEP DEUCE & SCISSORTAIL // OKC',
    'PASEO & UPTOWN 23RD // OKC',
  ];

  static const List<String> _okcNeonLabels = [
    'BRICKTOWN',
    'TOWER THEATRE',
    'OKC 405',
    'ARCHBTW.SH',
    'DEVON TOWER',
    'FILM ROW',
    'MIDTOWN',
    'SONIC OKC',
    'DEEP DEUCE',
  ];

  void _generateAndLoadLevel(int newLevel, {int? seed}) {
    _level = newLevel;
    _mapGenerationCount++;
    _mapSeed = seed ??
        (_masterRng.nextInt(900000) +
            newLevel * 1337 +
            _mapGenerationCount * 97);
    final Random rng = Random(_mapSeed);

    final int districtIdx =
        (newLevel - 1 + rng.nextInt(_okcDistricts.length)) %
            _okcDistricts.length;
    final String districtName = _okcDistricts[districtIdx];

    // Authentic 8-Bit NES night palette bands
    final List<Color> skyTops = const [
      Color(0xFF000020),
      Color(0xFF000828),
      Color(0xFF140024),
      Color(0xFF001418),
      Color(0xFF180400),
    ];
    final List<Color> skyMids = const [
      Color(0xFF100840),
      Color(0xFF0C1C54),
      Color(0xFF280848),
      Color(0xFF082830),
      Color(0xFF301018),
    ];
    final List<Color> skyBottoms = const [
      Color(0xFF241464),
      Color(0xFF183478),
      Color(0xFF441468),
      Color(0xFF144048),
      Color(0xFF481C24),
    ];
    final List<Color> neonAccents = const [
      Color(0xFFB878F8),
      Color(0xFF3CBCFC),
      Color(0xFFF83870),
      Color(0xFF58F898),
      Color(0xFFF8B800),
    ];

    final double levelLength = 2400.0 + (newLevel - 1) * 200.0;
    const double tortieCatX = 95.0;
    final double catFoodX = levelLength - 150.0;
    final double gooseSpawnX = 275.0 + rng.nextDouble() * 55.0;

    // Generate multi-tiered Downtown OKC 8-bit platforms
    final List<OkcPlatform> platforms = [];
    double cursorX = 230.0;
    while (cursorX < levelLength - 280.0) {
      final double width = 128.0 + (rng.nextInt(5) * 24.0);
      final double elevation = 72.0 + (rng.nextInt(3) * 48.0);
      final int style = rng.nextInt(3);
      platforms.add(
        OkcPlatform(
          xMin: cursorX,
          xMax: cursorX + width,
          elevation: elevation,
          style: style,
        ),
      );

      // Occasionally add an upper rooftop/fire-escape tier above
      if (rng.nextDouble() < 0.45) {
        final double upperW = 96.0 + (rng.nextInt(3) * 24.0);
        platforms.add(
          OkcPlatform(
            xMin: cursorX + 16.0,
            xMax: cursorX + 16.0 + upperW,
            elevation: elevation + 72.0,
            style: 1,
          ),
        );
      }

      cursorX += width + 88.0 + rng.nextDouble() * 96.0;
    }

    // Generate overhead web anchors (streetlights, neon sign brackets, skybridge beams)
    final List<Offset> webAnchors = [];
    for (double ax = 200.0;
        ax < levelLength - 120.0;
        ax += 160.0 + rng.nextDouble() * 60.0) {
      webAnchors.add(Offset(ax, 240.0 + rng.nextDouble() * 44.0));
    }

    // Generate Downtown OKC 8-bit streetscape buildings
    final List<OkcBuilding> buildings = [];
    double bx = -80.0;
    int signIdx = rng.nextInt(_okcNeonLabels.length);
    while (bx < levelLength + 200.0) {
      final double bw = 112.0 + (rng.nextInt(4) * 24.0);
      final double bh = 160.0 + (rng.nextInt(6) * 24.0);
      final bool isBrick = rng.nextBool();
      final Color bColor = isBrick
          ? const Color(0xFF681818)
          : const Color(0xFF182038);
      final Color trimColor = isBrick
          ? const Color(0xFFA83020)
          : const Color(0xFF384870);
      final String? neon = rng.nextDouble() < 0.60
          ? _okcNeonLabels[(signIdx++) % _okcNeonLabels.length]
          : null;
      final Color neonCol =
          neonAccents[(signIdx + districtIdx) % neonAccents.length];

      buildings.add(
        OkcBuilding(
          x: bx,
          width: bw,
          height: bh,
          color: bColor,
          trimColor: trimColor,
          neonSign: neon,
          neonColor: neonCol,
          windowRows: (bh / 32).floor().clamp(3, 8),
          windowCols: (bw / 28).floor().clamp(2, 5),
          isBrick: isBrick,
        ),
      );
      bx += bw + 12.0 + (rng.nextInt(3) * 8.0);
    }

    _currentMap = OkcLevelMap(
      level: newLevel,
      seed: _mapSeed,
      districtName: districtName,
      skyTop: skyTops[districtIdx],
      skyMid: skyMids[districtIdx],
      skyBottom: skyBottoms[districtIdx],
      neonAccent: neonAccents[districtIdx],
      levelLength: levelLength,
      tortieCatX: tortieCatX,
      catFoodX: catFoodX,
      gooseSpawnX: gooseSpawnX,
      platforms: platforms,
      webAnchors: webAnchors,
      buildings: buildings,
    );

    // Reset player position to start of the newly generated level
    _playerX = 155.0;
    _playerY = 0.0;
    _playerVx = 0.0;
    _playerVy = 0.0;
    _facingRight = true;
    _isGrounded = true;
    _jumpsRemaining = 2;
    _isWebSwinging = false;
    _activeWebAnchor = null;
    _hasCatFood = false;
    _tortieCatFed = false;
    _cameraX = 0.0;

    if (!_isRidingGoose) {
      _gooseX = gooseSpawnX;
      _gooseY = 0.0;
      _gooseVx = 0.0;
      _gooseFacingRight = true;
      _gooseRemountCooldown = 0.0;
    } else {
      _gooseX = _playerX;
      _gooseY = _playerY;
    }

    // Spawn Powerups: Guarantee Guitar, Spider, Pills, and Pigeons in EVERY level!
    _powerups.clear();
    _chordProjectiles.clear();
    _particles.clear();

    // 1. Guitar Powerup ("Fireflower" chord weapon)
    final double guitarX = 390.0 + rng.nextDouble() * 80.0;
    _powerups.add(
      OkcPowerupItem(
        id: _nextEntityId++,
        type: OkcPowerupType.guitar,
        x: guitarX,
        y: _elevationAt(guitarX, platforms) + 28.0,
        bobPhase: rng.nextDouble() * pi * 2,
      ),
    );

    // 2. Spider Powerup (Web-swinging ability)
    final double spiderX = 520.0 + rng.nextDouble() * 80.0;
    _powerups.add(
      OkcPowerupItem(
        id: _nextEntityId++,
        type: OkcPowerupType.spider,
        x: spiderX,
        y: _elevationAt(spiderX, platforms) + 28.0,
        bobPhase: rng.nextDouble() * pi * 2,
      ),
    );

    // 3. Health Pills along the level
    for (int i = 0; i < 4; i++) {
      final double pillX =
          450.0 + i * ((levelLength - 700.0) / 4.0) + rng.nextDouble() * 80.0;
      _powerups.add(
        OkcPowerupItem(
          id: _nextEntityId++,
          type: OkcPowerupType.pill,
          x: pillX,
          y: _elevationAt(pillX, platforms) + 24.0,
          bobPhase: rng.nextDouble() * pi * 2,
        ),
      );
    }

    // 4. Pigeons (+1 Life)
    for (int i = 0; i < 2; i++) {
      final double pigeonX =
          640.0 + i * ((levelLength - 900.0) / 2.0) + rng.nextDouble() * 110.0;
      final double baseElev = _elevationAt(pigeonX, platforms);
      _powerups.add(
        OkcPowerupItem(
          id: _nextEntityId++,
          type: OkcPowerupType.pigeon,
          x: pigeonX,
          y: max(84.0, baseElev + 36.0),
          bobPhase: rng.nextDouble() * pi * 2,
        ),
      );
    }

    // Spawn Downtown OKC Zombies
    _zombies.clear();
    final int zombieCount = 9 + newLevel * 3;
    for (int i = 0; i < zombieCount; i++) {
      final double zx = 430.0 +
          (i / zombieCount) * (levelLength - 650.0) +
          rng.nextDouble() * 70.0;
      final double roll = rng.nextDouble();
      final OkcZombieKind kind = roll < 0.50
          ? OkcZombieKind.walker
          : (roll < 0.82 ? OkcZombieKind.runner : OkcZombieKind.brute);

      final bool onPlat = rng.nextDouble() < 0.35;
      OkcPlatform? chosenPlat;
      if (onPlat) {
        for (final p in platforms) {
          if (zx >= p.xMin && zx <= p.xMax) {
            chosenPlat = p;
            break;
          }
        }
      }

      final int maxHp = kind == OkcZombieKind.walker
          ? 45
          : (kind == OkcZombieKind.runner ? 35 : 95);
      final double speed = kind == OkcZombieKind.walker
          ? 48.0 + rng.nextDouble() * 18.0
          : (kind == OkcZombieKind.runner
              ? 88.0 + rng.nextDouble() * 25.0
              : 34.0 + rng.nextDouble() * 12.0);

      _zombies.add(
        OkcZombie(
          id: _nextEntityId++,
          kind: kind,
          x: zx,
          y: chosenPlat?.elevation ?? 0.0,
          vx: (rng.nextBool() ? 1.0 : -1.0) * speed,
          hp: maxHp,
          maxHp: maxHp,
          facingRight: false,
          walkPhase: rng.nextDouble() * pi * 2,
          patrolMinX: chosenPlat != null
              ? chosenPlat.xMin + 14.0
              : max(350.0, zx - 160.0),
          patrolMaxX: chosenPlat != null
              ? chosenPlat.xMax - 14.0
              : min(levelLength - 180.0, zx + 160.0),
        ),
      );
    }

    _popups.add(
      OkcFloatingPopup(
        x: _playerX,
        y: 105.0,
        text: 'STAGE $_level: ${_currentMap.districtName}',
        color: _currentMap.neonAccent,
        life: 2.0,
      ),
    );
  }

  double _elevationAt(double worldX, List<OkcPlatform> platforms) {
    double best = 0.0;
    for (final p in platforms) {
      if (worldX >= p.xMin && worldX <= p.xMax) {
        if (p.elevation > best) best = p.elevation;
      }
    }
    return best;
  }

  void resetFullGame() {
    setState(() {
      _health = _maxHealth;
      _lives = 3;
      _score = 0;
      _zombiesDefeated = 0;
      _combo = 0;
      _comboTimer = 0.0;
      _hasGuitar = false;
      _hasSpiderPower = false;
      _isRidingGoose = false;
      _isGameOver = false;
      _playlist.shuffle(_masterRng);
      _generateAndLoadLevel(1);
    });
  }

  // --- Player Combat & Powerup Actions ---

  void triggerJump() {
    if (_isGameOver) return;
    if (_isWebSwinging) {
      releaseWebSwing(launchBoost: true);
      return;
    }
    if (_isGrounded || _jumpsRemaining > 0) {
      final double jumpMult = _isRidingGoose ? _gooseJumpMultiplier : 1.0;
      setState(() {
        _playerVy = _baseJumpVelocity * jumpMult;
        _isGrounded = false;
        if (_jumpsRemaining > 0) _jumpsRemaining--;
      });
    }
  }

  void triggerPunch() {
    if (_isGameOver || _attackCooldown > 0.0) return;
    setState(() {
      _currentAttack = OkcAttackKind.punch;
      _attackTimer = 0.22;
      _attackCooldown = 0.16;
      if (_isRidingGoose) {
        _gooseChompTimer = 0.26;
      }
      _performMeleeStrike(
        reach: _isRidingGoose ? 88.0 : 72.0,
        damage: _isRidingGoose ? 35 : 25,
        knockbackX: 165.0,
        knockbackY: 140.0,
        hitLabel: _isRidingGoose ? 'POW! + GOOSE CHOMP!' : 'POW!',
      );
      if (_hasGuitar) {
        _spawnChordProjectile();
      }
    });
  }

  void triggerKick() {
    if (_isGameOver) return;
    if (_currentAttack == OkcAttackKind.kick && _attackCooldown > 0.0) return;
    setState(() {
      _currentAttack = OkcAttackKind.kick;
      _attackTimer = 0.30;
      _attackCooldown = 0.24;
      if (_isRidingGoose) {
        _gooseChompTimer = 0.28;
      }
      _playerVx = (_facingRight ? 1.0 : -1.0) * 140.0;
      _performMeleeStrike(
        reach: _isRidingGoose ? 102.0 : 88.0,
        damage: _isRidingGoose ? 50 : 40,
        knockbackX: 280.0,
        knockbackY: 220.0,
        hitLabel: 'ROUNDHOUSE KICK!',
      );
    });
  }

  void triggerChordAttack() {
    if (_isGameOver) return;
    if (!_hasGuitar) {
      triggerPunch();
      return;
    }
    if (_attackCooldown > 0.0) return;
    setState(() {
      _currentAttack = OkcAttackKind.chord;
      _attackTimer = 0.26;
      _attackCooldown = 0.20;
      _spawnChordProjectile();
    });
  }

  void _spawnChordProjectile() {
    final String chordName =
        _powerChords[(_chordCycleIndex++) % _powerChords.length];
    final double dir = _facingRight ? 1.0 : -1.0;
    final List<Color> chordColors = const [
      Color(0xFFB878F8),
      Color(0xFF3CBCFC),
      Color(0xFFF83870),
      Color(0xFFF8B800),
    ];
    final Color cColor = chordColors[_chordCycleIndex % chordColors.length];

    _chordProjectiles.add(
      OkcChordProjectile(
        x: _playerX + dir * 28.0,
        y: _playerY + (_isRidingGoose ? 54.0 : 40.0),
        vx: dir * 480.0,
        chordName: chordName,
        color: cColor,
      ),
    );
  }

  void triggerWebSwing() {
    if (_isGameOver) return;
    if (!_hasSpiderPower) {
      _popups.add(
        OkcFloatingPopup(
          x: _playerX,
          y: _playerY + 80.0,
          text: 'NEED SPIDER POWERUP!',
          color: const Color(0xFFF83870),
          life: 0.9,
        ),
      );
      return;
    }
    if (_isWebSwinging) return;

    final double dir = _facingRight ? 1.0 : -1.0;
    Offset? bestAnchor;
    double bestScore = double.infinity;

    for (final anchor in _currentMap.webAnchors) {
      final double dx = anchor.dx - _playerX;
      if (dx * dir >= -30.0 && dx.abs() <= 260.0) {
        final double score = (dx - dir * 95.0).abs();
        if (score < bestScore) {
          bestScore = score;
          bestAnchor = anchor;
        }
      }
    }

    bestAnchor ??= Offset(
      (_playerX + dir * 95.0).clamp(60.0, _currentMap.levelLength - 60.0),
      max(245.0, _playerY + 140.0),
    );

    setState(() {
      _isWebSwinging = true;
      _activeWebAnchor = bestAnchor;
      _isGrounded = false;
      _webSwingTimer = 0.0;
      if (_playerY < 45.0) {
        _playerY = 45.0;
      }
      final double dx = _playerX - bestAnchor!.dx;
      final double dy = bestAnchor.dy - _playerY;
      _webRopeLength = sqrt(dx * dx + dy * dy).clamp(90.0, 175.0);
      _webAngle = atan2(dx, max(20.0, dy));
      _webAngularVel = dir * 3.35;

      _popups.add(
        OkcFloatingPopup(
          x: _playerX,
          y: _playerY + 82.0,
          text: 'THWIP! WEB SWING!',
          color: const Color(0xFF3CBCFC),
          life: 0.85,
        ),
      );
    });
  }

  void releaseWebSwing({bool launchBoost = false}) {
    if (!_isWebSwinging) return;
    final double dir = _facingRight ? 1.0 : -1.0;
    setState(() {
      _isWebSwinging = false;
      _activeWebAnchor = null;
      _playerVx = dir * (launchBoost ? 390.0 : 320.0);
      _playerVy = launchBoost ? 450.0 : 280.0;
      _jumpsRemaining = 1;
    });
  }

  void mountGoose() {
    setState(() {
      _isRidingGoose = true;
      _gooseX = _playerX;
      _gooseY = _playerY;
      _gooseRemountCooldown = 0.0;
      _popups.add(
        OkcFloatingPopup(
          x: _playerX,
          y: _playerY + 86.0,
          text: 'RIDING GOOSE! (WOOF!)',
          color: const Color(0xFFF8B800),
        ),
      );
    });
  }

  void dismountGoose() {
    if (!_isRidingGoose) return;
    setState(() {
      _isRidingGoose = false;
      _gooseX = _playerX - (_facingRight ? 36.0 : -36.0);
      _gooseY = _playerY;
      _gooseRemountCooldown = 1.2;
      _playerVy = 280.0;
      _isGrounded = false;
    });
  }

  void collectPowerup(OkcPowerupType type, {double? atX, double? atY}) {
    final double px = atX ?? _playerX;
    final double py = (atY ?? _playerY) + 64.0;

    setState(() {
      switch (type) {
        case OkcPowerupType.pill:
          _health = min(_maxHealth, _health + 30);
          _score += 100;
          _popups.add(
            OkcFloatingPopup(
              x: px,
              y: py,
              text: 'PILL +30 HP!',
              color: const Color(0xFF58F898),
            ),
          );
          break;
        case OkcPowerupType.guitar:
          _hasGuitar = true;
          _score += 250;
          _popups.add(
            OkcFloatingPopup(
              x: px,
              y: py,
              text: 'GUITAR EQUIPPED! POWER CHORDS!',
              color: const Color(0xFFB878F8),
            ),
          );
          break;
        case OkcPowerupType.spider:
          _hasSpiderPower = true;
          _score += 250;
          _popups.add(
            OkcFloatingPopup(
              x: px,
              y: py,
              text: 'SPIDER POWER! WEB SWING!',
              color: const Color(0xFF3CBCFC),
            ),
          );
          break;
        case OkcPowerupType.pigeon:
          _lives += 1;
          _score += 300;
          _popups.add(
            OkcFloatingPopup(
              x: px,
              y: py,
              text: '1-UP! PIGEON +1 LIFE!',
              color: const Color(0xFFF8B800),
            ),
          );
          break;
      }
      _spawnBurstParticles(px, py - 24.0, const Color(0xFFF8B800), count: 12);
    });
  }

  void completeCurrentLevel() {
    setState(() {
      _hasCatFood = true;
      _tortieCatFed = true;
      _score += 500 * _level;
      _health = min(_maxHealth, _health + 25);
      _levelClearBannerTimer = 1.8;
      _generateAndLoadLevel(_level + 1);
    });
  }

  void applyControllerInput(GamepadInputState gamepad) {
    _injectedGamepadState = gamepad;
    _processGamepadEdges(gamepad);
  }

  void _processGamepadEdges(GamepadInputState pad) {
    if (!pad.connected) {
      _prevGamepadState = pad;
      return;
    }
    if (pad.jumpPressed && !_prevGamepadState.jumpPressed) {
      triggerJump();
    }
    if (pad.punchPressed && !_prevGamepadState.punchPressed) {
      triggerPunch();
    }
    if (pad.kickPressed && !_prevGamepadState.kickPressed) {
      triggerKick();
    }
    if (pad.chordPressed && !_prevGamepadState.chordPressed) {
      triggerChordAttack();
    }
    if (pad.webPressed && !_prevGamepadState.webPressed) {
      triggerWebSwing();
    } else if (!pad.webPressed &&
        _prevGamepadState.webPressed &&
        _isWebSwinging) {
      releaseWebSwing();
    }
    if (pad.mountPressed && !_prevGamepadState.mountPressed) {
      if (_isRidingGoose) {
        dismountGoose();
      } else if ((_playerX - _gooseX).abs() < 85.0) {
        mountGoose();
      }
    }
    _prevGamepadState = pad;
  }

  void _performMeleeStrike({
    required double reach,
    required int damage,
    required double knockbackX,
    required double knockbackY,
    required String hitLabel,
  }) {
    final double dir = _facingRight ? 1.0 : -1.0;
    final double hitMinX = _facingRight ? _playerX - 18.0 : _playerX - reach;
    final double hitMaxX = _facingRight ? _playerX + reach : _playerX + 18.0;

    bool hitAny = false;
    for (final z in _zombies) {
      if (z.hp <= 0) continue;
      final bool inX = z.x >= hitMinX && z.x <= hitMaxX;
      final bool inY = (z.y - _playerY).abs() <= 72.0;
      if (inX && inY) {
        _damageZombie(
          z,
          damage: damage,
          knockVx: dir * knockbackX,
          knockVy: knockbackY,
        );
        hitAny = true;
      }
    }

    if (hitAny) {
      _screenShakeTimer = 0.12;
      _popups.add(
        OkcFloatingPopup(
          x: _playerX + dir * 42.0,
          y: _playerY + 72.0,
          text: hitLabel,
          color: const Color(0xFFF8B800),
          life: 0.65,
        ),
      );
    }
  }

  void _damageZombie(
    OkcZombie z, {
    required int damage,
    required double knockVx,
    required double knockVy,
  }) {
    z.hp -= damage;
    z.hurtTimer = 0.22;
    z.vx = knockVx;
    z.vy = knockVy;
    _combo++;
    _comboTimer = 2.5;
    _spawnBurstParticles(z.x, z.y + 36.0, const Color(0xFF58F898), count: 10);

    if (z.hp <= 0) {
      _zombiesDefeated++;
      final int pts = (z.kind == OkcZombieKind.brute ? 250 : 100) *
          max(1, min(_combo, 6));
      _score += pts;
      _popups.add(
        OkcFloatingPopup(
          x: z.x,
          y: z.y + 58.0,
          text: '+$pts KO!',
          color: const Color(0xFFF83870),
        ),
      );
      if (z.kind == OkcZombieKind.brute) {
        _powerups.add(
          OkcPowerupItem(
            id: _nextEntityId++,
            type: OkcPowerupType.pill,
            x: z.x,
            y: max(0.0, z.y) + 20.0,
            bobPhase: 0.0,
          ),
        );
      }
    }
  }

  void _spawnBurstParticles(
    double wx,
    double wy,
    Color color, {
    int count = 8,
  }) {
    for (int i = 0; i < count; i++) {
      final double angle = (i / count) * pi * 2 + _masterRng.nextDouble() * 0.5;
      final double speed = 60.0 + _masterRng.nextDouble() * 140.0;
      _particles.add(
        OkcParticle(
          x: wx,
          y: wy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed + 60.0,
          life: 0.35 + _masterRng.nextDouble() * 0.25,
          color: color,
          size: 4.0 + _masterRng.nextInt(3) * 2.0,
        ),
      );
    }
  }

  void _onPlayerDamaged(int dmg, double sourceX) {
    if (_invulnerableTimer > 0.0 || _isGameOver) return;

    // Yoshi-style Goose protection!
    if (_isRidingGoose) {
      _isRidingGoose = false;
      _invulnerableTimer = 1.25;
      _gooseRemountCooldown = 1.6;
      _gooseX = _playerX + (_playerX >= sourceX ? -48.0 : 48.0);
      _gooseY = _playerY;
      _gooseVx = (_playerX >= sourceX ? -1.0 : 1.0) * 140.0;
      _playerVy = 320.0;
      _isGrounded = false;
      _screenShakeTimer = 0.18;
      _popups.add(
        OkcFloatingPopup(
          x: _playerX,
          y: _playerY + 84.0,
          text: 'GOOSE TOOK THE HIT! HOP BACK ON!',
          color: const Color(0xFFF8B800),
        ),
      );
      return;
    }

    _health -= dmg;
    _invulnerableTimer = 1.05;
    _screenShakeTimer = 0.18;
    _playerVx = (_playerX >= sourceX ? 1.0 : -1.0) * 210.0;
    _playerVy = 250.0;
    _isGrounded = false;
    _spawnBurstParticles(
      _playerX,
      _playerY + 36.0,
      const Color(0xFFF83870),
      count: 12,
    );

    if (_health <= 0) {
      if (_lives > 1) {
        _lives--;
        _health = _maxHealth;
        _invulnerableTimer = 2.0;
        _playerVy = 340.0;
        _popups.add(
          OkcFloatingPopup(
            x: _playerX,
            y: _playerY + 88.0,
            text: 'LIFE LOST! ($_lives LEFT)',
            color: const Color(0xFFF8B800),
          ),
        );
      } else {
        _health = 0;
        _lives = 0;
        _isGameOver = true;
      }
    }
  }

  // --- Main Game Loop ---
  void _onTick(Duration elapsed) {
    final double rawDt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final double dt = rawDt.clamp(0.0, 0.05);

    if (!mounted) return;

    setState(() {
      _worldTime += dt;

      if (_levelClearBannerTimer > 0) {
        _levelClearBannerTimer = max(0.0, _levelClearBannerTimer - dt);
      }
      if (_screenShakeTimer > 0) {
        _screenShakeTimer = max(0.0, _screenShakeTimer - dt);
      }
      if (_invulnerableTimer > 0) {
        _invulnerableTimer = max(0.0, _invulnerableTimer - dt);
      }
      if (_attackTimer > 0) {
        _attackTimer = max(0.0, _attackTimer - dt);
        if (_attackTimer <= 0) {
          _currentAttack = OkcAttackKind.none;
        }
      }
      if (_attackCooldown > 0) {
        _attackCooldown = max(0.0, _attackCooldown - dt);
      }
      if (_gooseChompTimer > 0) {
        _gooseChompTimer = max(0.0, _gooseChompTimer - dt);
      }
      if (_gooseRemountCooldown > 0) {
        _gooseRemountCooldown = max(0.0, _gooseRemountCooldown - dt);
      }
      if (_comboTimer > 0) {
        _comboTimer -= dt;
        if (_comboTimer <= 0) _combo = 0;
      }

      if (_isGameOver) return;

      final GamepadInputState livePad =
          _injectedGamepadState ?? pollGamepadState();
      _gamepadState = livePad;
      _processGamepadEdges(livePad);

      _updatePlayerPhysics(dt);
      _updateGoose(dt);
      _updateChordProjectiles(dt);
      _updatePowerups(dt);
      _updateZombies(dt);
      _checkCatFoodAndLevelCompletion();
      _updateParticlesAndPopups(dt);
    });
  }

  void _updatePlayerPhysics(double dt) {
    double moveAxisX = 0.0;
    if (_keysPressed.contains(LogicalKeyboardKey.keyA) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      moveAxisX -= 1.0;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyD) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      moveAxisX += 1.0;
    }
    if (_joystickPointerId != null && _joystickDelta.dx.abs() > 0.12) {
      moveAxisX = _joystickDelta.dx;
    }
    if (_gamepadState.connected && _gamepadState.axisX.abs() > 0.18) {
      moveAxisX = _gamepadState.axisX;
    }
    moveAxisX = moveAxisX.clamp(-1.0, 1.0);

    if (moveAxisX.abs() > 0.05) {
      _facingRight = moveAxisX > 0;
    }

    if (_touchPunchHeld ||
        _keysPressed.contains(LogicalKeyboardKey.keyJ) ||
        _keysPressed.contains(LogicalKeyboardKey.keyZ)) {
      triggerPunch();
    }
    if (_touchKickHeld ||
        _keysPressed.contains(LogicalKeyboardKey.keyK) ||
        _keysPressed.contains(LogicalKeyboardKey.keyX)) {
      triggerKick();
    }
    if (_touchChordHeld ||
        _keysPressed.contains(LogicalKeyboardKey.keyL) ||
        _keysPressed.contains(LogicalKeyboardKey.keyC)) {
      triggerChordAttack();
    }

    // Spider Web-Swinging Pendulum Physics
    if (_isWebSwinging && _activeWebAnchor != null) {
      _webSwingTimer += dt;
      final Offset anchor = _activeWebAnchor!;
      final double gravityTorque = -6.8 * sin(_webAngle);
      final double pumpTorque =
          (moveAxisX != 0 ? moveAxisX : (_facingRight ? 1.0 : -1.0)) * 4.2;
      _webAngularVel += (gravityTorque + pumpTorque) * dt;
      _webAngularVel *= 0.992;
      _webAngle += _webAngularVel * dt;

      _playerX = (anchor.dx + sin(_webAngle) * _webRopeLength)
          .clamp(35.0, _currentMap.levelLength - 35.0);
      _playerY = max(22.0, anchor.dy - cos(_webAngle) * _webRopeLength);
      _walkCycle += dt * 10.0;

      for (final z in _zombies) {
        if (z.hp > 0 &&
            (z.x - _playerX).abs() < 44.0 &&
            (z.y - _playerY).abs() < 54.0) {
          _damageZombie(
            z,
            damage: 30,
            knockVx: (_facingRight ? 1.0 : -1.0) * 240.0,
            knockVy: 180.0,
          );
        }
      }

      final bool holdingWeb = _touchWebHeld ||
          _keysPressed.contains(LogicalKeyboardKey.keyE) ||
          _keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
          _keysPressed.contains(LogicalKeyboardKey.shiftRight) ||
          (_gamepadState.connected && _gamepadState.webPressed);
      if (_webSwingTimer > 0.62 && !holdingWeb) {
        releaseWebSwing(launchBoost: true);
      } else if (_webSwingTimer > 1.45) {
        releaseWebSwing(launchBoost: true);
      }
      return;
    }

    final double speedMult = _isRidingGoose ? _gooseSpeedMultiplier : 1.0;
    final double targetVx = moveAxisX * _baseMoveSpeed * speedMult;
    _playerVx = _playerVx * 0.72 + targetVx * 0.28;

    final double prevY = _playerY;
    _playerX = (_playerX + _playerVx * dt)
        .clamp(35.0, _currentMap.levelLength - 35.0);
    _playerVy -= _gravity * dt;
    _playerY += _playerVy * dt;

    bool landed = false;
    if (_playerVy <= 0.0) {
      for (final plat in _currentMap.platforms) {
        if (_playerX >= plat.xMin - 12.0 &&
            _playerX <= plat.xMax + 12.0 &&
            prevY >= plat.elevation - 4.0 &&
            _playerY <= plat.elevation) {
          _playerY = plat.elevation;
          _playerVy = 0.0;
          _isGrounded = true;
          _jumpsRemaining = 2;
          landed = true;
          break;
        }
      }
    }

    if (!landed && _playerY <= 0.0) {
      _playerY = 0.0;
      _playerVy = 0.0;
      _isGrounded = true;
      _jumpsRemaining = 2;
    }

    if (moveAxisX.abs() > 0.05 && _isGrounded) {
      _walkCycle += dt * (11.0 * speedMult);
    } else if (!_isGrounded) {
      _walkCycle += dt * 4.0;
    }
  }

  void _updateGoose(double dt) {
    if (_isRidingGoose) {
      _gooseX = _playerX;
      _gooseY = _playerY;
      _gooseFacingRight = _facingRight;
      _gooseWalkCycle = _walkCycle;
      return;
    }

    if (_gooseVx.abs() > 2.0) {
      _gooseX = (_gooseX + _gooseVx * dt)
          .clamp(60.0, _currentMap.levelLength - 60.0);
      _gooseVx *= 0.92;
      _gooseWalkCycle += dt * 9.0;
    } else {
      _gooseFacingRight = _playerX >= _gooseX;
      _gooseWalkCycle += dt * 2.5;
    }

    if (_gooseY > 0.0) {
      _gooseY = max(0.0, _gooseY - 300.0 * dt);
    }

    if (_gooseRemountCooldown <= 0.0 &&
        (_playerX - _gooseX).abs() < 46.0 &&
        (_playerY - _gooseY).abs() < 48.0) {
      mountGoose();
    }
  }

  void _updateChordProjectiles(double dt) {
    for (final chord in _chordProjectiles) {
      chord.x += chord.vx * dt;
      chord.y += chord.vy * dt;
      chord.life -= dt;

      for (final z in _zombies) {
        if (z.hp <= 0 || chord.hitZombieIds.contains(z.id)) continue;
        if ((z.x - chord.x).abs() < 36.0 &&
            ((z.y + 32.0) - chord.y).abs() < 46.0) {
          chord.hitZombieIds.add(z.id);
          _damageZombie(
            z,
            damage: 32,
            knockVx: chord.vx.sign * 195.0,
            knockVy: 130.0,
          );
          _popups.add(
            OkcFloatingPopup(
              x: z.x,
              y: z.y + 68.0,
              text: '${chord.chordName} CHORD!',
              color: chord.color,
              life: 0.65,
            ),
          );
        }
      }
    }
    _chordProjectiles.removeWhere(
      (c) =>
          c.life <= 0.0 ||
          c.x < -50.0 ||
          c.x > _currentMap.levelLength + 50.0 ||
          c.hitZombieIds.length >= 2,
    );
  }

  void _updatePowerups(double dt) {
    for (final item in _powerups) {
      if (item.collected) continue;
      item.bobPhase += dt * 3.8;
      item.y = item.baseY + sin(item.bobPhase) * 6.0;

      if (item.type == OkcPowerupType.pigeon) {
        item.x += cos(item.bobPhase * 0.7) * 14.0 * dt;
      }

      if ((_playerX - item.x).abs() < 44.0 &&
          ((_playerY + 28.0) - item.y).abs() < 50.0) {
        item.collected = true;
        collectPowerup(item.type, atX: item.x, atY: item.y);
      }
    }
    _powerups.removeWhere((p) => p.collected);
  }

  void _updateZombies(double dt) {
    for (final z in _zombies) {
      if (z.hp <= 0) continue;

      if (z.hurtTimer > 0) {
        z.hurtTimer = max(0.0, z.hurtTimer - dt);
      }
      if (z.attackCooldown > 0) {
        z.attackCooldown = max(0.0, z.attackCooldown - dt);
      }

      if (z.vy != 0.0 || z.y > 0.0) {
        final double floorElev = _elevationAt(z.x, _currentMap.platforms);
        if (z.y > floorElev || z.vy > 0.0) {
          z.vy -= _gravity * 0.85 * dt;
          z.y += z.vy * dt;
          if (z.y <= floorElev) {
            z.y = floorElev;
            z.vy = 0.0;
          }
        }
      }

      if (z.hurtTimer <= 0.0) {
        final double distToPlayer = _playerX - z.x;
        final double baseSpeed = z.kind == OkcZombieKind.walker
            ? 52.0
            : (z.kind == OkcZombieKind.runner ? 98.0 : 38.0);
        if (distToPlayer.abs() < 260.0 && (z.y - _playerY).abs() < 65.0) {
          z.vx = distToPlayer.sign * baseSpeed * 1.15;
        } else {
          if (z.vx.abs() < 10.0) {
            z.vx = baseSpeed;
          }
          if (z.x <= z.patrolMinX && z.vx < 0) z.vx = baseSpeed;
          if (z.x >= z.patrolMaxX && z.vx > 0) z.vx = -baseSpeed;
        }
      } else {
        z.vx *= 0.90;
      }

      z.x = (z.x + z.vx * dt).clamp(180.0, _currentMap.levelLength - 80.0);
      z.facingRight = z.vx >= 0;
      z.walkPhase += dt * (z.kind == OkcZombieKind.runner ? 9.5 : 5.5);

      final bool xOverlap = (_playerX - z.x).abs() < 36.0;
      if (xOverlap &&
          _playerVy < -60.0 &&
          _playerY >= z.y + 18.0 &&
          _playerY <= z.y + 56.0) {
        _damageZombie(
          z,
          damage: _isRidingGoose ? 60 : 35,
          knockVx: (_facingRight ? 1.0 : -1.0) * 120.0,
          knockVy: 90.0,
        );
        _playerVy = 410.0;
        _popups.add(
          OkcFloatingPopup(
            x: z.x,
            y: z.y + 68.0,
            text: _isRidingGoose ? 'GOOSE STOMP!' : 'STOMP!',
            color: const Color(0xFFF8B800),
          ),
        );
        continue;
      }

      if (xOverlap &&
          (_playerY - z.y).abs() < 38.0 &&
          z.hurtTimer <= 0.0 &&
          z.attackCooldown <= 0.0 &&
          _attackTimer <= 0.0) {
        z.attackCooldown = 0.85;
        final int zDmg = z.kind == OkcZombieKind.brute ? 22 : 14;
        _onPlayerDamaged(zDmg, z.x);
      }
    }

    _zombies.removeWhere((z) => z.hp <= 0);
  }

  void _checkCatFoodAndLevelCompletion() {
    if ((_playerX - _currentMap.tortieCatX).abs() < 46.0 &&
        _playerY < 45.0 &&
        _popups.isEmpty) {
      _popups.add(
        OkcFloatingPopup(
          x: _currentMap.tortieCatX,
          y: 78.0,
          text: 'TORTIE CAT: MEOW! FOOD IS AT THE END! ->',
          color: const Color(0xFFF8B800),
          life: 1.1,
        ),
      );
    }

    if ((_playerX - _currentMap.catFoodX).abs() < 52.0 && _playerY < 90.0) {
      completeCurrentLevel();
    }
  }

  void _updateParticlesAndPopups(double dt) {
    for (final p in _particles) {
      p.x += p.vx * dt;
      p.vy -= 420.0 * dt;
      p.y = max(0.0, p.y + p.vy * dt);
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final pop in _popups) {
      pop.y += 32.0 * dt;
      pop.life -= dt;
    }
    _popups.removeWhere((pop) => pop.life <= 0);
  }

  void _handleKeyEvent(KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    if (event is KeyDownEvent) {
      final bool isNewPress = _keysPressed.add(key);
      if (isNewPress) {
        if (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.keyW ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.gameButtonA) {
          triggerJump();
        } else if (key == LogicalKeyboardKey.keyJ ||
            key == LogicalKeyboardKey.keyZ ||
            key == LogicalKeyboardKey.gameButtonX) {
          triggerPunch();
        } else if (key == LogicalKeyboardKey.keyK ||
            key == LogicalKeyboardKey.keyX ||
            key == LogicalKeyboardKey.gameButtonB) {
          triggerKick();
        } else if (key == LogicalKeyboardKey.keyL ||
            key == LogicalKeyboardKey.keyC ||
            key == LogicalKeyboardKey.gameButtonY) {
          triggerChordAttack();
        } else if (key == LogicalKeyboardKey.keyE ||
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight ||
            key == LogicalKeyboardKey.gameButtonRight1 ||
            key == LogicalKeyboardKey.gameButtonLeft1) {
          triggerWebSwing();
        } else if (key == LogicalKeyboardKey.keyG) {
          if (_isRidingGoose) {
            dismountGoose();
          } else if ((_playerX - _gooseX).abs() < 90.0) {
            mountGoose();
          }
        }
      }
    } else if (event is KeyUpEvent) {
      _keysPressed.remove(key);
      if ((key == LogicalKeyboardKey.keyE ||
              key == LogicalKeyboardKey.shiftLeft ||
              key == LogicalKeyboardKey.shiftRight ||
              key == LogicalKeyboardKey.gameButtonRight1 ||
              key == LogicalKeyboardKey.gameButtonLeft1) &&
          _isWebSwinging) {
        releaseWebSwing(launchBoost: true);
      }
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
      backgroundColor: _currentMap.skyTop,
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'okc_dead_chord.sh',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'JetBrainsMono',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'New OKC Map / Restart',
            onPressed: resetFullGame,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: InGameMusicHud(
            currentTrack: _playlist[_currentTrackIndex].split('/').last,
            isPlaying: _isMusicPlaying,
            accentColor: _currentMap.neonAccent,
            onPrevious: _playPreviousTrack,
            onPlayPause: _togglePlayPause,
            onNext: _playNextTrack,
          ),
        ),
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 700;
            final double joystickSize = isCompact ? 112.0 : 142.0;
            final double joystickRadius = joystickSize / 2;

            // Responsive 8-Bit NES viewport zoom so characters and text are bold & large on 1080p+ desktop screens!
            final double worldScale = isCompact
                ? (constraints.maxHeight / 440.0).clamp(1.10, 1.55)
                : (constraints.maxHeight / 410.0).clamp(1.65, 2.65);
            _lastWorldScale = worldScale;

            final double virtualWidth = constraints.maxWidth / worldScale;

            // Update camera smoothly in virtual world coordinates
            final double targetCam = (_playerX - virtualWidth * 0.34).clamp(
              0.0,
              max(0.0, _currentMap.levelLength - virtualWidth),
            );
            _cameraX = _cameraX * 0.82 + targetCam * 0.18;

            final double shakeDx = _screenShakeTimer > 0
                ? sin(_worldTime * 90.0) * 5.0
                : 0.0;
            final double shakeDy = _screenShakeTimer > 0
                ? cos(_worldTime * 80.0) * 4.0
                : 0.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 8-Bit NES Downtown OKC Canvas
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _focusNode.requestFocus(),
                  child: Transform.translate(
                    offset: Offset(shakeDx, shakeDy),
                    child: CustomPaint(
                      painter: _OkcRetroGamePainter(
                        worldTime: _worldTime,
                        worldScale: worldScale,
                        map: _currentMap,
                        cameraX: _cameraX,
                        playerX: _playerX,
                        playerY: _playerY,
                        facingRight: _facingRight,
                        walkCycle: _walkCycle,
                        isGrounded: _isGrounded,
                        invulnerableTimer: _invulnerableTimer,
                        currentAttack: _currentAttack,
                        attackTimer: _attackTimer,
                        hasGuitar: _hasGuitar,
                        hasSpiderPower: _hasSpiderPower,
                        isWebSwinging: _isWebSwinging,
                        activeWebAnchor: _activeWebAnchor,
                        isRidingGoose: _isRidingGoose,
                        gooseX: _gooseX,
                        gooseY: _gooseY,
                        gooseFacingRight: _gooseFacingRight,
                        gooseWalkCycle: _gooseWalkCycle,
                        gooseChompTimer: _gooseChompTimer,
                        zombies: _zombies,
                        powerups: _powerups,
                        chordProjectiles: _chordProjectiles,
                        particles: _particles,
                        popups: _popups,
                      ),
                    ),
                  ),
                ),

                // Top 8-Bit NES Arcade HUD
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: _buildTopHud(isCompact),
                  ),
                ),

                // Level Clear 8-Bit Banner
                if (_levelClearBannerTimer > 0)
                  Positioned(
                    top: isCompact ? 96 : 118,
                    left: 20,
                    right: 20,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 24,
                            vertical: isCompact ? 10 : 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                              color: const Color(0xFFF8B800),
                              width: 3,
                            ),
                          ),
                          child: Text(
                            'TORTIE CAT FED! NEW DOWNTOWN OKC MAP: LVL $_level',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFF8B800),
                              fontFamily: 'JetBrainsMono',
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 13 : 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Touch Joystick (Bottom-Left)
                Positioned(
                  left: isCompact ? 12 : 26,
                  bottom: isCompact ? 14 : 24,
                  child: Listener(
                    key: const Key('virtual_joystick'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      if (_joystickPointerId == null) {
                        setState(() {
                          _joystickPointerId = event.pointer;
                          _joystickCenter =
                              Offset(joystickRadius, joystickRadius);
                          _updateJoystickVector(
                            event.localPosition,
                            joystickRadius * 0.68,
                          );
                          if (_joystickDelta.dy < -0.55) {
                            triggerJump();
                          }
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
                      width: joystickSize,
                      height: joystickSize,
                      child: CustomPaint(
                        painter: _OkcJoystickPainter(
                          delta: _joystickDelta,
                          isActive: _joystickPointerId != null,
                          accentColor: _currentMap.neonAccent,
                        ),
                      ),
                    ),
                  ),
                ),

                // Touch 8-Bit Arcade Action Buttons (Bottom-Right)
                Positioned(
                  right: isCompact ? 10 : 24,
                  bottom: isCompact ? 12 : 22,
                  child: _buildTouchButtons(isCompact),
                ),

                // Game Over Overlay
                if (_isGameOver) _buildGameOverOverlay(isCompact),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHud(bool isCompact) {
    final int filledBlocks = ((_health / _maxHealth) * 10).round().clamp(0, 10);
    final String nesHpBar =
        '█' * filledBlocks + '░' * (10 - filledBlocks);
    final double mainFont = isCompact ? 12.0 : 16.0;
    final double subFont = isCompact ? 10.0 : 13.0;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        // 8-Bit NES Double-Bordered Player Status Box
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.90),
            border: Border.all(
              color: Colors.white,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _currentMap.neonAccent.withValues(alpha: 0.45),
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '1P: archBTW',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.bold,
                      fontSize: mainFont,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'LIVES: $_lives',
                    style: TextStyle(
                      color: const Color(0xFFF8B800),
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.bold,
                      fontSize: mainFont,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SCORE: $_score',
                    style: TextStyle(
                      color: const Color(0xFF3CBCFC),
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.bold,
                      fontSize: mainFont,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'HP: $_health/$_maxHealth ',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.bold,
                      fontSize: subFont,
                    ),
                  ),
                  Text(
                    '[$nesHpBar]',
                    style: TextStyle(
                      color: filledBlocks > 4
                          ? const Color(0xFF58F898)
                          : const Color(0xFFF83870),
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.bold,
                      fontSize: subFont,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildStatusBadge(
                    label: 'LVL $_level: ${_currentMap.districtName}',
                    color: _currentMap.neonAccent,
                    fontSize: subFont,
                  ),
                  if (_isRidingGoose)
                    _buildStatusBadge(
                      label: 'MOUNT: GOOSE',
                      color: const Color(0xFFF8B800),
                      fontSize: subFont,
                    ),
                  if (_hasGuitar)
                    _buildStatusBadge(
                      label: 'GUITAR: CHORDS',
                      color: const Color(0xFFB878F8),
                      fontSize: subFont,
                    ),
                  if (_hasSpiderPower)
                    _buildStatusBadge(
                      label: 'SPIDER: WEB',
                      color: const Color(0xFF3CBCFC),
                      fontSize: subFont,
                    ),
                ],
              ),
            ],
          ),
        ),

        // Desktop Controls & Quest Box
        if (!isCompact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.90),
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _gamepadState.connected
                      ? 'CONTROLLER CONNECTED // STICK: Move | A: Jump | X: Punch | B: Kick | Y: Chord | RB: Web'
                      : 'WASD/ARROWS: Move | SPACE: Jump | J/Z: Punch | K/X: Kick | L/C: Chord | E/SHIFT: Web',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'QUEST: Tortie Cat is begging! Grab the Cat Food at the end of Downtown OKC!',
                  style: TextStyle(
                    color: Color(0xFFF8B800),
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required Color color,
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: color, width: 1.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'JetBrainsMono',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTouchButtons(bool isCompact) {
    final double btnSize = isCompact ? 56.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildArcadeButton(
              buttonKey: const Key('web_button'),
              label: 'WEB',
              subLabel: 'SWING',
              color: const Color(0xFF3CBCFC),
              size: btnSize * 0.92,
              isPressed: _touchWebHeld,
              onDown: () {
                setState(() => _touchWebHeld = true);
                triggerWebSwing();
              },
              onUp: () {
                setState(() => _touchWebHeld = false);
                if (_isWebSwinging) releaseWebSwing(launchBoost: true);
              },
            ),
            const SizedBox(width: 8),
            _buildArcadeButton(
              buttonKey: const Key('chord_button'),
              label: 'CHORD',
              subLabel: 'GUITAR',
              color: const Color(0xFFB878F8),
              size: btnSize * 0.92,
              isPressed: _touchChordHeld,
              onDown: () {
                setState(() => _touchChordHeld = true);
                triggerChordAttack();
              },
              onUp: () => setState(() => _touchChordHeld = false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildArcadeButton(
              buttonKey: const Key('punch_button'),
              label: 'PUNCH',
              subLabel: 'J / Z',
              color: const Color(0xFFF83870),
              size: btnSize,
              isPressed: _touchPunchHeld,
              onDown: () {
                setState(() => _touchPunchHeld = true);
                triggerPunch();
              },
              onUp: () => setState(() => _touchPunchHeld = false),
            ),
            const SizedBox(width: 8),
            _buildArcadeButton(
              buttonKey: const Key('kick_button'),
              label: 'KICK',
              subLabel: 'K / X',
              color: const Color(0xFFF8B800),
              size: btnSize,
              isPressed: _touchKickHeld,
              onDown: () {
                setState(() => _touchKickHeld = true);
                triggerKick();
              },
              onUp: () => setState(() => _touchKickHeld = false),
            ),
            const SizedBox(width: 8),
            _buildArcadeButton(
              buttonKey: const Key('jump_button'),
              label: 'JUMP',
              subLabel: 'SPACE',
              color: const Color(0xFF58F898),
              size: btnSize,
              isPressed: _touchJumpHeld,
              onDown: () {
                setState(() => _touchJumpHeld = true);
                triggerJump();
              },
              onUp: () => setState(() => _touchJumpHeld = false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArcadeButton({
    required Key buttonKey,
    required String label,
    required String subLabel,
    required Color color,
    required double size,
    required bool isPressed,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPressed ? color : Colors.black.withValues(alpha: 0.85),
          border: Border.all(
            color: isPressed ? Colors.white : color,
            width: 3.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: isPressed ? const Offset(1, 1) : const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isPressed ? Colors.black : Colors.white,
                  fontFamily: 'JetBrainsMono',
                  fontSize: size > 62 ? 13 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subLabel,
                style: TextStyle(
                  color: isPressed ? Colors.black87 : color,
                  fontFamily: 'JetBrainsMono',
                  fontSize: size > 62 ? 9 : 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(bool isCompact) {
    return Container(
      color: Colors.black.withValues(alpha: 0.86),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: const Color(0xFFF83870), width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GAME OVER IN DOWNTOWN OKC',
                style: TextStyle(
                  color: const Color(0xFFF83870),
                  fontFamily: 'JetBrainsMono',
                  fontSize: isCompact ? 18 : 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'FINAL SCORE: $_score  |  ZOMBIES KO: $_zombiesDefeated  |  LEVEL: $_level',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'JetBrainsMono',
                  fontSize: isCompact ? 12 : 16,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('retry_game_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: resetFullGame,
                child: Text(
                  '[ INSERT COIN / PLAY AGAIN ]',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 13 : 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 8-Bit NES D-Pad / Joystick Painter ---
class _OkcJoystickPainter extends CustomPainter {
  final Offset delta;
  final bool isActive;
  final Color accentColor;

  _OkcJoystickPainter({
    required this.delta,
    required this.isActive,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    // 8-Bit Octagonal/Square NES D-Pad Housing
    final Rect outerRect = Rect.fromCenter(
      center: center,
      width: size.width - 6,
      height: size.height - 6,
    );
    canvas.drawRect(
      outerRect,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
    canvas.drawRect(
      outerRect,
      Paint()
        ..color = isActive ? accentColor : Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // NES Cross D-Pad grooves
    final double armW = size.width * 0.28;
    final double armL = size.width * 0.72;
    final Paint crossPaint = Paint()..color = const Color(0xFF262626);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: armL, height: armW),
      crossPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: armW, height: armL),
      crossPaint,
    );

    // 8-Bit Pixel Thumb Block
    final Offset knobPos = center + delta * (radius * 0.52);
    final double thumbSize = radius * 0.50;
    final Rect thumbRect = Rect.fromCenter(
      center: knobPos,
      width: thumbSize,
      height: thumbSize,
    );
    canvas.drawRect(
      thumbRect,
      Paint()..color = isActive ? accentColor : const Color(0xFFE2E8F0),
    );
    canvas.drawRect(
      thumbRect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _OkcJoystickPainter oldDelegate) =>
      oldDelegate.delta != delta || oldDelegate.isActive != isActive;
}

// --- Detailed 8-Bit NES Side-Scroller Downtown OKC Painter ---
class _OkcRetroGamePainter extends CustomPainter {
  final double worldTime;
  final double worldScale;
  final OkcLevelMap map;
  final double cameraX;
  final double playerX;
  final double playerY;
  final bool facingRight;
  final double walkCycle;
  final bool isGrounded;
  final double invulnerableTimer;
  final OkcAttackKind currentAttack;
  final double attackTimer;
  final bool hasGuitar;
  final bool hasSpiderPower;
  final bool isWebSwinging;
  final Offset? activeWebAnchor;
  final bool isRidingGoose;
  final double gooseX;
  final double gooseY;
  final bool gooseFacingRight;
  final double gooseWalkCycle;
  final double gooseChompTimer;
  final List<OkcZombie> zombies;
  final List<OkcPowerupItem> powerups;
  final List<OkcChordProjectile> chordProjectiles;
  final List<OkcParticle> particles;
  final List<OkcFloatingPopup> popups;

  _OkcRetroGamePainter({
    required this.worldTime,
    required this.worldScale,
    required this.map,
    required this.cameraX,
    required this.playerX,
    required this.playerY,
    required this.facingRight,
    required this.walkCycle,
    required this.isGrounded,
    required this.invulnerableTimer,
    required this.currentAttack,
    required this.attackTimer,
    required this.hasGuitar,
    required this.hasSpiderPower,
    required this.isWebSwinging,
    required this.activeWebAnchor,
    required this.isRidingGoose,
    required this.gooseX,
    required this.gooseY,
    required this.gooseFacingRight,
    required this.gooseWalkCycle,
    required this.gooseChompTimer,
    required this.zombies,
    required this.powerups,
    required this.chordProjectiles,
    required this.particles,
    required this.popups,
  });

  // Core 8-Bit NES Sprite Renderer: draws character-mapped pixel art matrices
  // using crisp run-length encoded rectangles with anti-aliasing disabled.
  void _drawPixelMatrix(
    Canvas canvas,
    List<String> rows,
    Map<String, Color> palette, {
    required double pixelSize,
    required Offset origin,
  }) {
    final Paint p = Paint()..isAntiAlias = false;
    for (int r = 0; r < rows.length; r++) {
      final String row = rows[r];
      int c = 0;
      while (c < row.length) {
        final String ch = row[c];
        final Color? color = palette[ch];
        if (color == null) {
          c++;
          continue;
        }
        int run = 1;
        while (c + run < row.length && row[c + run] == ch) {
          run++;
        }
        p.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + c * pixelSize,
            origin.dy + r * pixelSize,
            run * pixelSize,
            pixelSize,
          ),
          p,
        );
        c += run;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size screenSize) {
    canvas.save();
    canvas.scale(worldScale, worldScale);
    final Size size = Size(
      screenSize.width / worldScale,
      screenSize.height / worldScale,
    );
    final double groundScreenY = size.height * 0.78;

    // 1. 8-Bit NES Stepped Sky Bands & Dithering
    _drawNesSkyBands(canvas, size, groundScreenY);

    // 2. Far Parallax: 8-Bit Downtown OKC Skyline (Devon Energy Tower, Wheeler Ferris Wheel)
    _drawOkcSkylineParallax(canvas, size, groundScreenY);

    // 3. Midground: Detailed 8-Bit Bricktown Buildings & Pixel Neon Signs
    _drawDistrictBuildings(canvas, size, groundScreenY);

    // 4. 8-Bit Tiled Street, Brick Curb & OKC Streetcar Tracks
    _drawStreetAndSidewalk(canvas, size, groundScreenY);

    // 5. Overhead Streetlight Web-Anchors
    _drawWebAnchors(canvas, groundScreenY);

    // 6. 8-Bit Brick & Steel Girder Platforms
    _drawPlatforms(canvas, groundScreenY);

    // 7. Tortie Cat at the beginning of the level begging for food!
    _drawTortieCat(
      canvas,
      map.tortieCatX - cameraX,
      groundScreenY,
    );

    // 8. Cat Food Goal at the end of the level!
    _drawCatFoodGoal(
      canvas,
      map.catFoodX - cameraX,
      groundScreenY,
    );

    // 9. 8-Bit Powerups: Health Pills, Purple PRS Guitar, Spider Emblem, Pigeons (+1 Life)
    for (final item in powerups) {
      final double sx = item.x - cameraX;
      if (sx < -70 || sx > size.width + 70) continue;
      final double sy = groundScreenY - item.y;
      _drawPowerupItem(canvas, item, sx, sy);
    }

    // 10. Unmounted Goose (White Pitbull/Corgi Mix)
    if (!isRidingGoose) {
      final double gsx = gooseX - cameraX;
      final double gsy = groundScreenY - gooseY;
      _drawGoose(
        canvas,
        gsx,
        gsy,
        gooseFacingRight,
        gooseWalkCycle,
        gooseChompTimer > 0,
        showRidePrompt: true,
      );
    }

    // 11. 8-Bit Zombies
    for (final z in zombies) {
      final double zsx = z.x - cameraX;
      if (zsx < -90 || zsx > size.width + 90) continue;
      final double zsy = groundScreenY - z.y;
      _drawZombie(canvas, z, zsx, zsy);
    }

    // 12. 8-Bit Segmented Pixel Spider-Web Chain when swinging
    if (isWebSwinging && activeWebAnchor != null) {
      final double ax = activeWebAnchor!.dx - cameraX;
      final double ay = groundScreenY - activeWebAnchor!.dy;
      final double px = playerX - cameraX;
      final double py = groundScreenY - playerY - 46.0;
      _drawPixelLine(
        canvas,
        Offset(px, py),
        Offset(ax, ay),
        pixelSize: 3.0,
        color: Colors.white,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(ax, ay), width: 10, height: 10),
        Paint()..color = const Color(0xFF3CBCFC),
      );
    }

    // 13. Player (archBTW 8-Bit Sprite) + Mounted Goose
    final bool flashHide =
        invulnerableTimer > 0 && ((worldTime * 18).floor() % 2 == 0);
    if (!flashHide) {
      final double psx = playerX - cameraX;
      final double psy = groundScreenY - playerY;
      if (isRidingGoose) {
        _drawGoose(
          canvas,
          psx,
          psy,
          facingRight,
          walkCycle,
          gooseChompTimer > 0,
          showRidePrompt: false,
        );
        _drawArchBtwPlayer(canvas, psx, psy - 24.0);
      } else {
        _drawArchBtwPlayer(canvas, psx, psy);
      }
    }

    // 14. 8-Bit Guitar Power Chord Projectiles
    for (final chord in chordProjectiles) {
      final double csx = chord.x - cameraX;
      final double csy = groundScreenY - chord.y;
      _drawChordProjectile(canvas, chord, csx, csy);
    }

    // 15. 8-Bit Square Pixel Particles & Floating Popups
    final Paint partPaint = Paint()..isAntiAlias = false;
    for (final p in particles) {
      final double sx = (p.x - cameraX / 1.0).floorToDouble();
      final double sy = (groundScreenY - p.y).floorToDouble();
      partPaint.color = p.color;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(sx, sy), width: p.size, height: p.size),
        partPaint,
      );
    }

    for (final pop in popups) {
      final double sx = pop.x - cameraX;
      final double sy = groundScreenY - pop.y;
      _drawNesBannerLabel(
        canvas,
        pop.text,
        Offset(sx, sy),
        pop.color,
        fontSize: 12,
      );
    }

    canvas.restore();

    // 16. Crisp 8-Bit CRT Scanlines in screen space
    final Paint scanlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 1.0;
    for (double y = 0; y < screenSize.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(screenSize.width, y), scanlinePaint);
    }
  }

  void _drawPixelLine(
    Canvas canvas,
    Offset p1,
    Offset p2, {
    required double pixelSize,
    required Color color,
  }) {
    final double dist = (p2 - p1).distance;
    final int steps = max(1, (dist / pixelSize).ceil());
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double x =
          ((p1.dx + (p2.dx - p1.dx) * t) / pixelSize).floor() * pixelSize;
      final double y =
          ((p1.dy + (p2.dy - p1.dy) * t) / pixelSize).floor() * pixelSize;
      canvas.drawRect(Rect.fromLTWH(x, y, pixelSize, pixelSize), paint);
    }
  }

  void _drawNesSkyBands(Canvas canvas, Size size, double groundScreenY) {
    final Paint p = Paint()..isAntiAlias = false;
    final double band1 = groundScreenY * 0.36;
    final double band2 = groundScreenY * 0.70;

    p.color = map.skyTop;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, band1), p);
    p.color = map.skyMid;
    canvas.drawRect(Rect.fromLTWH(0, band1, size.width, band2 - band1), p);
    p.color = map.skyBottom;
    canvas.drawRect(
      Rect.fromLTWH(0, band2, size.width, size.height - band2),
      p,
    );

    // 8-Bit Checkerboard Dither strips between sky bands
    p.color = map.skyMid;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, band1 - 4, 4, 4), p);
    }
    p.color = map.skyBottom;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, band2 - 4, 4, 4), p);
    }
  }

  void _drawOkcSkylineParallax(
    Canvas canvas,
    Size size,
    double groundScreenY,
  ) {
    final double parallaxX = cameraX * 0.22;
    final Paint p = Paint()..isAntiAlias = false;

    // 8-Bit Pixel Stars & Cross Twinkles
    for (int i = 0; i < 28; i++) {
      final double sx =
          (((i * 137.0 - parallaxX * 0.3) % size.width + size.width) %
                  size.width /
                  3.0)
              .floor() *
              3.0;
      final double sy =
          (((i * 43.0) % (groundScreenY * 0.52)) / 3.0).floor() * 3.0;
      final bool twinkle = ((worldTime * 3.0 + i).floor() % 4) == 0;
      p.color = twinkle ? const Color(0xFFF8B800) : Colors.white70;
      canvas.drawRect(Rect.fromLTWH(sx, sy, 3, 3), p);
      if (twinkle) {
        canvas.drawRect(Rect.fromLTWH(sx - 3, sy, 9, 3), p);
        canvas.drawRect(Rect.fromLTWH(sx, sy - 3, 3, 9), p);
      }
    }

    // 8-Bit Stepped Devon Energy Center Skyscraper (OKC's tallest landmark!)
    final double devonX =
        (((size.width * 0.54 - parallaxX * 0.45) % (size.width + 320)) - 80)
            .floorToDouble();
    final double towerW = 64.0;
    final double towerH = 220.0;
    final double topY = groundScreenY - towerH;

    // Main stepped glass tower body
    p.color = const Color(0xFF102040);
    canvas.drawRect(Rect.fromLTWH(devonX, topY + 24, towerW, towerH - 24), p);
    // Stepped 8-bit triangular crown of Devon Tower
    for (int step = 0; step < 6; step++) {
      canvas.drawRect(
        Rect.fromLTWH(
          devonX + step * 4.0,
          topY + (5 - step) * 4.0,
          towerW - step * 8.0,
          4.0,
        ),
        p,
      );
    }
    // Pixel border & vertical window columns on Devon Tower
    p.color = const Color(0xFF3CBCFC);
    canvas.drawRect(Rect.fromLTWH(devonX, topY + 24, 3, towerH - 24), p);
    canvas.drawRect(
      Rect.fromLTWH(devonX + towerW - 3, topY + 24, 3, towerH - 24),
      p,
    );
    for (double wy = topY + 32; wy < groundScreenY - 12; wy += 10) {
      for (double wx = devonX + 8; wx < devonX + towerW - 10; wx += 10) {
        canvas.drawRect(
          Rect.fromLTWH(wx, wy, 5, 5),
          Paint()..color = const Color(0xFF3CBCFC).withValues(alpha: 0.45),
        );
      }
    }
    // Blinking 8-bit beacon on Devon spire
    if ((worldTime * 4).floor().isEven) {
      canvas.drawRect(
        Rect.fromLTWH(devonX + towerW / 2 - 3, topY - 6, 6, 6),
        Paint()..color = const Color(0xFFF83870),
      );
    }

    // 8-Bit Pixel Wheeler District Ferris Wheel
    final double wheelCenterX =
        (((size.width * 0.22 - parallaxX * 0.35) % (size.width + 280)) - 50)
            .floorToDouble();
    final Offset wc = Offset(wheelCenterX, groundScreenY - 64);
    const double wr = 42.0;
    // Support A-frame legs
    _drawPixelLine(
      canvas,
      wc,
      Offset(wc.dx - 24, groundScreenY),
      pixelSize: 3.0,
      color: const Color(0xFF475569),
    );
    _drawPixelLine(
      canvas,
      wc,
      Offset(wc.dx + 24, groundScreenY),
      pixelSize: 3.0,
      color: const Color(0xFF475569),
    );
    // 12 Pixel Gondola Cars around the Ferris wheel
    for (int i = 0; i < 12; i++) {
      final double a = worldTime * 0.35 + (i * pi / 6);
      final double gx = (wc.dx + cos(a) * wr).floorToDouble();
      final double gy = (wc.dy + sin(a) * wr).floorToDouble();
      canvas.drawRect(
        Rect.fromCenter(center: Offset(gx, gy), width: 6, height: 6),
        Paint()
          ..color = i.isEven ? map.neonAccent : const Color(0xFFF8B800)
          ..isAntiAlias = false,
      );
    }
  }

  void _drawDistrictBuildings(
    Canvas canvas,
    Size size,
    double groundScreenY,
  ) {
    final double midScroll = (cameraX * 0.65).floorToDouble();
    final Paint p = Paint()..isAntiAlias = false;

    for (final b in map.buildings) {
      final double bx = (b.x - midScroll).floorToDouble();
      if (bx + b.width < -60 || bx > size.width + 60) continue;
      final double topY = (groundScreenY - b.height).floorToDouble();

      // Main 8-bit building block with 3px black NES outline
      p.color = Colors.black;
      canvas.drawRect(
        Rect.fromLTWH(bx - 3, topY - 3, b.width + 6, b.height + 3),
        p,
      );
      p.color = b.color;
      canvas.drawRect(Rect.fromLTWH(bx, topY, b.width, b.height), p);

      // Stepped cornice roof trim
      p.color = b.trimColor;
      canvas.drawRect(Rect.fromLTWH(bx - 3, topY - 3, b.width + 6, 9), p);

      // 8-Bit Brick mortar pixel rows on Bricktown buildings
      if (b.isBrick) {
        p.color = const Color(0xFF480C0C);
        for (double by = topY + 12; by < groundScreenY; by += 12) {
          canvas.drawRect(Rect.fromLTWH(bx, by, b.width, 2), p);
        }
      }

      // 8-Bit Pixel Windows with sills
      final double padX = 12.0;
      final double padY = 28.0;
      final double cellW = (b.width - padX * 2) / max(1, b.windowCols);
      final double cellH = (b.height - padY * 2) / max(1, b.windowRows);
      for (int r = 0; r < b.windowRows; r++) {
        for (int c = 0; c < b.windowCols; c++) {
          final bool lit = ((r * 7 + c * 13 + b.windowRows) % 3) != 0;
          final double wx = (bx + padX + c * cellW + 3).floorToDouble();
          final double wy = (topY + padY + r * cellH + 3).floorToDouble();
          final double ww = max(8.0, (cellW - 8).floorToDouble());
          final double wh = max(10.0, (cellH - 10).floorToDouble());

          p.color = Colors.black;
          canvas.drawRect(Rect.fromLTWH(wx - 2, wy - 2, ww + 4, wh + 4), p);
          p.color = lit ? const Color(0xFFF8D870) : const Color(0xFF0C1020);
          canvas.drawRect(Rect.fromLTWH(wx, wy, ww, wh), p);
        }
      }

      // 8-Bit Pixel Neon District Sign
      if (b.neonSign != null) {
        final Rect signRect = Rect.fromLTWH(
          bx + 6,
          topY + 10,
          b.width - 12,
          20,
        );
        p.color = Colors.black;
        canvas.drawRect(signRect, p);
        canvas.drawRect(
          signRect,
          Paint()
            ..color = b.neonColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        _drawLabel(
          canvas,
          b.neonSign!,
          signRect.center,
          b.neonColor,
          fontSize: 10,
          bold: true,
        );
      }
    }
  }

  void _drawStreetAndSidewalk(
    Canvas canvas,
    Size size,
    double groundScreenY,
  ) {
    final Paint p = Paint()..isAntiAlias = false;

    // Black top border line on sidewalk
    p.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, groundScreenY - 3, size.width, 3), p);

    // 8-Bit Tiled Concrete Curb Blocks
    p.color = const Color(0xFF94A3B8);
    canvas.drawRect(Rect.fromLTWH(0, groundScreenY, size.width, 6), p);
    p.color = const Color(0xFF64748B);
    canvas.drawRect(Rect.fromLTWH(0, groundScreenY + 6, size.width, 10), p);

    final double tileOffset = -(cameraX % 32).floorToDouble();
    p.color = Colors.black;
    for (double x = tileOffset; x < size.width; x += 32) {
      canvas.drawRect(Rect.fromLTWH(x, groundScreenY, 3, 16), p);
    }

    // Dark Asphalt Street
    p.color = const Color(0xFF181C28);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        groundScreenY + 16,
        size.width,
        size.height - groundScreenY,
      ),
      p,
    );

    // OKC Streetcar Steel Tracks & Yellow Dashed Centerline
    p.color = const Color(0xFF334155);
    canvas.drawRect(Rect.fromLTWH(0, groundScreenY + 26, size.width, 3), p);
    canvas.drawRect(Rect.fromLTWH(0, groundScreenY + 52, size.width, 3), p);

    final double dashOffset = -(cameraX % 56).floorToDouble();
    p.color = const Color(0xFFF8B800);
    for (double x = dashOffset; x < size.width; x += 56) {
      canvas.drawRect(Rect.fromLTWH(x, groundScreenY + 38, 28, 4), p);
    }
  }

  void _drawWebAnchors(Canvas canvas, double groundScreenY) {
    final Paint p = Paint()..isAntiAlias = false;
    for (final anchor in map.webAnchors) {
      final double sx = (anchor.dx - cameraX).floorToDouble();
      final double sy = (groundScreenY - anchor.dy).floorToDouble();

      // 8-Bit Streetlight Post
      p.color = const Color(0xFF334155);
      canvas.drawRect(Rect.fromLTWH(sx - 2, sy, 4, groundScreenY - sy), p);
      // Crossbar & Lantern Block
      p.color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(sx - 9, sy - 9, 18, 18), p);
      p.color = hasSpiderPower
          ? const Color(0xFF3CBCFC)
          : const Color(0xFFF8D870);
      canvas.drawRect(Rect.fromLTWH(sx - 6, sy - 6, 12, 12), p);
    }
  }

  void _drawPlatforms(Canvas canvas, double groundScreenY) {
    final Paint p = Paint()..isAntiAlias = false;
    for (final plat in map.platforms) {
      final double x1 = (plat.xMin - cameraX).floorToDouble();
      final double x2 = (plat.xMax - cameraX).floorToDouble();
      final double py = (groundScreenY - plat.elevation).floorToDouble();
      final double w = x2 - x1;
      const double h = 16.0;

      // 8-Bit Black Outer Frame
      p.color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(x1 - 2, py - 2, w + 4, h + 4), p);

      final Color baseCol = plat.style == 0
          ? const Color(0xFFA82820) // Bricktown red brick
          : (plat.style == 1
              ? const Color(0xFF385078) // Steel girder
              : const Color(0xFF6828A8)); // OKC Streetcar canopy
      final Color topHighlight = plat.style == 0
          ? const Color(0xFFF87858)
          : (plat.style == 1
              ? const Color(0xFF88B0E8)
              : const Color(0xFFB878F8));

      p.color = baseCol;
      canvas.drawRect(Rect.fromLTWH(x1, py, w, h), p);
      p.color = topHighlight;
      canvas.drawRect(Rect.fromLTWH(x1, py, w, 4), p);

      // 8-Bit Brick / Girder Rivet Tile Divisions
      p.color = Colors.black;
      for (double tx = x1 + 16; tx < x2 - 4; tx += 16) {
        canvas.drawRect(Rect.fromLTWH(tx, py, 2, h), p);
      }
      canvas.drawRect(Rect.fromLTWH(x1, py + 8, w, 2), p);
    }
  }

  // --- Detailed 8-Bit Tortie Cat Sprite (Start of Level) ---
  static const List<String> _tortieCatMatrix = [
    '..KK......KK....',
    '.KOO.KKKK.AAK...',
    '.KOOKOOOOAAAAK..',
    '.KOOOGGOOAAGGK..',
    '.KKKKOOOOAAAAK..',
    '..KOOAAAACCKKK..',
    '..KKKKKKKKKK....',
    '.KOOAAKKOOOO.KK.',
    'KKOOAAKKOOOOAAAK',
    'KOOOAAKKOOOOAAAK',
    'K.KKKKKKKKKKKK..',
    '..KOOAAKKOOOO...',
    '..KOOAAKKOOOO...',
    '..KKKKK..KKKKK..',
  ];

  void _drawTortieCat(Canvas canvas, double sx, double groundY) {
    final double bob = ((worldTime * 5.0).floor() % 2) * 3.0;
    const double px = 3.0;
    final double w = 16 * px;
    final double h = 14 * px;

    _drawPixelMatrix(
      canvas,
      _tortieCatMatrix,
      const {
        'K': Color(0xFF141210), // Black outline & dark tortie fur
        'O': Color(0xFFEA580C), // Tortie fiery orange patch
        'A': Color(0xFFF8B800), // Tortie amber gold patch
        'C': Color(0xFFFDE68A), // Cream chin patch
        'G': Color(0xFF58F898), // Bright green cat eyes
      },
      pixelSize: px,
      origin: Offset(sx - w / 2, groundY - h - bob),
    );

    _drawNesBannerLabel(
      canvas,
      'TORTIE CAT: "MEOW! FEED ME!"',
      Offset(sx + 10, groundY - h - 20),
      const Color(0xFFF8B800),
      fontSize: 11,
    );
  }

  // --- Detailed 8-Bit Cat Food Goal Sprite (End of Level) ---
  static const List<String> _catFoodMatrix = [
    '....KKKKKKKK....',
    '..KKFFFFFFFFKK..',
    '.KFFWWWWWWWWFFK.',
    'KFFWKKKKKKKKWFFK',
    'KFFWKPPPPPPKWFFK',
    'KFFWKPYYYYPKWFFK',
    'KFFWKPPPPPPKWFFK',
    '.KKKKKKKKKKKKKK.',
    '.KPPPPPPPPPPPPK.',
    '.KPYYYYYYYYYYPK.',
    '.KPPPPPPPPPPPPK.',
    '..KKKKKKKKKKKK..',
  ];

  void _drawCatFoodGoal(Canvas canvas, double sx, double groundY) {
    final double bob = ((worldTime * 4.0).floor() % 2) * 4.0;
    const double px = 3.2;
    final double w = 16 * px;
    final double h = 12 * px;

    // 8-Bit Pedestal Block
    final Paint p = Paint()..isAntiAlias = false;
    p.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(sx - 24, groundY - 26, 48, 26), p);
    p.color = const Color(0xFF475569);
    canvas.drawRect(Rect.fromLTWH(sx - 21, groundY - 23, 42, 23), p);

    _drawPixelMatrix(
      canvas,
      _catFoodMatrix,
      const {
        'K': Colors.black,
        'F': Color(0xFFFB7185), // Salmon fish
        'W': Colors.white,
        'P': Color(0xFFF83870), // Pink cat food tin
        'Y': Color(0xFFF8B800), // Gold stripe
      },
      pixelSize: px,
      origin: Offset(sx - w / 2, groundY - 26 - h - bob),
    );

    _drawNesBannerLabel(
      canvas,
      '▼ CAT FOOD [GOAL] ▼',
      Offset(sx, groundY - 26 - h - 22 - bob),
      const Color(0xFFF8B800),
      fontSize: 12,
    );
  }

  // --- Detailed 8-Bit Goose Sprite (White Pitbull/Corgi Mix — Yoshi Mount) ---
  static const List<String> _gooseMatrix = [
    '..............KKK...KKK.',
    '.............KTTTK.KWWWK',
    '.............KTWWKKWWWWK',
    '............KWWWWWWWWWWK',
    '..KKK.......KWWWWWWKWKWWK',
    '.KWWWK......KWWWWWWWWWWKK',
    '.KWWWWKKKKKKCPWWWWWWWWWWNN',
    '..KWWWWWWWWCPYWWWWWWWWWWWK',
    '..KWWTTTTWWCPWWWWWWWWKKKK.',
    '..KWWTTTTWWWWWWWWWWWWRRR..',
    '..KWWWWWWWWWWWWWWWWWWKKK..',
    '...KKKKKKKKKKKKKKKKKK.....',
    '...KWWWK.KWWWK..KWWWK.KWWK',
    '...KWWWK.KWWWK..KWWWK.KWWK',
    '...KKKKK.KKKKK..KKKKK.KKKK',
  ];

  void _drawGoose(
    Canvas canvas,
    double sx,
    double sy,
    bool right,
    double cycle,
    bool chomping, {
    required bool showRidePrompt,
  }) {
    const double px = 3.0;
    final double w = 26 * px;
    final double h = 15 * px;
    final double stepBob = ((cycle * 1.5).floor() % 2) * 3.0;

    canvas.save();
    canvas.translate(sx, sy - stepBob);
    if (!right) {
      canvas.scale(-1.0, 1.0);
    }

    _drawPixelMatrix(
      canvas,
      _gooseMatrix,
      {
        'K': Colors.black,
        'W': const Color(0xFFF8FAFC), // Crisp white pitbull/corgi coat
        'T': const Color(0xFFE5C07B), // Biscuit/tan corgi ear & saddle patch
        'C': const Color(0xFFB878F8), // Purple studded collar
        'P': const Color(0xFF9333EA),
        'Y': const Color(0xFFF8B800), // Gold "GOOSE" collar tag
        'N': const Color(0xFF0F172A), // Nose
        'R': chomping
            ? const Color(0xFFF8B800)
            : const Color(0xFFF83870), // Pink tongue / chomp spark
      },
      pixelSize: px,
      origin: Offset(-w / 2, -h),
    );

    canvas.restore();

    if (showRidePrompt) {
      _drawNesBannerLabel(
        canvas,
        '▼ GOOSE [RIDE] ▼',
        Offset(sx, sy - h - 18),
        const Color(0xFFF8B800),
        fontSize: 11,
      );
    }
  }

  // --- Detailed 8-Bit NES Sprite for archBTW (Modeled after User Photo!) ---
  // Dark swept hair + beard, black ear gauge, purple & black buffalo plaid flannel,
  // dark band tee with white gothic emblem & silver cross necklace, dark blue jeans,
  // and black & white Converse Chuck Taylor high-tops!
  static const List<String> _archBtwHeadAndTorsoMatrix = [
    '....KKKKKKKK....', // 0: Hair top outline
    '...KHHHHHHHHK...', // 1: Dark swept hair
    '..KHHHHHHHHHHK..', // 2: Swept bangs
    '..KHHSSSSSSHHK..', // 3: Forehead
    '..KHSKSSSSKSHK..', // 4: Eyes
    '..EGSSSSSSSSSK..', // 5: Black ear gauge (E/G) + cheeks
    '..KSSBBBBBBSSK..', // 6: Mustache
    '..KBBBBSSBBBBK..', // 7: Full dark beard
    '...KBBBBBBBBK...', // 8: Beard chin
    '....KKKKKKKK....', // 9: Neckline
    '..KKPKTTTTNPKK..', // 10: Flannel collar + silver cross necklace (N)
    '.KPKPKTWWWTKPkK.', // 11: Purple/black buffalo plaid + white band tee logo
    '.KPKPKTWWTWKPkK.', // 12: Plaid + band logo
    '.KPKPKTWWWTKPkK.', // 13: Plaid + band logo
    '.KSSPKTTTTTKPSSK', // 14: Rolled sleeves + forearms (S)
    '..KKPKTTTTTKPKK.', // 15: Lower flannel & tee
  ];

  void _drawArchBtwPlayer(Canvas canvas, double sx, double sy) {
    const double px = 3.2; // Chunky, detailed 8-bit pixels!
    final double spriteW = 16 * px;
    final double torsoH = 16 * px;
    final double legH = 8 * px;
    final double totalH = torsoH + legH;

    final int walkFrame = (walkCycle * 1.6).floor() % 4;
    final bool isKicking =
        currentAttack == OkcAttackKind.kick && attackTimer > 0;
    final bool isPunching =
        currentAttack == OkcAttackKind.punch && attackTimer > 0;

    canvas.save();
    canvas.translate(sx, sy);
    if (!facingRight) {
      canvas.scale(-1.0, 1.0);
    }

    // 1. Draw Head & Plaid Flannel Torso Matrix
    _drawPixelMatrix(
      canvas,
      _archBtwHeadAndTorsoMatrix,
      const {
        'K': Colors.black,
        'H': Color(0xFF141210), // Dark swept hair
        'B': Color(0xFF1C1917), // Full dark beard & mustache
        'S': Color(0xFFF3C6A5), // Skin tone
        'E': Colors.black, // Ear gauge rim
        'G': Color(0xFF38BDF8), // Ear gauge highlight
        'P': Color(0xFF9333EA), // Purple buffalo plaid squares
        'k': Color(0xFF1E1B4B), // Dark plaid squares
        'T': Color(0xFF1F242D), // Charcoal graphic band tee
        'W': Colors.white, // White gothic band logo on tee
        'N': Color(0xFFE2E8F0), // Silver cross necklace
      },
      pixelSize: px,
      origin: Offset(-spriteW / 2, -totalH),
    );

    final Paint p = Paint()..isAntiAlias = false;

    // 2. Draw 8-Bit Dark Blue Jeans & Black/White Converse Chuck Taylors
    final double hipY = -legH;
    final double leftLegOffset = isGrounded
        ? (walkFrame == 1 ? -px * 2 : (walkFrame == 3 ? px * 2 : 0.0))
        : -px * 2;
    final double rightLegOffset = isGrounded ? -leftLegOffset : px * 2;

    // Back Leg (Blue jeans + Converse shoe)
    _drawNesLegAndConverse(
      canvas,
      x: -px * 4 + leftLegOffset,
      y: hipY,
      px: px,
      denimColor: const Color(0xFF1D3557),
    );

    // Front Leg (or Extended 8-Bit Roundhouse Kick!)
    if (isKicking) {
      // Horizontal extended kicking leg in dark blue jeans + Converse high-top!
      p.color = Colors.black;
      canvas.drawRect(
        Rect.fromLTWH(px * 1, hipY - px * 3, px * 9, px * 4),
        p,
      );
      p.color = const Color(0xFF254B7C);
      canvas.drawRect(
        Rect.fromLTWH(px * 1, hipY - px * 2, px * 7, px * 2.5),
        p,
      );
      // Black & White Converse shoe at tip of kick
      p.color = const Color(0xFF0F172A);
      canvas.drawRect(
        Rect.fromLTWH(px * 7, hipY - px * 3, px * 3, px * 3),
        p,
      );
      p.color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(px * 9, hipY - px * 2, px * 2, px * 2),
        p,
      );
      // 8-Bit Gold Kick Spark Burst
      p.color = const Color(0xFFF8B800);
      canvas.drawRect(
        Rect.fromLTWH(px * 11, hipY - px * 5, px * 2, px * 2),
        p,
      );
      canvas.drawRect(
        Rect.fromLTWH(px * 12, hipY - px * 2, px * 3, px * 2),
        p,
      );
      canvas.drawRect(
        Rect.fromLTWH(px * 11, hipY + px * 1, px * 2, px * 2),
        p,
      );
    } else {
      _drawNesLegAndConverse(
        canvas,
        x: px * 1 + rightLegOffset,
        y: hipY,
        px: px,
        denimColor: const Color(0xFF254B7C),
      );
    }

    // 3. Draw 8-Bit Punching Arm & Hit Spark
    if (isPunching) {
      final double armY = -totalH + px * 11;
      p.color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(px * 3, armY - px, px * 10, px * 4), p);
      // Rolled purple flannel cuff
      p.color = const Color(0xFF9333EA);
      canvas.drawRect(Rect.fromLTWH(px * 3, armY, px * 3, px * 2.5), p);
      // Forearm & Fist
      p.color = const Color(0xFFF3C6A5);
      canvas.drawRect(Rect.fromLTWH(px * 6, armY, px * 6, px * 2.5), p);
      // 8-Bit Hit Star
      p.color = const Color(0xFFF8B800);
      canvas.drawRect(Rect.fromLTWH(px * 13, armY - px * 2, px * 2, px * 6), p);
      canvas.drawRect(Rect.fromLTWH(px * 11, armY, px * 6, px * 2), p);
    }

    // 4. Draw Equipped 8-Bit Modded Purple PRS Electric Guitar ("Fireflower" mode!)
    if (hasGuitar) {
      final double gy = -totalH + px * 11;
      // Guitar body in metallic purple with white pixel outline
      p.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(-px * 2, gy - px, px * 7, px * 5), p);
      p.color = const Color(0xFF9333EA);
      canvas.drawRect(Rect.fromLTWH(-px * 1, gy, px * 5, px * 3.5), p);
      // Guitar neck & headstock extending forward
      p.color = const Color(0xFFF8B800);
      canvas.drawRect(Rect.fromLTWH(px * 4, gy - px * 1, px * 6, px * 1.8), p);
      p.color = const Color(0xFF9333EA);
      canvas.drawRect(
        Rect.fromLTWH(px * 9, gy - px * 1.5, px * 2.5, px * 2.5),
        p,
      );
    }

    // 5. Spider Web-Shooter Wrist Pixel Glow
    if (hasSpiderPower) {
      p.color = const Color(0xFF3CBCFC);
      canvas.drawRect(
        Rect.fromLTWH(px * 4, -totalH + px * 13, px * 2, px * 2),
        p,
      );
    }

    canvas.restore();
  }

  void _drawNesLegAndConverse(
    Canvas canvas, {
    required double x,
    required double y,
    required double px,
    required Color denimColor,
  }) {
    final Paint p = Paint()..isAntiAlias = false;
    // Black pixel outline
    p.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(x - px * 0.5, y, px * 4, px * 8), p);
    // Dark blue denim jeans
    p.color = denimColor;
    canvas.drawRect(Rect.fromLTWH(x, y, px * 3, px * 5.5), p);
    // Black Converse Chuck Taylor upper
    p.color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(x, y + px * 5.5, px * 3.2, px * 2), p);
    // White Converse rubber toe-cap & white sole stripe
    p.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(x + px * 2.2, y + px * 5.8, px * 2.0, px * 1.8),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(x, y + px * 7.0, px * 4.2, px * 1.0),
      p,
    );
  }

  // --- Detailed 8-Bit Zombie Sprite ---
  static const List<String> _zombieMatrix = [
    '....KKKKKKKK....',
    '...KGGGGGGGGK...',
    '..KGGGGGGGGGGK..',
    '..KGGRRGGGRRGK..', // Glowing red zombie eyes
    '..KGGGGGGGGGGK..',
    '...KGGKKKKGGK...',
    '....KKKKKKKK....',
    '..KKCCCCCCCCKKKK',
    '.KCCCRRRRRCCCGGG', // Exposed ribs + outstretched zombie arms
    '.KCCCCCCCCCCCGGG',
    '.KCCCRRRRRCCCKKK',
    '..KKCCCCCCCCKK..',
    '...KPPPPPPPPK...',
    '...KPPK..KPPK...',
    '...KPPK..KPPK...',
    '...KKKK..KKKK...',
  ];

  void _drawZombie(Canvas canvas, OkcZombie z, double sx, double sy) {
    final double px = z.kind == OkcZombieKind.brute ? 3.8 : 3.0;
    final double w = 16 * px;
    final double h = 16 * px;
    final double shambleBob = ((z.walkPhase * 1.5).floor() % 2) * 3.0;

    final Color skinColor = z.hurtTimer > 0
        ? Colors.white
        : (z.kind == OkcZombieKind.runner
            ? const Color(0xFF84CC16)
            : const Color(0xFF58F898));
    final Color coatColor = z.kind == OkcZombieKind.brute
        ? const Color(0xFF581C87)
        : const Color(0xFF334155);

    canvas.save();
    canvas.translate(sx, sy - shambleBob);
    if (!z.facingRight) {
      canvas.scale(-1.0, 1.0);
    }

    _drawPixelMatrix(
      canvas,
      _zombieMatrix,
      {
        'K': Colors.black,
        'G': skinColor,
        'R': const Color(0xFFF83870), // Red eyes & ribs
        'C': coatColor,
        'P': const Color(0xFF1E293B),
      },
      pixelSize: px,
      origin: Offset(-w / 2, -h),
    );

    canvas.restore();

    // 8-Bit Pixel Zombie HP Bar
    if (z.hp < z.maxHp) {
      final double frac = (z.hp / z.maxHp).clamp(0.0, 1.0);
      final Paint p = Paint()..isAntiAlias = false;
      p.color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(sx - 18, sy - h - 12, 36, 7), p);
      p.color = const Color(0xFFF83870);
      canvas.drawRect(Rect.fromLTWH(sx - 16, sy - h - 10, 32 * frac, 3), p);
    }
  }

  // --- Detailed 8-Bit Powerups: Pills, Guitar, Spider, Pigeons ---
  static const List<String> _pillMatrix = [
    '..KKKKKKKKKK..',
    '.KRRRRRWWWWWK.',
    'KRRRRRRWWWWWWK',
    'KRRRRRRWWWWWWK',
    '.KRRRRRWWWWWK.',
    '..KKKKKKKKKK..',
  ];

  static const List<String> _guitarMatrix = [
    '.........KKKK.',
    '........KYYYYK',
    '.......KYYYYK.',
    '..KKKKKYYYYK..',
    '.KPPPPPKYYK...',
    'KPPWWPPPKK....',
    'KPPWWPPPK.....',
    '.KPPPPPK......',
    '..KKKKK.......',
  ];

  static const List<String> _spiderMatrix = [
    'K..K..KKKK..K..K',
    '.K.K.KRRRRK.K.K.',
    '..KKKRRRRRRKKK..',
    '....KRWWWWWRK...',
    '..KKKRRRRRRKKK..',
    '.K.K.KRRRRK.K.K.',
    'K..K..KKKK..K..K',
  ];

  static const List<String> _pigeonMatrix = [
    '........KKKK....',
    '.......KGGGGK...',
    '......KGGWKGGKK.',
    '.KKKK.KGGGGGGYYK',
    'KSSSSKKSSSSSSSSK',
    'KSSSSWWSSSSSSSSK',
    '.KSSSSSSSSSSSSK.',
    '..KKKKKKKKKKKK..',
    '....K.K...K.K...',
  ];

  void _drawPowerupItem(
    Canvas canvas,
    OkcPowerupItem item,
    double sx,
    double sy,
  ) {
    const double px = 2.8;
    switch (item.type) {
      case OkcPowerupType.pill:
        _drawPixelMatrix(
          canvas,
          _pillMatrix,
          const {
            'K': Colors.black,
            'R': Color(0xFFF83870),
            'W': Colors.white,
          },
          pixelSize: px,
          origin: Offset(sx - 7 * px, sy - 3 * px),
        );
        _drawLabel(
          canvas,
          '+HP PILL',
          Offset(sx, sy - 18),
          const Color(0xFF58F898),
          fontSize: 10,
          bold: true,
        );
        break;

      case OkcPowerupType.guitar:
        _drawPixelMatrix(
          canvas,
          _guitarMatrix,
          const {
            'K': Colors.black,
            'P': Color(0xFFB878F8),
            'W': Colors.white,
            'Y': Color(0xFFF8B800),
          },
          pixelSize: px,
          origin: Offset(sx - 7 * px, sy - 4.5 * px),
        );
        _drawLabel(
          canvas,
          'GUITAR [CHORDS]',
          Offset(sx, sy - 22),
          const Color(0xFFB878F8),
          fontSize: 10,
          bold: true,
        );
        break;

      case OkcPowerupType.spider:
        _drawPixelMatrix(
          canvas,
          _spiderMatrix,
          const {
            'K': Color(0xFF3CBCFC),
            'R': Color(0xFFF83870),
            'W': Colors.white,
          },
          pixelSize: px,
          origin: Offset(sx - 8 * px, sy - 3.5 * px),
        );
        _drawLabel(
          canvas,
          'SPIDER [WEB]',
          Offset(sx, sy - 22),
          const Color(0xFF3CBCFC),
          fontSize: 10,
          bold: true,
        );
        break;

      case OkcPowerupType.pigeon:
        _drawPixelMatrix(
          canvas,
          _pigeonMatrix,
          const {
            'K': Colors.black,
            'S': Color(0xFF94A3B8), // Slate pigeon feathers
            'W': Colors.white,
            'G': Color(0xFF58F898), // Iridescent green neck
            'Y': Color(0xFFF8B800), // Beak
          },
          pixelSize: px,
          origin: Offset(sx - 8 * px, sy - 4.5 * px),
        );
        _drawLabel(
          canvas,
          'PIGEON [+1 UP]',
          Offset(sx, sy - 22),
          const Color(0xFFF8B800),
          fontSize: 10,
          bold: true,
        );
        break;
    }
  }

  void _drawChordProjectile(
    Canvas canvas,
    OkcChordProjectile chord,
    double sx,
    double sy,
  ) {
    final Paint p = Paint()..isAntiAlias = false;
    final Rect box = Rect.fromCenter(
      center: Offset(sx, sy),
      width: 38,
      height: 20,
    );
    p.color = Colors.black;
    canvas.drawRect(box.inflate(2), p);
    p.color = chord.color;
    canvas.drawRect(box, p);
    p.color = Colors.black;
    canvas.drawRect(box.deflate(2), p);

    _drawLabel(
      canvas,
      '♪${chord.chordName}',
      Offset(sx, sy),
      Colors.white,
      fontSize: 11,
      bold: true,
    );
  }

  void _drawNesBannerLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double fontSize = 11,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'JetBrainsMono',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final Rect bgRect = Rect.fromCenter(
      center: center,
      width: tp.width + 10,
      height: tp.height + 6,
    );
    final Paint p = Paint()..isAntiAlias = false;
    p.color = Colors.black.withValues(alpha: 0.88);
    canvas.drawRect(bgRect, p);
    canvas.drawRect(
      bgRect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double fontSize = 10,
    bool bold = false,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'JetBrainsMono',
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 0, offset: Offset(1.5, 1.5)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _OkcRetroGamePainter oldDelegate) => true;
}
