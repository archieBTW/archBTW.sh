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

typedef OkcBeatEmUpGame = SuperArchBtw;
typedef OkcBeatEmUpGameState = SuperArchBtwState;

class SuperArchBtw extends StatefulWidget {
  const SuperArchBtw({super.key});

  @override
  State<SuperArchBtw> createState() => SuperArchBtwState();
}

class SuperArchBtwState extends State<SuperArchBtw>
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
  bool _showTitleScreen = true;

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
  bool get isTitleScreenShowing => _showTitleScreen;
  double get playerX => _playerX;
  double get playerY => _playerY;
  double get gooseX => _gooseX;
  double get gooseY => _gooseY;
  double get tortieCatX => _currentMap.tortieCatX;
  double get duchessX => _currentMap.tortieCatX;
  bool get duchessFed => _tortieCatFed;
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
    const double tortieCatX = 122.0;
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
      bx += bw + 68.0 + (rng.nextInt(4) * 22.0);
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

  void dismissTitleScreen() {
    if (_showTitleScreen) {
      setState(() {
        _showTitleScreen = false;
      });
    }
  }

  void triggerJump() {
    if (_isGameOver) return;
    _showTitleScreen = false;
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
    _showTitleScreen = false;
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
    _showTitleScreen = false;
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
    _showTitleScreen = false;
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
      _showTitleScreen = false;
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
      _showTitleScreen = false;
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
              text: 'PURPLE PRS EQUIPPED! POWER CHORDS!',
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
      _showTitleScreen = false;
      _hasCatFood = true;
      _tortieCatFed = true;
      _score += 500 * _level;
      _health = min(_maxHealth, _health + 25);
      _levelClearBannerTimer = 1.8;
      _generateAndLoadLevel(_level + 1);
    });
  }

  void applyControllerInput(GamepadInputState gamepad) {
    if (gamepad.connected &&
        (gamepad.axisX.abs() > 0.1 ||
            gamepad.jumpPressed ||
            gamepad.punchPressed ||
            gamepad.kickPressed ||
            gamepad.chordPressed ||
            gamepad.webPressed ||
            gamepad.mountPressed)) {
      _showTitleScreen = false;
    }
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
    if (_showTitleScreen && !_isRidingGoose) return;

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
          text: 'DUCHESS: MEOW! FOOD IS AT THE END! ->',
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
      if (_showTitleScreen) {
        setState(() {
          _showTitleScreen = false;
        });
      }
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
          'super_archbtw.sh',
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

                // Minimal Top HUD (Health Bar, Lives, Score, Active Powerups)
                Positioned(
                  top: 8,
                  left: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: _buildTopHud(isCompact),
                  ),
                ),

                // Level Clear 8-Bit Banner
                if (_levelClearBannerTimer > 0)
                  Positioned(
                    top: isCompact ? 50 : 58,
                    left: 20,
                    right: 20,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 14 : 20,
                            vertical: isCompact ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            border: Border.all(
                              color: const Color(0xFFF8B800),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'DUCHESS FED! NEW DOWNTOWN OKC MAP: LVL $_level',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFF8B800),
                              fontFamily: 'JetBrainsMono',
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 12 : 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 'super archBTW' 8-Bit Arcade Title Screen Overlay
                if (_showTitleScreen && !_isGameOver)
                  Positioned.fill(
                    child: _buildTitleScreenOverlay(isCompact),
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
                          _showTitleScreen = false;
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
    final double hpFraction = (_health / _maxHealth).clamp(0.0, 1.0);
    final Color hpColor = hpFraction > 0.4
        ? const Color(0xFF58F898)
        : const Color(0xFFF83870);
    final double fontSize = isCompact ? 11.0 : 12.0;
    final double barWidth = isCompact ? 100.0 : 136.0;

    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HP',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  shadows: const [
                    Shadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: barWidth,
                height: isCompact ? 10 : 12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: hpFraction,
                  child: Container(color: hpColor),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_lives}UP',
                style: TextStyle(
                  color: const Color(0xFFF8B800),
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  shadows: const [
                    Shadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_score',
                style: TextStyle(
                  color: const Color(0xFF3CBCFC),
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  shadows: const [
                    Shadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                  ],
                ),
              ),
            ],
          ),
          if (_isRidingGoose)
            _buildStatusBadge(
              label: 'MOUNT: GOOSE',
              color: const Color(0xFFF8B800),
              fontSize: fontSize - 1,
            ),
          if (_hasGuitar)
            _buildStatusBadge(
              label: 'GUITAR: CHORDS',
              color: const Color(0xFFB878F8),
              fontSize: fontSize - 1,
            ),
          if (_hasSpiderPower)
            _buildStatusBadge(
              label: 'SPIDER: WEB',
              color: const Color(0xFF3CBCFC),
              fontSize: fontSize - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required Color color,
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1.5),
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

  Widget _buildTitleScreenOverlay(bool isCompact) {
    final bool blink = ((_worldTime * 3.0).floor() % 2) == 0;
    return GestureDetector(
      key: const Key('super_archbtw_title_screen'),
      behavior: HitTestBehavior.translucent,
      onTap: dismissTitleScreen,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 24,
          vertical: isCompact ? 6 : 12,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 18 : 32,
              vertical: isCompact ? 12 : 20,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF090514).withValues(alpha: 0.96),
              border: Border.all(
                color: const Color(0xFFB878F8),
                width: 3.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF5E117C),
                  offset: Offset(6, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: isCompact ? 10 : 14),
                Text(
                  'super archBTW',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'JetBrainsMono',
                    fontSize: isCompact ? 28 : 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    shadows: const [
                      Shadow(
                        color: Color(0xFF8B3DD6),
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      ),
                      Shadow(
                        color: Color(0xFF3CBCFC),
                        offset: Offset(-2, -2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 16),
                SizedBox(
                  width: isCompact ? 240 : 300,
                  height: isCompact ? 120 : 152,
                  child: CustomPaint(
                    painter: _SuperArchBtwTitleHeroPainter(
                      worldTime: _worldTime,
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 12 : 18),
                ElevatedButton(
                  key: const Key('start_game_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blink
                        ? const Color(0xFFB878F8)
                        : const Color(0xFFF8B800),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 20 : 28,
                      vertical: isCompact ? 10 : 14,
                    ),
                    shape: const RoundedRectangleBorder(
                      side: BorderSide(color: Colors.white, width: 2.5),
                    ),
                  ),
                  onPressed: dismissTitleScreen,
                  child: Text(
                    '[ PRESS START ]',
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

  void _drawPixelCircle(
    Canvas canvas,
    Offset center,
    double radius, {
    required double pixelSize,
    required Color color,
  }) {
    final int steps = max(24, (radius * 2 * pi / pixelSize).ceil());
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (int i = 0; i < steps; i++) {
      final double a = (i / steps) * 2 * pi;
      final double x =
          ((center.dx + cos(a) * radius) / pixelSize).floor() * pixelSize;
      final double y =
          ((center.dy + sin(a) * radius) / pixelSize).floor() * pixelSize;
      canvas.drawRect(Rect.fromLTWH(x, y, pixelSize, pixelSize), paint);
    }
  }

  void _drawOkcSkylineParallax(
    Canvas canvas,
    Size size,
    double groundScreenY,
  ) {
    final double parallaxX = cameraX * 0.22;
    final Paint p = Paint()..isAntiAlias = false;
    const double spanW = 760.0;

    double wrapX(double baseOffset, double factor) {
      final double raw = (baseOffset - parallaxX * factor) % spanW;
      return ((raw < 0 ? raw + spanW : raw) - 80.0).floorToDouble();
    }

    // 1. 8-Bit Pixel Stars & Cross Twinkles
    for (int i = 0; i < 28; i++) {
      final double sx =
          (((i * 137.0 - parallaxX * 0.3) % size.width + size.width) %
                  size.width /
                  3.0)
              .floor() *
              3.0;
      final double sy =
          (((i * 43.0) % (groundScreenY * 0.50)) / 3.0).floor() * 3.0;
      final bool twinkle = ((worldTime * 3.0 + i).floor() % 4) == 0;
      p.color = twinkle ? const Color(0xFFF8B800) : Colors.white70;
      canvas.drawRect(Rect.fromLTWH(sx, sy, 3, 3), p);
      if (twinkle) {
        canvas.drawRect(Rect.fromLTWH(sx - 3, sy, 9, 3), p);
        canvas.drawRect(Rect.fromLTWH(sx, sy - 3, 3, 9), p);
      }
    }

    // 2. Distant Horizon Silhouette Band & Oklahoma State Capitol Dome (far background)
    p.color = const Color(0xFF090D1E);
    canvas.drawRect(Rect.fromLTWH(0, groundScreenY - 36, size.width, 36), p);

    final double capitolX = wrapX(780.0, 0.25);
    final double capBaseY = groundScreenY - 36;
    // Classical colonnade base + ribbed neoclassical dome + lantern cupola
    p.color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromLTWH(capitolX - 38, capBaseY - 26, 76, 26), p);
    p.color = const Color(0xFF334155);
    canvas.drawRect(Rect.fromLTWH(capitolX - 24, capBaseY - 42, 48, 16), p);
    // Colonnade pillars
    p.color = const Color(0xFF94A3B8);
    for (double cx = capitolX - 20; cx <= capitolX + 18; cx += 6) {
      canvas.drawRect(Rect.fromLTWH(cx, capBaseY - 38, 2, 12), p);
    }
    // Illuminated white/gold Capitol dome steps
    p.color = const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(capitolX - 18, capBaseY - 52, 36, 10), p);
    canvas.drawRect(Rect.fromLTWH(capitolX - 13, capBaseY - 60, 26, 8), p);
    canvas.drawRect(Rect.fromLTWH(capitolX - 7, capBaseY - 66, 14, 6), p);
    p.color = const Color(0xFFF8B800); // Guardian statue & lantern top
    canvas.drawRect(Rect.fromLTWH(capitolX - 2, capBaseY - 74, 4, 8), p);

    // 3. Historic Oklahoma Lattice Oil Derrick & Animated Pumpjack (Nodding Donkey)
    final double oilX = wrapX(90.0, 0.30);
    // Tapered steel lattice derrick tower
    _drawPixelLine(
      canvas,
      Offset(oilX - 14, groundScreenY),
      Offset(oilX - 3, groundScreenY - 78),
      pixelSize: 2.0,
      color: const Color(0xFF475569),
    );
    _drawPixelLine(
      canvas,
      Offset(oilX + 14, groundScreenY),
      Offset(oilX + 3, groundScreenY - 78),
      pixelSize: 2.0,
      color: const Color(0xFF475569),
    );
    p.color = const Color(0xFF64748B);
    canvas.drawRect(Rect.fromLTWH(oilX - 5, groundScreenY - 82, 10, 5), p);
    for (int g = 1; g <= 5; g++) {
      final double gy = groundScreenY - g * 14.0;
      final double hw = 14.0 - g * 2.0;
      canvas.drawRect(Rect.fromLTWH(oilX - hw, gy, hw * 2, 2), p);
    }
    // Animated rocking pumpjack ("horsehead") beside the derrick
    final double pumpTilt = sin(worldTime * 2.6) * 6.0;
    final double pjX = oilX + 28.0;
    p.color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromLTWH(pjX - 6, groundScreenY - 22, 12, 22), p);
    _drawPixelLine(
      canvas,
      Offset(pjX - 14, groundScreenY - 22 - pumpTilt),
      Offset(pjX + 14, groundScreenY - 22 + pumpTilt),
      pixelSize: 3.0,
      color: const Color(0xFF94A3B8),
    );
    // Horsehead arc at right end of walking beam
    p.color = const Color(0xFFF8B800);
    canvas.drawRect(
      Rect.fromLTWH(pjX + 12, groundScreenY - 26 + pumpTilt, 6, 10),
      p,
    );

    // 4. Scissortail Park Skydance Bridge (Soaring Scissortail Flycatcher Bird Wings!)
    final double bridgeX = wrapX(255.0, 0.36);
    // Illuminated pedestrian bridge deck & support piers
    p.color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromLTWH(bridgeX - 56, groundScreenY - 38, 112, 7), p);
    p.color = const Color(0xFF38BDF8);
    canvas.drawRect(Rect.fromLTWH(bridgeX - 56, groundScreenY - 39, 112, 2), p);
    p.color = const Color(0xFF334155);
    canvas.drawRect(Rect.fromLTWH(bridgeX - 38, groundScreenY - 32, 6, 32), p);
    canvas.drawRect(Rect.fromLTWH(bridgeX + 32, groundScreenY - 32, 6, 32), p);
    // Iconic soaring asymmetrical white steel scissor-tail wings
    // Tall main tail feather sweeping up-left
    _drawPixelLine(
      canvas,
      Offset(bridgeX - 8, groundScreenY - 38),
      Offset(bridgeX - 36, groundScreenY - 128),
      pixelSize: 2.5,
      color: const Color(0xFFE2E8F0),
    );
    _drawPixelLine(
      canvas,
      Offset(bridgeX + 6, groundScreenY - 38),
      Offset(bridgeX - 36, groundScreenY - 128),
      pixelSize: 2.0,
      color: const Color(0xFF94A3B8),
    );
    // Secondary forked scissor-tail feather sweeping up-right
    _drawPixelLine(
      canvas,
      Offset(bridgeX - 4, groundScreenY - 38),
      Offset(bridgeX + 28, groundScreenY - 114),
      pixelSize: 2.5,
      color: const Color(0xFFE2E8F0),
    );
    _drawPixelLine(
      canvas,
      Offset(bridgeX + 10, groundScreenY - 38),
      Offset(bridgeX + 28, groundScreenY - 114),
      pixelSize: 2.0,
      color: const Color(0xFF94A3B8),
    );
    // Lower third wing strut
    _drawPixelLine(
      canvas,
      Offset(bridgeX + 4, groundScreenY - 38),
      Offset(bridgeX + 42, groundScreenY - 82),
      pixelSize: 2.0,
      color: const Color(0xFFCBD5E1),
    );
    // Warm sunset/neon uplighting glow at base of Skydance wings
    p.color = map.neonAccent.withValues(alpha: 0.75);
    canvas.drawRect(Rect.fromLTWH(bridgeX - 10, groundScreenY - 46, 22, 8), p);

    // 5. Downtown OKC Skyscraper Cluster:
    //    (a) BancFirst Tower (dark bronze modernist tower)
    //    (b) Devon Energy Center (844 ft glass diagrid tower with V-notch twin peaks)
    //    (c) First National Center (1931 Art Deco stepped limestone skyscraper + pyramid spire)
    final double clusterX = wrapX(490.0, 0.45);

    // (a) BancFirst Tower (left of Devon)
    final double bancX = clusterX - 78.0;
    const double bancW = 54.0;
    const double bancH = 168.0;
    final double bancTopY = groundScreenY - bancH;
    p.color = const Color(0xFF1C1917); // Dark bronze-espresso facade
    canvas.drawRect(Rect.fromLTWH(bancX, bancTopY, bancW, bancH), p);
    p.color = const Color(0xFF44403C);
    canvas.drawRect(Rect.fromLTWH(bancX, bancTopY, bancW, 8), p);
    // Illuminated white mechanical penthouse crown
    p.color = const Color(0xFFFDE68A);
    canvas.drawRect(Rect.fromLTWH(bancX + 8, bancTopY + 3, bancW - 16, 4), p);
    // Vertical bronze mullion pinstripes & warm office windows
    for (double wx = bancX + 5; wx < bancX + bancW - 4; wx += 6) {
      p.color = const Color(0xFF292524);
      canvas.drawRect(Rect.fromLTWH(wx, bancTopY + 10, 2, bancH - 14), p);
      for (double wy = bancTopY + 14; wy < groundScreenY - 12; wy += 12) {
        if (((wx.toInt() + wy.toInt()) % 3) != 0) {
          p.color = const Color(0xFFFDE68A).withValues(alpha: 0.45);
          canvas.drawRect(Rect.fromLTWH(wx + 2, wy, 3, 6), p);
        }
      }
    }

    // (b) Devon Energy Center (OKC's 50-story flagship glass tower!)
    final double devonX = clusterX;
    const double towerW = 68.0;
    const double towerH = 236.0;
    final double topY = groundScreenY - towerH;

    // Main tapered blue-glass tower shaft
    p.color = const Color(0xFF0F2442);
    canvas.drawRect(Rect.fromLTWH(devonX, topY + 26, towerW, towerH - 26), p);
    // Chamfered lighter cyan-glass center facet
    p.color = const Color(0xFF16355D);
    canvas.drawRect(
      Rect.fromLTWH(devonX + 10, topY + 22, towerW - 20, towerH - 22),
      p,
    );
    // Iconic twin peaked parapet fins with V-notch crown at top of Devon Tower
    for (int step = 0; step < 7; step++) {
      final double y = topY + step * 4.0;
      final double w = 6.0 + step * 3.5;
      p.color = const Color(0xFF1E40AF);
      // Left peak fin
      canvas.drawRect(Rect.fromLTWH(devonX + 4, y, w, 4.0), p);
      // Right peak fin
      canvas.drawRect(Rect.fromLTWH(devonX + towerW - 4 - w, y, w, 4.0), p);
    }
    // Bright cyan glass curtain-wall edges & horizontal sky-lobby bands
    p.color = const Color(0xFF38BDF8);
    canvas.drawRect(Rect.fromLTWH(devonX, topY + 26, 2, towerH - 26), p);
    canvas.drawRect(
      Rect.fromLTWH(devonX + towerW - 2, topY + 26, 2, towerH - 26),
      p,
    );
    canvas.drawRect(Rect.fromLTWH(devonX + 10, topY + 22, 2, towerH - 22), p);
    canvas.drawRect(
      Rect.fromLTWH(devonX + towerW - 12, topY + 22, 2, towerH - 22),
      p,
    );
    // Glass window grid & diagonal X-bracing highlights
    for (double wy = topY + 32; wy < groundScreenY - 12; wy += 9) {
      p.color = const Color(0xFF0284C7).withValues(alpha: 0.35);
      canvas.drawRect(Rect.fromLTWH(devonX + 4, wy, towerW - 8, 2), p);
      for (double wx = devonX + 14; wx < devonX + towerW - 14; wx += 9) {
        p.color = const Color(0xFF7DD3FC).withValues(alpha: 0.55);
        canvas.drawRect(Rect.fromLTWH(wx, wy + 2, 5, 4), p);
      }
    }
    // Blinking red aviation beacons on Devon's twin peaks
    if ((worldTime * 4).floor().isEven) {
      p.color = const Color(0xFFF83870);
      canvas.drawRect(Rect.fromLTWH(devonX + 4, topY - 4, 4, 4), p);
      canvas.drawRect(Rect.fromLTWH(devonX + towerW - 8, topY - 4, 4, 4), p);
    }

    // (c) First National Center (1931 Art Deco stepped-setback limestone tower + spire)
    final double fncX = clusterX + 82.0;
    const double fncW = 60.0;
    const double fncH = 182.0;
    final double fncTopY = groundScreenY - fncH;
    // Lower wide limestone base
    p.color = const Color(0xFF57534E);
    canvas.drawRect(Rect.fromLTWH(fncX, fncTopY + 56, fncW, fncH - 56), p);
    // Middle Art Deco setback shaft
    p.color = const Color(0xFF78716C);
    canvas.drawRect(Rect.fromLTWH(fncX + 8, fncTopY + 24, fncW - 16, 32), p);
    // Upper Art Deco tower lantern
    p.color = const Color(0xFFA8A29E);
    canvas.drawRect(Rect.fromLTWH(fncX + 16, fncTopY + 8, fncW - 32, 16), p);
    // Sloped pyramid crown & tall silver Art Deco spire
    p.color = const Color(0xFF14B8A6); // Aged copper pyramid roof
    canvas.drawRect(Rect.fromLTWH(fncX + 18, fncTopY + 2, fncW - 36, 6), p);
    canvas.drawRect(Rect.fromLTWH(fncX + 22, fncTopY - 4, fncW - 44, 6), p);
    p.color = const Color(0xFFF8FAFC);
    canvas.drawRect(Rect.fromLTWH(fncX + fncW / 2 - 1, fncTopY - 28, 3, 24), p);
    p.color = const Color(0xFFF8B800);
    canvas.drawRect(Rect.fromLTWH(fncX + fncW / 2 - 2, fncTopY - 32, 5, 5), p);
    // Vertical Art Deco recessed window spandrels
    for (double wx = fncX + 6; wx < fncX + fncW - 6; wx += 8) {
      p.color = const Color(0xFF292524);
      canvas.drawRect(Rect.fromLTWH(wx, fncTopY + 62, 4, fncH - 68), p);
      p.color = const Color(0xFFFDE68A).withValues(alpha: 0.55);
      for (double wy = fncTopY + 66; wy < groundScreenY - 12; wy += 10) {
        canvas.drawRect(Rect.fromLTWH(wx + 1, wy, 2, 5), p);
      }
    }

    // 6. Wheeler District Santa Monica Ferris Wheel on the Oklahoma River
    //    (Full double circular steel rims, 12 rotating radial spokes, glowing hub & gondolas!)
    final double wheelCenterX = wrapX(350.0, 0.35);
    final Offset wc = Offset(wheelCenterX, groundScreenY - 68);
    const double wr = 42.0;

    // Outer & inner circular pixel steel rims
    _drawPixelCircle(
      canvas,
      wc,
      wr,
      pixelSize: 2.5,
      color: const Color(0xFF38BDF8),
    );
    _drawPixelCircle(
      canvas,
      wc,
      wr - 9.0,
      pixelSize: 2.0,
      color: const Color(0xFFB878F8),
    );

    // 12 Rotating Radial Spokes & Swinging Gondola Cars
    for (int i = 0; i < 12; i++) {
      final double a = worldTime * 0.35 + (i * pi / 6);
      final double gx = (wc.dx + cos(a) * wr).floorToDouble();
      final double gy = (wc.dy + sin(a) * wr).floorToDouble();
      // Radial steel spoke from center hub to outer rim
      _drawPixelLine(
        canvas,
        wc,
        Offset(gx, gy),
        pixelSize: 1.5,
        color: const Color(0xFF64748B),
      );
      // Gondola bucket hanging below its rim pin
      final Color carColor = i.isEven
          ? map.neonAccent
          : (i % 3 == 0 ? const Color(0xFFF83870) : const Color(0xFFF8B800));
      p.color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(gx - 4, gy - 2, 8, 9), p);
      p.color = carColor;
      canvas.drawRect(Rect.fromLTWH(gx - 3, gy - 1, 6, 3), p); // Canopy top
      p.color = const Color(0xFFFDE68A);
      canvas.drawRect(Rect.fromLTWH(gx - 2, gy + 2, 4, 4), p); // Lit cabin
    }

    // Support A-frame legs & glowing center star hub
    _drawPixelLine(
      canvas,
      wc,
      Offset(wc.dx - 26, groundScreenY),
      pixelSize: 3.0,
      color: const Color(0xFF475569),
    );
    _drawPixelLine(
      canvas,
      wc,
      Offset(wc.dx + 26, groundScreenY),
      pixelSize: 3.0,
      color: const Color(0xFF475569),
    );
    p.color = Colors.black;
    canvas.drawRect(Rect.fromCenter(center: wc, width: 12, height: 12), p);
    p.color = const Color(0xFFF8B800);
    canvas.drawRect(Rect.fromCenter(center: wc, width: 8, height: 8), p);
  }

  void _drawDistrictBuildings(
    Canvas canvas,
    Size size,
    double groundScreenY,
  ) {
    final double midScroll = (cameraX * 0.65).floorToDouble();
    final Paint p = Paint()..isAntiAlias = false;

    for (int bIdx = 0; bIdx < map.buildings.length; bIdx++) {
      final OkcBuilding b = map.buildings[bIdx];
      final double bx = (b.x - midScroll).floorToDouble();
      if (bx + b.width < -90 || bx > size.width + 90) continue;
      final double topY = (groundScreenY - b.height).floorToDouble();
      final int archStyle = bIdx % 6;

      if (archStyle == 2) {
        // --- STYLE 2: MYRIAD BOTANICAL GARDENS CRYSTAL BRIDGE CONSERVATORY ---
        // Translucent cylindrical glass barrel-vault conservatory with white space-frame ribs
        // and lush pixel palm trees & tropical foliage inside!
        final double domeH = min(b.height, 148.0);
        final double domeTopY = groundScreenY - domeH;

        // Stepped cylindrical glass arch profile
        for (int s = 0; s < 6; s++) {
          final double inset = (5 - s) * 4.0;
          final double sy = domeTopY + (5 - s) * 5.0;
          final double sh = domeH - (5 - s) * 5.0;
          p.color = Colors.black;
          canvas.drawRect(
            Rect.fromLTWH(bx + inset - 2, sy - 2, b.width - inset * 2 + 4, sh + 2),
            p,
          );
          p.color = const Color(0xFF0D3B4C);
          canvas.drawRect(
            Rect.fromLTWH(bx + inset, sy, b.width - inset * 2, sh),
            p,
          );
        }

        // Glowing emerald/cyan conservatory interior + pixel palm trees & ferns
        p.color = const Color(0xFF0F766E);
        canvas.drawRect(
          Rect.fromLTWH(bx + 10, domeTopY + 26, b.width - 20, domeH - 30),
          p,
        );
        for (double tx = bx + 28; tx < bx + b.width - 24; tx += 36) {
          // Palm trunk
          p.color = const Color(0xFF78350F);
          canvas.drawRect(Rect.fromLTWH(tx - 2, groundScreenY - 62, 5, 58), p);
          // Lush green palm fronds
          p.color = const Color(0xFF22C55E);
          canvas.drawRect(Rect.fromLTWH(tx - 16, groundScreenY - 70, 32, 8), p);
          canvas.drawRect(Rect.fromLTWH(tx - 12, groundScreenY - 78, 24, 8), p);
          p.color = const Color(0xFF4ADE80);
          canvas.drawRect(Rect.fromLTWH(tx - 8, groundScreenY - 74, 16, 4), p);
        }

        // White tubular steel space-frame ribs & diagonal X-trusses
        p.color = const Color(0xFFE2E8F0);
        for (double rx = bx + 8; rx <= bx + b.width - 8; rx += 22) {
          canvas.drawRect(Rect.fromLTWH(rx, domeTopY + 12, 3, domeH - 12), p);
        }
        for (double ry = domeTopY + 26; ry < groundScreenY - 12; ry += 24) {
          canvas.drawRect(Rect.fromLTWH(bx + 6, ry, b.width - 12, 3), p);
        }
        continue;
      }

      if (archStyle == 3) {
        // --- STYLE 3: ICONIC OKC SONIC DRIVE-IN CANOPY & RETRO BOOMERANG PYLON ---
        final double canopyH = 92.0;
        final double canopyTopY = groundScreenY - canopyH;

        // Background brick drive-in kitchen building
        p.color = Colors.black;
        canvas.drawRect(
          Rect.fromLTWH(bx + 8, canopyTopY - 26, b.width - 16, canopyH + 26),
          p,
        );
        p.color = const Color(0xFF7F1D1D);
        canvas.drawRect(
          Rect.fromLTWH(bx + 11, canopyTopY - 23, b.width - 22, canopyH + 23),
          p,
        );

        // Tall Retro Mid-Century Atomic Boomerang Pylon Sign rising above the drive-in
        final double pylonX = bx + b.width * 0.5;
        p.color = const Color(0xFFE2E8F0);
        canvas.drawRect(Rect.fromLTWH(pylonX - 3, canopyTopY - 86, 6, 86), p);
        // Red & yellow retro boomerang arrow fin
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(pylonX - 28, canopyTopY - 78, 56, 24), p);
        p.color = const Color(0xFFEF4444);
        canvas.drawRect(Rect.fromLTWH(pylonX - 25, canopyTopY - 75, 50, 18), p);
        p.color = const Color(0xFFFACC15);
        canvas.drawRect(Rect.fromLTWH(pylonX - 19, canopyTopY - 70, 38, 8), p);

        // Zig-Zag Googie Folded-Plate Cantilevered Canopy Roof (cream, red & cyan)
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(bx - 4, canopyTopY - 4, b.width + 8, 18), p);
        p.color = const Color(0xFFF8FAFC);
        canvas.drawRect(Rect.fromLTWH(bx - 1, canopyTopY - 1, b.width + 2, 6), p);
        p.color = const Color(0xFFEF4444);
        canvas.drawRect(Rect.fromLTWH(bx - 1, canopyTopY + 5, b.width + 2, 4), p);
        p.color = const Color(0xFF38BDF8);
        canvas.drawRect(Rect.fromLTWH(bx - 1, canopyTopY + 9, b.width + 2, 3), p);

        // Glowing Carhop Menu Stalls & Speaker Posts
        for (double sx = bx + 18; sx < bx + b.width - 24; sx += 34) {
          p.color = const Color(0xFFCBD5E1);
          canvas.drawRect(
            Rect.fromLTWH(sx, canopyTopY + 14, 3, canopyH - 14),
            p,
          );
          // Lit turquoise/amber menu board
          p.color = Colors.black;
          canvas.drawRect(Rect.fromLTWH(sx + 5, groundScreenY - 44, 18, 22), p);
          p.color = const Color(0xFF38BDF8);
          canvas.drawRect(Rect.fromLTWH(sx + 7, groundScreenY - 42, 14, 18), p);
          p.color = const Color(0xFFFDE68A);
          canvas.drawRect(Rect.fromLTWH(sx + 9, groundScreenY - 39, 10, 6), p);
        }

        // Classic 1950s Cherry-Red Tailfin Muscle Cruiser parked under the canopy
        final double carX = bx + b.width - 58;
        final double carY = groundScreenY - 22;
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(carX - 2, carY - 2, 48, 20), p);
        p.color = const Color(0xFFDC2626); // Cherry red body
        canvas.drawRect(Rect.fromLTWH(carX, carY + 4, 44, 10), p);
        p.color = const Color(0xFFBAE6FD); // Wrap-around windshield cabin
        canvas.drawRect(Rect.fromLTWH(carX + 10, carY - 2, 20, 6), p);
        p.color = const Color(0xFFF8FAFC); // Whitewall side-trim & tailfin
        canvas.drawRect(Rect.fromLTWH(carX + 2, carY + 8, 40, 2), p);
        p.color = Colors.black; // Tires
        canvas.drawRect(Rect.fromLTWH(carX + 6, carY + 12, 9, 9), p);
        canvas.drawRect(Rect.fromLTWH(carX + 30, carY + 12, 9, 9), p);
        continue;
      }

      // --- STANDARD / LANDMARK TALL FACADE BASE (Styles 0, 1, 4, 5) ---
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
      // Corbeled dentil blocks along roofline
      p.color = Colors.black;
      for (double dx = bx + 4; dx < bx + b.width - 4; dx += 10) {
        canvas.drawRect(Rect.fromLTWH(dx, topY + 6, 4, 4), p);
      }

      // 8-Bit Brick mortar pixel rows on brick buildings
      if (b.isBrick) {
        p.color = const Color(0xFF480C0C);
        for (double by = topY + 14; by < groundScreenY; by += 12) {
          canvas.drawRect(Rect.fromLTWH(bx, by, b.width, 2), p);
        }
      }

      // Architectural Windows (Arched Romanesque in Bricktown Style 0, Loft Muntins otherwise)
      final double padX = 12.0;
      final double padY = 26.0;
      final double availH = b.height - padY - 46.0;
      final double cellW = (b.width - padX * 2) / max(1, b.windowCols);
      final double cellH = max(22.0, availH / max(1, b.windowRows));
      for (int r = 0; r < b.windowRows; r++) {
        final double wy = (topY + padY + r * cellH).floorToDouble();
        if (wy + 16 > groundScreenY - 42) break;
        for (int c = 0; c < b.windowCols; c++) {
          final bool lit = ((r * 7 + c * 13 + b.windowRows) % 3) != 0;
          final double wx = (bx + padX + c * cellW + 3).floorToDouble();
          final double ww = max(10.0, (cellW - 8).floorToDouble());
          final double wh = max(12.0, (cellH - 8).floorToDouble());

          // Window frame & limestone keystone arch
          p.color = b.trimColor;
          canvas.drawRect(Rect.fromLTWH(wx - 2, wy - 4, ww + 4, 3), p);
          p.color = Colors.black;
          canvas.drawRect(Rect.fromLTWH(wx - 2, wy - 2, ww + 4, wh + 4), p);
          p.color = lit ? const Color(0xFFF8D870) : const Color(0xFF0C1020);
          canvas.drawRect(Rect.fromLTWH(wx, wy, ww, wh), p);
          // Window pane muntin crossbars
          p.color = Colors.black;
          canvas.drawRect(Rect.fromLTWH(wx + ww / 2 - 1, wy, 2, wh), p);
          canvas.drawRect(Rect.fromLTWH(wx, wy + wh / 2 - 1, ww, 2), p);
        }
      }

      if (archStyle == 0) {
        // --- STYLE 0: BRICKTOWN WAREHOUSE WATER TOWER, FIRE ESCAPE & CANAL ARCH ---
        // 1. Rooftop Wooden Stave Water Tank on Steel Trestle Legs
        final double wtX = bx + 16.0;
        p.color = const Color(0xFF334155);
        canvas.drawRect(Rect.fromLTWH(wtX + 3, topY - 20, 3, 18), p);
        canvas.drawRect(Rect.fromLTWH(wtX + 20, topY - 20, 3, 18), p);
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(wtX - 2, topY - 44, 30, 26), p);
        p.color = const Color(0xFF92400E); // Cedar wood barrel staves
        canvas.drawRect(Rect.fromLTWH(wtX, topY - 42, 26, 22), p);
        p.color = const Color(0xFF451A03); // Iron barrel hoops
        canvas.drawRect(Rect.fromLTWH(wtX, topY - 36, 26, 2), p);
        canvas.drawRect(Rect.fromLTWH(wtX, topY - 27, 26, 2), p);
        // Conical roof cap on water tower
        p.color = const Color(0xFF78350F);
        canvas.drawRect(Rect.fromLTWH(wtX + 3, topY - 48, 20, 4), p);
        canvas.drawRect(Rect.fromLTWH(wtX + 8, topY - 52, 10, 4), p);

        // 2. Ground-level Bricktown Canal Stone Archway & Shimmering Water Taxi Tunnel
        final double archW = min(56.0, b.width - 28.0);
        final double archX = bx + (b.width - archW) / 2;
        final double archTopY = groundScreenY - 36.0;
        p.color = const Color(0xFF94A3B8); // Limestone arch voussoirs
        canvas.drawRect(Rect.fromLTWH(archX - 4, archTopY - 4, archW + 8, 40), p);
        p.color = const Color(0xFF082F49); // Deep canal tunnel
        canvas.drawRect(Rect.fromLTWH(archX, archTopY, archW, 36), p);
        p.color = const Color(0xFF38BDF8); // Shimmering Bricktown Canal water at base
        canvas.drawRect(Rect.fromLTWH(archX, groundScreenY - 10, archW, 10), p);
        p.color = const Color(0xFF7DD3FC);
        canvas.drawRect(Rect.fromLTWH(archX + 6, groundScreenY - 7, archW - 12, 3), p);
        // Warm Edison festoon string bulbs across the canal arch
        p.color = const Color(0xFFFDE68A);
        for (double lx = archX + 6; lx < archX + archW - 4; lx += 10) {
          canvas.drawRect(Rect.fromLTWH(lx, archTopY + 4, 3, 3), p);
        }
      } else if (archStyle == 1) {
        // --- STYLE 1: HISTORIC TOWER THEATRE (UPTOWN 23RD) ---
        // Tall stepped Art Deco vertical neon fin tower rising above the roof
        // + 3D cantilevered neon street marquee & ticket booth!
        final double cx = bx + b.width * 0.5;

        // Vertical Art Deco turquoise/magenta neon pilasters along facade edges
        p.color = const Color(0xFF2DD4BF);
        canvas.drawRect(Rect.fromLTWH(bx + 4, topY + 10, 4, b.height - 48), p);
        canvas.drawRect(
          Rect.fromLTWH(bx + b.width - 8, topY + 10, 4, b.height - 48),
          p,
        );

        // Iconic Towering Vertical Fin Sign above roofline
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(cx - 12, topY - 62, 24, 62), p);
        p.color = const Color(0xFFBE123C); // Deep crimson Art Deco fin
        canvas.drawRect(Rect.fromLTWH(cx - 9, topY - 59, 18, 56), p);
        p.color = const Color(0xFF2DD4BF); // Neon turquoise border & vertical tubes
        canvas.drawRect(Rect.fromLTWH(cx - 9, topY - 59, 3, 56), p);
        canvas.drawRect(Rect.fromLTWH(cx + 6, topY - 59, 3, 56), p);
        p.color = const Color(0xFFFDE047); // Chaser chevrons down the tower fin
        for (double fy = topY - 52; fy < topY - 8; fy += 9) {
          canvas.drawRect(Rect.fromLTWH(cx - 3, fy, 6, 5), p);
        }
        // Glowing neon sunburst crest at top of Tower fin
        p.color = const Color(0xFFF83870);
        canvas.drawRect(Rect.fromLTWH(cx - 8, topY - 72, 16, 10), p);
        p.color = const Color(0xFFFDE047);
        canvas.drawRect(Rect.fromLTWH(cx - 4, topY - 70, 8, 6), p);

        // Cantilevered Trapezoidal Street Marquee & Glass Ticket Booth
        final double mqY = groundScreenY - 42.0;
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(bx + 6, mqY, b.width - 12, 18), p);
        p.color = const Color(0xFFFDE68A); // Illuminated white/gold letter board
        canvas.drawRect(Rect.fromLTWH(bx + 10, mqY + 3, b.width - 20, 12), p);
        p.color = const Color(0xFFF83870); // Neon pink marquee trim
        canvas.drawRect(Rect.fromLTWH(bx + 8, mqY + 1, b.width - 16, 2), p);
        canvas.drawRect(Rect.fromLTWH(bx + 8, mqY + 15, b.width - 16, 2), p);
        // Box-office ticket booth below marquee
        p.color = const Color(0xFFF59E0B);
        canvas.drawRect(Rect.fromLTWH(cx - 8, groundScreenY - 24, 16, 24), p);
        p.color = const Color(0xFFBAE6FD);
        canvas.drawRect(Rect.fromLTWH(cx - 5, groundScreenY - 21, 10, 11), p);
      } else if (archStyle == 4) {
        // --- STYLE 4: CLASSEN TRIANGLE MILK BOTTLE BUILDING & ROUTE 66 GIANT SODA BOTTLE ---
        // OKC's famous giant rooftop Braum's/Townley's Milk Bottle + Pops 66 LED Soda Bottle!
        final double mbX = bx + b.width * 0.32;
        // Stepped brick roof pediment
        p.color = const Color(0xFFFDE68A);
        canvas.drawRect(Rect.fromLTWH(mbX - 16, topY - 12, 32, 10), p);
        // Giant 3D Rooftop White & Cream Milk Bottle
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(mbX - 11, topY - 46, 22, 34), p);
        canvas.drawRect(Rect.fromLTWH(mbX - 7, topY - 62, 14, 18), p);
        canvas.drawRect(Rect.fromLTWH(mbX - 9, topY - 66, 18, 5), p);
        p.color = const Color(0xFFF8FAFC); // Crisp white milk bottle body
        canvas.drawRect(Rect.fromLTWH(mbX - 8, topY - 44, 16, 30), p);
        p.color = const Color(0xFFFEF3C7); // Rich cream top & neck
        canvas.drawRect(Rect.fromLTWH(mbX - 5, topY - 60, 10, 16), p);
        canvas.drawRect(Rect.fromLTWH(mbX - 7, topY - 64, 14, 3), p);
        // Red vintage band around the bottle belly
        p.color = const Color(0xFFEF4444);
        canvas.drawRect(Rect.fromLTWH(mbX - 8, topY - 32, 16, 6), p);

        // Glowing Pops 66 LED Neon Soda Bottle on the right side of the roof
        final double sbX = bx + b.width * 0.74;
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(sbX - 8, topY - 42, 16, 40), p);
        canvas.drawRect(Rect.fromLTWH(sbX - 4, topY - 58, 8, 16), p);
        final List<Color> ledCols = const [
          Color(0xFFF83870),
          Color(0xFF3CBCFC),
          Color(0xFF58F898),
          Color(0xFFF8B800),
          Color(0xFFB878F8),
        ];
        for (int s = 0; s < 5; s++) {
          p.color = ledCols[(s + (worldTime * 3).floor()) % ledCols.length];
          canvas.drawRect(Rect.fromLTWH(sbX - 6, topY - 10 - s * 6.0, 12, 5), p);
        }
      } else {
        // --- STYLE 5: MIDTOWN ART DECO ZIGGURAT & OKC ROCK HALL ---
        // Stepped Art Deco ziggurat crown + winged electric guitar neon facade crest!
        final double cx = bx + b.width * 0.5;
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(cx - 28, topY - 16, 56, 14), p);
        canvas.drawRect(Rect.fromLTWH(cx - 16, topY - 28, 32, 12), p);
        p.color = b.trimColor;
        canvas.drawRect(Rect.fromLTWH(cx - 25, topY - 14, 50, 11), p);
        canvas.drawRect(Rect.fromLTWH(cx - 13, topY - 25, 26, 11), p);
        p.color = b.neonColor;
        canvas.drawRect(Rect.fromLTWH(cx - 8, topY - 21, 16, 4), p);

        // Ground-floor striped storefront awning & warm lit shopfront
        final double sfY = groundScreenY - 34.0;
        p.color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(bx + 8, sfY, b.width - 16, 34), p);
        p.color = const Color(0xFF1E293B);
        canvas.drawRect(Rect.fromLTWH(bx + 11, sfY + 10, b.width - 22, 24), p);
        p.color = const Color(0xFFFDE68A);
        canvas.drawRect(Rect.fromLTWH(bx + 15, sfY + 14, b.width - 30, 14), p);
        // Striped purple/gold awning
        for (double ax = bx + 8; ax < bx + b.width - 12; ax += 8) {
          p.color = ((ax ~/ 8).isEven) ? b.neonColor : const Color(0xFFF8FAFC);
          canvas.drawRect(Rect.fromLTWH(ax, sfY, 8, 9), p);
        }
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

  // --- High-Detail Pixel-Art Sprite for Duchess (Tortoiseshell Cat, Start of Level) ---
  // Matches the main character's px=1.05 high-density pixel art style:
  // 1px black outline ('K'), multi-tone mottled tortoiseshell coat (dark espresso 'b',
  // burnt sienna 'o', ginger orange 'O', amber gold 'A', soft cream 'C'),
  // pink inner ears & nose ('P'), and emerald green eyes ('G'/'g') with white catchlights ('W')!
  static const Map<String, Color> duchessCatPalette = {
    'K': Color(0xFF020103), // Crisp 1px black outline & obsidian tortie fur
    'b': Color(0xFF2A1810), // Dark espresso tortie fur shadow
    'o': Color(0xFFB45309), // Shaded burnt sienna fur
    'O': Color(0xFFEA580C), // Fiery ginger orange tortie patch
    'A': Color(0xFFF59E0B), // Golden amber tortie blaze
    'C': Color(0xFFFDE68A), // Soft cream chin/paw/chest patch
    'P': Color(0xFFF472B6), // Pink inner ear & nose
    'G': Color(0xFF58F898), // Bright emerald cat iris
    'g': Color(0xFF15803D), // Shaded green iris contour
    'W': Color(0xFFEEEDEC), // Crisp white eye catchlight & whiskers
  };

  static const List<String> duchessCatMatrix = [
    '........KK..........KK......', // 00: Pointed cat ear tips
    '.......KbbK........KAAK.....', // 01: Upper ears (left dark, right amber)
    '......KbPPbK......KAPPK.....', // 02: Pink inner ears
    '.....KbbPPbbKKKKKKoAPPAk....', // 03: Ear bases + crown
    '.....KbOObbbKbbbbOOAAAAK....', // 04: Forehead with ginger/amber blaze
    '....KbbOOObbKbbbOOAAOObbK...', // 05: Upper head mottled tortie pattern
    '....KbOOOObbACAAOOAAOObbK...', // 06: Split tortie nose blaze (amber/cream)
    '....KbOWGKbbACAAbbKWGKbbK...', // 07: Emerald eyes with white catchlights!
    '....KbOgGKbbACCAbbKgGKbbK...', // 08: Lower emerald eyes + black pupils
    '....KbbOObbbACCCbbbOObbbK...', // 09: Cheeks
    '.....KbbObbCCPPPCCbbObbK....', // 10: Muzzle + pink cat nose ('PPP')
    '....WWKbbbbCCCKCCCbbbbKWW...', // 11: Whiskers ('WW') + mouth
    '......KKbbbbCCCCCbbbbKK.....', // 12: Cream chin tuft
    '.......KKKbbbbCbbbbKKK......', // 13: Neckline
    '......KbbbOOOCCCAAObbbK.....', // 14: Upper chest ruff
    '.....KbOOOObbCCCCAAOObbK....', // 15: Chest + cream bib
    '....KbbOOObbbCCCCAAAOObbK...', // 16: Seated shoulders
    '...KbbOObbbbbCCCCAAOOObbK.KK', // 17: Back + tail tip starting on right
    '...KbOObbbbbbCCCbAAOOObbKKAK', // 18: Tortie back + curled tail tip
    '..KbbObbbbbbbKbbKAAOOOObbKAK', // 19: Seated body + raised tail
    '..KbbObbbbbbKbCCKAAOOOObbKOK', // 20: Begging/seated front chest + tail
    '..KbbbbOObbbKbCCKbbOOObbbKOK', // 21: Mottled tortie flank + tail
    '..KbbbbOOObbKKKKKbbOObbbbKbK', // 22: Lower flank + tail curve
    '..KbbAAOOObbKbbbbbAAObbbbKbK', // 23: Haunches + tail
    '..KbbAAOOObbKbbbbbAAAbbbKbbK', // 24: Hind leg contour + tail base
    '...KbbAAOObbKbbbbbAAAbbKKbK.', // 25: Lower haunches
    '...KbbbOOObbKbbKbboAAbbKbbK.', // 26: Front legs & hind paws
    '....KbbbOObbKbbKbbKAAbbKbK..', // 27: Ankle shading
    '....KbbbbbbbKbbKbbKbbbbKK...', // 28: Lower legs
    '....KCCCbbbbKCCKCCKCCCbK....', // 29: Cream & amber tortie paws
    '....KCCCbKKK.KKKKK.KCCCK....', // 30: Paw toes
    '....KKKKK..........KKKKK....', // 31: Crisp 1px black paw base outline
  ];

  void _drawTortieCat(Canvas canvas, double sx, double groundY) {
    final double bob = ((worldTime * 4.5).floor() % 2) * 1.5;
    const double px = 1.05; // Matches archBTW character pixel density!
    final double w = 28 * px;
    final double h = 32 * px;

    _drawPixelMatrix(
      canvas,
      duchessCatMatrix,
      duchessCatPalette,
      pixelSize: px,
      origin: Offset(sx - w / 2, groundY - h - bob),
    );

    _drawNesBannerLabel(
      canvas,
      'DUCHESS: "MEOW! FEED ME!"',
      Offset(sx + 8, groundY - h - 14),
      const Color(0xFFF8B800),
      fontSize: 10,
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

  // --- High-Detail Pixel-Art Sprite for Goose (White Pitbull/Corgi Mix — Mount) ---
  // Matches the main character's px=1.05 high-density pixel art style:
  // Multi-tone white coat ('W' snow highlight, 'w' alabaster, 's' cool slate shade, 'g' shadow),
  // biscuit-tan corgi ears & saddle patch ('T' light tan, 't' warm biscuit, 'd' brown-tan shade),
  // pink inner ears & happy tongue ('R'/'r'), purple studded collar ('P'/'C') with gold tag ('Y'),
  // blocky pitbull head with expressive eye catchlight, and sturdy short corgi legs!
  static const List<String> gooseDogMatrix = [
    '...........................KKKK.......KKKK......', // 00: Pointed corgi/pitbull ear tips
    '..........................KTTttK.....KWWWWK.....', // 01: Left biscuit-tan ear, right white ear
    '.........................KTtRRttK...KWWRRWWK....', // 02: Pink inner ears
    '.........................KTtRRRttKKKWWRRRWWK....', // 03: Ear bases
    '........................KTTttRRRttKWWRRRWWWWK...', // 04: Crown of blocky pitbull head
    '.......................KTTTtttKKKKWWWWWWWWWWK...', // 05: Forehead with biscuit ear patch
    '......................KTTttWWWwwwwWWWWWWWWWWWK..', // 06: Broad pitbull brow
    '....KKKK..............KTtWWWWwwwwwwWWWWWWWWWWK..', // 07: Tail tip (left) + upper head
    '...KWWWWK.............KWWWWwwwwwwwwwKWKWWWWWWK..', // 08: Fluffy tail + eye brow
    '..KWWwwwwK............KWWWWwwwwwwwwKWWKWWWWWWK..', // 09: Expressive dog eye with white catchlight
    '..KWwwwwsK............KWWWwwwwwwwwwwKKKWWWWWWKK.', // 10: Lower eye + snout bridge
    '..KWwwwssK............KCPWWWWwwwwwwwwWWWWWWWWNNK', // 11: Collar top + blocky snout + dark nose ('NN')
    '...KWwssgKKKKKKKKKKKKKKCPWWWWwwwwwwwwWWWWWWWWNNK', // 12: Long corgi back + pitbull muzzle
    '...KWWwwwwWWWWWWWWttTTTtCPWWWWwwwwwwwwWWWWWWWWK.', // 13: Back + tan saddle + purple studded collar
    '....KWWWWWWWWWWWttttTTTTtCPYWWWWwwwwwwwwKKKKKK..', // 14: Biscuit-tan corgi saddle + gold collar tag ('Y')
    '....KWWWWWWWWWWttttTTTTTTtCPWWWWWwwwwwwKRRRRK...', // 15: Saddle + happy open mouth & pink tongue ('RRRR')
    '....KWWWWwwwwwwttttTTTTTTttCWWWWWWwwwwwKRRrK....', // 16: Mid torso + pink tongue tip
    '....KWWWwwwwwwwtttttTTTTTttWWWWWWWWwwwwKKKK.....', // 17: Ribcage + strong pitbull jaw
    '....KWWWwwwwwwwwttttTTTTttWWWWWWWWWWwwwK........', // 18: Muscular chest
    '.....KWWWwwwwwwwwddddddddwwwwWWWWWWWWwwK........', // 19: Shaded under-saddle & chest
    '.....KWWWwwwwwwwwwwwwwwwwwwwwWWWWWWWWWwK........', // 20: Lower torso
    '......KsssswwwwwwwwwwwwwwwwwwwwWWWWsssK.........', // 21: Shaded belly contour
    '......KggggssssssssssssssssssssssggggK..........', // 22: Underbelly shadow
    '.......KKKKWWwwKKKKggggggggKKKKWWwwKKK..........', // 23: Upper short corgi legs
    '.......KssKWWwwKssK........KssKWWwwKssK.........', // 24: Front & back leg pairs
    '.......KssKWWwwKssK........KssKWWwwKssK.........', // 25: Short sturdy corgi legs
    '.......KggKWWWWKggK........KggKWWWWKggK.........', // 26: Ankle shading
    '.......KWWKWWWWKWWK........KWWKWWWWKWWK.........', // 27: White paws
    '.......KWWKWWWWKWWK........KWWKWWWWKWWK.........', // 28: Paw toes
    '.......KKKKKKKKKKKK........KKKKKKKKKKKK.........', // 29: Crisp 1px black paw outline
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
    const double px = 1.05; // Matches archBTW character pixel density!
    final double w = 48 * px;
    final double h = 30 * px;
    final double stepBob = ((cycle * 2.0).floor() % 2) * 1.5;

    canvas.save();
    canvas.translate(sx, sy - stepBob);
    if (!right) {
      canvas.scale(-1.0, 1.0);
    }

    _drawPixelMatrix(
      canvas,
      gooseDogMatrix,
      {
        'K': const Color(0xFF020103), // Crisp 1px black outline
        'W': const Color(0xFFFFFFFF), // Pure snow white coat highlight
        'w': const Color(0xFFF1F5F9), // Soft alabaster white coat
        's': const Color(0xFFCBD5E1), // Cool slate muscle/belly shading
        'g': const Color(0xFF94A3B8), // Deeper shadow under belly/back legs
        'T': const Color(0xFFE5C07B), // Light biscuit/tan corgi ear & saddle highlight
        't': const Color(0xFFC08B3E), // Warm mid-biscuit corgi saddle
        'd': const Color(0xFF8C5E24), // Shaded tan saddle contour
        'C': const Color(0xFFD8B4FE), // Lavender collar studs
        'P': const Color(0xFF7E22CE), // Royal purple collar strap
        'Y': const Color(0xFFF8B800), // Gleaming gold "GOOSE" collar tag
        'N': const Color(0xFF0F172A), // Dark nose
        'R': chomping
            ? const Color(0xFFF8B800)
            : const Color(0xFFFB7185), // Pink inner ear / tongue / chomp spark
        'r': const Color(0xFFE11D48), // Shaded tongue contour
      },
      pixelSize: px,
      origin: Offset(-w / 2, -h),
    );

    canvas.restore();

    if (showRidePrompt) {
      _drawNesBannerLabel(
        canvas,
        '▼ GOOSE [RIDE] ▼',
        Offset(sx, sy - h - 14),
        const Color(0xFFF8B800),
        fontSize: 10,
      );
    }
  }

  // --- Identical 28x80 Pixel-Art Sprite for archBTW (Extracted 1:1 from Reference!) ---
  // Exact 28x80 pixel grid & palette: tousled black hair, peach/tan shaded face & beard,
  // purple & black buffalo plaid flannel with rolled sleeves & lavender buttons,
  // charcoal band tee with white/silver skull-cross emblem, teal-blue/navy shaded jeans,
  // and black & white sneakers with white laces, toe caps, and soles!
  static const Map<String, Color> archBtwCharacterPalette = {
    'K': Color(0xFF020103), // Crisp black outline, hair, beard & plaid black
    'S': Color(0xFFF2BBA7), // Light peach skin highlight
    's': Color(0xFFDF8870), // Mid warm skin tone
    'c': Color(0xFFBC644C), // Shaded skin contour (nose/brow/ear/fingers)
    'e': Color(0xFF6B3C28), // Deep eye/brow crease
    'W': Color(0xFFEEEDEC), // Crisp white (eye sclera, tee emblem, shoe toe/sole)
    'L': Color(0xFFB8B5BD), // Cool silver-gray (tee emblem shading, shoe laces/trim)
    'T': Color(0xFF444444), // Charcoal grey inner shirt
    'P': Color(0xFF8B3DD6), // Bright amethyst-lavender purple plaid
    'p': Color(0xFF5E117C), // Medium royal purple plaid
    'd': Color(0xFF33134F), // Deep dark violet plaid shadow
    'j': Color(0xFF093F65), // Teal-blue denim jeans
    'n': Color(0xFF15154D), // Dark navy denim shadow
  };

  // Rows 00..57: Head, hair, beard, open purple/black plaid flannel, charcoal tee, and arms/hands
  static const List<String> archBtwUpperBodyMatrix = [
    '................KKKK........', // 00
    '.............KKKKKKKKKKK....', // 01
    '........KK.KKKKKKKKKKKK.K...', // 02
    '.........KKKKKKKKKKKKKKK....', // 03
    '.......KKKKKKKKKKKKKKKKKKKK.', // 04
    '........KKKKKKKKKKKKKKKKKK..', // 05
    '.......KKKKKKKKKKKKKKKKKKK..', // 06
    '.......KKKKKKKKKKKKKKscKKKK.', // 07
    '.......KKKKKKKKKKKKKsSssKKK.', // 08
    '......KKKKKKKKKKKsKsSSSsKKKK', // 09
    '......KKKKKKKKKKsKSSSSSSKKKK', // 10
    '......KKKKKKKKKsSSSSSSSSKK.K', // 11
    '......KKKKKKKKsKKKKSSSKKKK..', // 12
    '.......KKKKKKsKsKKesSKKsK.K.', // 13
    '.......KKSKKKSSKWKKSSKWKK...', // 14
    '.......KKSSKKSSSSssSSKssK...', // 15
    '.......KKsKsKSSSSSSSScSSK...', // 16
    '........KKKKKsSSSSSSSScSK...', // 17
    '........KKKKKKsSSSSsKKssK...', // 18
    '.........KKKKKKsSKKKKKKsK...', // 19
    '...........KKKKKKKSSSSKKK...', // 20
    '..........KKKKKKKKsKKsKKK...', // 21
    '........KKpKKsKKKKKKKKKK....', // 22
    '.......KKPpKKSsKKKKKKKK.....', // 23
    '......KKKPppKsSsKKKKKK......', // 24
    '....KKPPdKppPKSSSsKKPKK.....', // 25
    '...KKpPPpKPPPdKSSssKPPKK....', // 26
    '...KpKKpKKKPKKKKSSKKKpKKK...', // 27
    '..KKKKdpKKKKKKKTKKTKKKKpK...', // 28
    '..KPdPpPPpPppPKTTTTKppdPd...', // 29
    '..KPpPPdKKppKpKTTTTKpKKKKK..', // 30
    '.KpKKppdKKppKpKWTTLKpKKKKK..', // 31
    '.KpKKppKKpPPpPKTWTTKPpKdPK..', // 32
    '.KPppPpdKdppdPKWWLWKPdKdpK..', // 33
    '.KpKKppKKKppKpKLTWLKpKKKKK..', // 34
    '.KpKKpKKddPPdpKLWWWKPdKKdK..', // 35
    '.KPpPPKKdpPPpLKWLLLKPpKdPK..', // 36
    '.KKKPPpKKKppKpKWTTWKpKKdKK..', // 37
    'KKKKKKKKKKppKpKLTTWKpKKdKKK.', // 38
    'KdpPPKKKdpPPppKTTLTKPpKKKPK.', // 39
    'KppPPPpKdpPPpPKTTTTKPpKdPpK.', // 40
    'KPpKKPpKKKppKpKTTTTKpKKdPpK.', // 41
    'KdKKKKKKKKppKpKTTTTKpKKKKK..', // 42
    '.KssScKpdpPPpPKTTTTKPpKccK..', // 43
    '.KSSSsKdKKppKTKTTTTKpKKsSK..', // 44
    '.KSSSsKdKKppKpKTTTTKdKKsSKK.', // 45
    '.KSSScKdppPPppKTTTTTKpKcSKK.', // 46
    '.KSSScKdppPPpdKTTTTTKpKcSKK.', // 47
    '..KSSsKdKKppdKTTTTTTKpKKSK..', // 48
    '..KsSSKdKKppdKTTTTTTKpKKSK..', // 49
    '..KcSSKKdpPPdKKKKKKKKPpKSK..', // 50
    '..KcSSSKKKppKKnnnnnnKpKKSSK.', // 51
    '..KsSSSSKKddKnjjjnjjKdKSSSK.', // 52
    '..KSSSSSsKKKKjjjnKjjnKKScSK.', // 53
    '..KSSSSKSKnnnjjjKKnjjnKScSK.', // 54
    '..KSSSSKsKjjjjjnKnjjjjKccsK.', // 55
    '..KcscSKKKjjjjnKnnjjjjKcSK..', // 56
    '....KcccKjjjjjnKnjjjjjKKK...', // 57
  ];

  // Rows 00..57 when punching (40 cols wide):
  // - Regular hanging arms (cols 0..7 and 22..27 in rows 36..57) lift up off his sides
  // - Rolled purple/black buffalo plaid sleeve (cols 21..27), shaded bare forearm (cols 28..34),
  //   and clenched human fist with knuckles & thumb (cols 35..39) extend straight forward at shoulder level!
  static const List<String> archBtwPunchingUpperBodyMatrix = [
    '................KKKK....................', // 00
    '.............KKKKKKKKKKK................', // 01
    '........KK.KKKKKKKKKKKK.K...............', // 02
    '.........KKKKKKKKKKKKKKK................', // 03
    '.......KKKKKKKKKKKKKKKKKKKK.............', // 04
    '........KKKKKKKKKKKKKKKKKK..............', // 05
    '.......KKKKKKKKKKKKKKKKKKK..............', // 06
    '.......KKKKKKKKKKKKKKscKKKK.............', // 07
    '.......KKKKKKKKKKKKKsSssKKK.............', // 08
    '......KKKKKKKKKKKsKsSSSsKKKK............', // 09
    '......KKKKKKKKKKsKSSSSSSKKKK............', // 10
    '......KKKKKKKKKsSSSSSSSSKK.K............', // 11
    '......KKKKKKKKsKKKKSSSKKKK..............', // 12
    '.......KKKKKKsKsKKesSKKsK.K.............', // 13
    '.......KKSKKKSSKWKKSSKWKK...............', // 14
    '.......KKSSKKSSSSssSSKssK...............', // 15
    '.......KKsKsKSSSSSSSScSSK...............', // 16
    '........KKKKKsSSSSSSSScSK...............', // 17
    '........KKKKKKsSSSSsKKssK...............', // 18
    '.........KKKKKKsSKKKKKKsK...............', // 19
    '...........KKKKKKKSSSSKKK...............', // 20
    '..........KKKKKKKKsKKsKKK...............', // 21
    '........KKpKKsKKKKKKKKKK................', // 22
    '.......KKPpKKSsKKKKKKKK.................', // 23
    '......KKKPppKsSsKKKKKK..................', // 24
    '....KKPPdKppPKSSSsKKPKK.................', // 25
    '...KKpPPpKPPPdKSSssKPPKK................', // 26
    '...KpKKpKKKPKKKKSSKKKpKKK...............', // 27
    '......KKKKKKsKKTKKTKKKKpKKK.............', // 28
    '.....KKpPPpPppPKTTTTKppdPPpKKKKKKKKKKK...', // 29
    '.....KdpPPppKpKTTTTKpKPpPPdKSSSSSSSSsK..', // 30
    '......KKppdpKpKWTTLKpKppPPpKSSSSSSSSsSK.', // 31
    '......KdpPPppPKTWTTKPpKKppdKsssssssScsK.', // 32
    '......KKdppdPKWWLWKPdKdpPPKssssssscsSK.', // 33
    '.......KKKppKpKLTWLKpKKKppdKccccccccsK..', // 34
    '.......KddPPdpKLWWWKPdKKKKKKKKKKKKKKK...', // 35
    '.......KdpPPpLKWLLLKPpKdPK..............', // 36
    '.......KKKppKpKWTTWKpKKdKK..............', // 37
    '.......KKKppKpKLTTWKpKKdKK..............', // 38
    '.......KdpPPppKTTLTKPpKKPK..............', // 39
    '.......KdpPPpPKTTTTKPpKdPK..............', // 40
    '.......KKKppKpKTTTTKpKKdPK..............', // 41
    '.......KKKppKpKTTTTKpKKKK...............', // 42
    '.......KdpPPpPKTTTTKPpK.................', // 43
    '.......KKKppKTKTTTTKpKK.................', // 44
    '.......KKKppKpKTTTTKdKK.................', // 45
    '.......KdpPPppKTTTTTKpK.................', // 46
    '.......KdpPPpdKTTTTTKpK.................', // 47
    '.......KKKppdKTTTTTTKpK.................', // 48
    '.......KKKppdKTTTTTTKpK.................', // 49
    '.......KdpPPdKKKKKKKKPpK................', // 50
    '.......KKKppKKnnnnnnKpKK................', // 51
    '........KKddKnjjjnjjKdK.................', // 52
    '........KKKKKjjjnKjjnKK.................', // 53
    '.........KnnnjjjKKnjjnK.................', // 54
    '.........KjjjjjnKnjjjjK.................', // 55
    '.........KjjjjnKnnjjjjK.................', // 56
    '.........KjjjjjnKnjjjjjK................', // 57
  ];

  // Rows 58..79 split into Left Leg (cols 0..14) and Right Leg (cols 15..27)
  // so standing idle is 100% pixel-identical to the reference and walking animates smoothly!
  static const List<String> archBtwLeftLegMatrix = [
    '.....KKKKjjjjjK.............', // 58
    '......KnnjjjjnK.............', // 59
    '......KnnjjjjnK.............', // 60
    '......KnnjjjjK..............', // 61
    '......KnnjjjjK..............', // 62
    '......KnnjjjjK..............', // 63
    '......KnnjjjnK..............', // 64
    '......KnjjjnK...............', // 65
    '.....KnnjnnnK...............', // 66
    '.....KnjjjjnK...............', // 67
    '.....KnnjjjnK...............', // 68
    '.....KnnjjjK................', // 69
    '.....KnjjjjK................', // 70
    '.....KnjjjnK................', // 71
    '....KjnnnnjK................', // 72
    '....KnnjjjjK................', // 73
    '....KnjKKKKK................', // 74
    '....KKKKLWLK................', // 75
    '....KKKLKKKKK...............', // 76
    '....KKKKWWWWKK..............', // 77
    '....KLLWWWWWWK..............', // 78
    '.....KKKKKKKKK..............', // 79
  ];

  static const List<String> archBtwRightLegMatrix = [
    '...............KnjjjjjK.....', // 58
    '...............KnjjjjjK.....', // 59
    '...............KnjjjjjK.....', // 60
    '...............KnjjjjjK.....', // 61
    '...............KnnjjjjK.....', // 62
    '...............KnnjjjjK.....', // 63
    '...............KnnjjjK......', // 64
    '...............KnjnjjK......', // 65
    '...............KnjjnnK......', // 66
    '...............KnjjjjK......', // 67
    '...............KnjjjjK......', // 68
    '...............KnjjjjK......', // 69
    '...............KnjjjnK......', // 70
    '...............KnnnnjK......', // 71
    '...............KnnjjjK......', // 72
    '...............KnjjKKK......', // 73
    '...............KKKKKWLK.....', // 74
    '...............KKLKKKLWKK...', // 75
    '...............KKKKKKKKWWK..', // 76
    '...............KLLLLWWWWWK..', // 77
    '...............KKKKKKKKKKK..', // 78
    '............................', // 79
  ];

  // Extended kicking right leg & black-and-white sneaker (25x7 pixel matrix)
  // Uses the exact pixel-for-pixel sneaker from rows 74..78 of archBtwRightLegMatrix
  // at the end of the extended horizontal jeans leg!
  static const List<String> archBtwKickingRightLegMatrix = [
    '............KKKKKWLK.....', // 00: Sneaker ankle collar + tongue + top lace
    '..KKKKKKKKKKKKLKKKLWKK...', // 01: Top of extended jeans leg + black sneaker upper + white laces
    '.KnnnnnnnnnnnnKKKKKKWWK..', // 02: Navy top shadow of jeans + black canvas upper + white rubber toe-cap
    'KnjjjjjjjjjjjjnKLLLLWWWWK', // 03: Teal-blue denim jeans + silver-white midsole + white rubber toe-cap
    'KnjjjjjjjjjjjjnKKKKKKKKKK', // 04: Jeans + black rubber outsole
    '.KnnnnnnnnnnnnK..........', // 05: Bottom shadow of extended jeans leg
    '..KKKKKKKKKKKK...........', // 06: Bottom black outline of extended jeans leg
  ];

  // Renders a high-detail Purple PRS Custom 24 Electric Guitar:
  // - Sculpted hourglass body with wide lower bout, pinched waist, deep cutaways,
  //   long pointed PRS upper horn, and shorter scooped lower horn
  // - Natural maple cream binding, deep violet burst edge, royal purple body,
  //   and bright lavender chevron flame-maple tiger stripes
  // - Dual humbucker pickups (cream rings, black bobbins, 12 silver pole pieces),
  //   chrome PRS tremolo bridge, and gold volume/tone knobs
  // - Long slender rosewood fretboard with silver frets, white PRS bird inlays,
  //   6 silver strings, and pointed 3x3 PRS winged headstock with 6 silver tuners!
  static void drawPurplePrsGuitar(
    Canvas canvas,
    Offset center, {
    required double scale,
    double angle = -0.30,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale, scale);

    // Local coordinates (in virtual guitar units, centered near the bridge/pickups):
    // Body spans x: -20..+8, y: -13..+13
    // Neck spans x: +4..+32, y: -2.3..+2.3
    // Headstock spans x: +32..+43, y: -4.2..+4.2

    // 1. Iconic PRS Custom 24 Double-Cutaway Body Silhouette Path
    Path buildBodyPath(double inflate) {
      final double d = inflate;
      final Path path = Path();
      // Start at rear strap button (leftmost center of lower bout)
      path.moveTo(-21.0 - d, 0.0);
      // Upper-left lower bout curve (wide, rounded)
      path.cubicTo(
        -21.0 - d,
        -9.5 - d,
        -13.5 - d * 0.5,
        -13.5 - d,
        -7.5,
        -12.0 - d,
      );
      // Pinched waist (top edge curves inward around x = -3)
      path.cubicTo(
        -4.5,
        -11.0 - d * 0.6,
        -3.5,
        -7.8 - d * 0.5,
        -0.5,
        -8.2 - d * 0.6,
      );
      // Sweeping long PRS upper horn (extends forward to x = +9.5, y = -11.5)
      path.cubicTo(
        2.5,
        -9.0 - d,
        6.8,
        -12.2 - d,
        9.6 + d,
        -10.6 - d * 0.5,
      );
      // Inner scoop of upper cutaway down to neck joint (x = +3.5, y = -2.4)
      path.cubicTo(
        10.2 + d,
        -8.6,
        5.5 + d * 0.4,
        -5.8 + d * 0.4,
        3.5,
        -5.8 + d * 0.4,
      );
      path.cubicTo(
        1.5,
        -5.8 + d * 0.4,
        1.5,
        -2.4,
        4.5,
        -2.2,
      );
      // Across neck pocket to lower cutaway
      path.lineTo(4.5, 2.2);
      // Inner scoop of lower cutaway out to shorter PRS lower horn (x = +7.8, y = +9.8)
      path.cubicTo(
        1.2,
        2.5,
        0.8,
        6.2 - d * 0.4,
        3.2,
        6.8 - d * 0.4,
      );
      path.cubicTo(
        5.4,
        7.3 - d * 0.4,
        8.2 + d,
        7.2,
        7.8 + d,
        9.5 + d * 0.5,
      );
      // Outer curve of lower horn into pinched lower waist (x = -3, y = +7.8)
      path.cubicTo(
        6.8,
        11.4 + d,
        2.2,
        9.8 + d,
        -0.5,
        8.2 + d * 0.6,
      );
      path.cubicTo(
        -3.5,
        7.5 + d * 0.5,
        -4.5,
        11.2 + d * 0.6,
        -7.5,
        12.2 + d,
      );
      // Lower-left lower bout curve back to rear strap button
      path.cubicTo(
        -13.5 - d * 0.5,
        13.8 + d,
        -21.0 - d,
        9.5 + d,
        -21.0 - d,
        0.0,
      );
      path.close();
      return path;
    }

    final Path outerBlackBody = buildBodyPath(1.8);
    final Path mapleBindingBody = buildBodyPath(0.6);
    final Path purpleBurstBody = buildBodyPath(-0.4);
    final Path carvedTopBody = buildBodyPath(-2.2);

    // Draw Black Outer Outline
    canvas.drawPath(
      outerBlackBody,
      Paint()
        ..color = const Color(0xFF05020A)
        ..style = PaintingStyle.fill,
    );
    // Draw Cream / Natural Maple Scrape Binding Edge
    canvas.drawPath(
      mapleBindingBody,
      Paint()
        ..color = const Color(0xFFFDE68A)
        ..style = PaintingStyle.fill,
    );
    // Draw Deep Violet Charcoal Burst Outer Body
    canvas.drawPath(
      purpleBurstBody,
      Paint()
        ..color = const Color(0xFF3B0764)
        ..style = PaintingStyle.fill,
    );
    // Draw Royal Amethyst Carved Maple Top
    canvas.drawPath(
      carvedTopBody,
      Paint()
        ..color = const Color(0xFF7E22CE)
        ..style = PaintingStyle.fill,
    );

    // Clip to carved top to draw chevron flame maple stripes & center glow
    canvas.save();
    canvas.clipPath(carvedTopBody);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-8.0, 0.0), width: 20.0, height: 15.0),
      Paint()..color = const Color(0xFF9333EA),
    );
    final Paint flamePaint = Paint()
      ..color = const Color(0xFFD8B4FE).withValues(alpha: 0.65)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;
    for (double fx = -18.0; fx <= 6.0; fx += 2.8) {
      final Path chevron = Path()
        ..moveTo(fx - 2.2, -13.0)
        ..lineTo(fx + 1.4, 0.0)
        ..lineTo(fx - 2.2, 13.0);
      canvas.drawPath(chevron, flamePaint);
    }
    canvas.restore();

    // 2. Long Slender Rosewood Neck & Fretboard (x: +2.0..+32.0, y: -2.2..+2.2)
    final RRect neckOutline = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1.5, -3.1, 31.5, 6.2),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(neckOutline, Paint()..color = const Color(0xFF05020A));
    canvas.drawRect(
      const Rect.fromLTWH(2.0, -2.1, 30.5, 4.2),
      Paint()..color = const Color(0xFF3E2723), // Rosewood fretboard
    );

    // Silver frets & White Mother-of-Pearl PRS Bird Inlays along the neck
    final Paint fretPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 0.6;
    final Paint birdPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (double nx = 5.5; nx <= 29.5; nx += 3.4) {
      canvas.drawLine(Offset(nx, -2.0), Offset(nx, 2.0), fretPaint);
      // Tiny winged bird inlay between frets
      final Path bird = Path()
        ..moveTo(nx - 1.7, 0.0)
        ..lineTo(nx - 1.1, -1.2)
        ..lineTo(nx - 0.6, -0.2)
        ..lineTo(nx - 1.1, 1.2)
        ..close();
      canvas.drawPath(bird, birdPaint);
    }

    // White Bone Nut at x = 32.0
    canvas.drawRect(
      const Rect.fromLTWH(31.8, -2.2, 1.0, 4.4),
      Paint()..color = const Color(0xFFF8FAFC),
    );

    // 3. Signature Pointed 3x3 PRS Winged Headstock (x: 32.5..43.5)
    final Path headstockPath = Path()
      ..moveTo(32.2, -2.2)
      ..lineTo(35.0, -4.2) // Treble/bass wing flare
      ..lineTo(42.8, -2.8) // Pointed upper tip
      ..lineTo(40.8, 0.0) // PRS V-notch carve at tip
      ..lineTo(43.5, 2.4) // Pointed lower tip
      ..lineTo(35.0, 4.2) // Lower wing flare
      ..lineTo(32.2, 2.2)
      ..close();

    // 6 Silver Tuning Pegs & Buttons (3 on top, 3 on bottom of headstock)
    final Paint tunerPaint = Paint()..color = const Color(0xFFCBD5E1);
    final Paint tunerOutline = Paint()..color = const Color(0xFF05020A);
    for (int t = 0; t < 3; t++) {
      final double tx = 35.2 + t * 2.4;
      // Top tuner
      canvas.drawRect(Rect.fromLTWH(tx - 1.0, -6.4, 2.2, 2.4), tunerOutline);
      canvas.drawRect(Rect.fromLTWH(tx - 0.6, -6.0, 1.4, 1.8), tunerPaint);
      // Bottom tuner
      canvas.drawRect(Rect.fromLTWH(tx - 1.0, 4.0, 2.2, 2.4), tunerOutline);
      canvas.drawRect(Rect.fromLTWH(tx - 0.6, 4.2, 1.4, 1.8), tunerPaint);
    }

    canvas.drawPath(
      headstockPath,
      Paint()
        ..color = const Color(0xFF05020A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawPath(
      headstockPath,
      Paint()
        ..color = const Color(0xFF6B21A8)
        ..style = PaintingStyle.fill,
    );
    // Gold PRS signature logo accent on headstock
    canvas.drawLine(
      const Offset(34.5, -0.8),
      const Offset(39.5, -1.4),
      Paint()
        ..color = const Color(0xFFFDE68A)
        ..strokeWidth = 0.9,
    );

    // 4. Dual Humbucker Pickups (Bridge @ x=-6.0, Neck @ x=-0.2)
    for (final double pxCenter in const [-6.2, -0.4]) {
      final Rect ringRect = Rect.fromCenter(
        center: Offset(pxCenter, 0.0),
        width: 4.4,
        height: 7.4,
      );
      // Cream pickup mounting ring
      canvas.drawRect(ringRect, Paint()..color = const Color(0xFFFDE68A));
      // Black dual-coil humbucker bobbins
      canvas.drawRect(
        ringRect.deflate(0.7),
        Paint()..color = const Color(0xFF0F172A),
      );
      // Silver pole pieces
      for (double py = -2.2; py <= 2.2; py += 1.4) {
        canvas.drawCircle(
          Offset(pxCenter - 0.7, py),
          0.45,
          Paint()..color = const Color(0xFFE2E8F0),
        );
        canvas.drawCircle(
          Offset(pxCenter + 0.7, py),
          0.45,
          Paint()..color = const Color(0xFFE2E8F0),
        );
      }
    }

    // 5. Chrome PRS Tremolo Bridge & Whammy Bar (x = -12.0)
    final Rect bridgeRect = Rect.fromCenter(
      center: const Offset(-12.0, 0.0),
      width: 3.6,
      height: 7.8,
    );
    canvas.drawRect(
      bridgeRect.inflate(0.6),
      Paint()..color = const Color(0xFF05020A),
    );
    canvas.drawRect(
      bridgeRect,
      Paint()..color = const Color(0xFFCBD5E1),
    );
    // Chrome tremolo arm (whammy bar)
    canvas.drawLine(
      const Offset(-11.5, 3.2),
      const Offset(-4.5, 6.2),
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 1.2,
    );

    // 6. Gold/Amber Speed Knobs (Volume & Tone) on lower bout
    for (final Offset knobPos in const [
      Offset(-9.5, 7.2),
      Offset(-13.8, 8.2),
    ]) {
      canvas.drawCircle(
        knobPos,
        1.7,
        Paint()..color = const Color(0xFF05020A),
      );
      canvas.drawCircle(
        knobPos,
        1.2,
        Paint()..color = const Color(0xFFF8B800),
      );
    }

    // 7. Silver Guitar Strings from Bridge to Headstock
    final Paint stringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..strokeWidth = 0.45;
    for (double sy = -1.5; sy <= 1.5; sy += 1.0) {
      canvas.drawLine(Offset(-11.5, sy), Offset(32.5, sy), stringPaint);
    }

    canvas.restore();
  }

  void _drawArchBtwPlayer(Canvas canvas, double sx, double sy) {
    const double px = 1.05; // Crisp 28x80 high-detail pixel scale (~84 world units tall)
    final double spriteW = 28 * px;
    final double upperH = 58 * px;
    final double legH = 22 * px;
    final double totalH = upperH + legH;

    final bool isMoving = walkCycle > 0 &&
        ((walkCycle * 3.0).floor() % 4 == 1 ||
            (walkCycle * 3.0).floor() % 4 == 3);
    final int walkFrame = (walkCycle * 2.2).floor() % 4;
    final bool isKicking =
        currentAttack == OkcAttackKind.kick && attackTimer > 0;
    final bool isPunching =
        currentAttack == OkcAttackKind.punch && attackTimer > 0;

    final double walkBob =
        (isGrounded && isMoving) ? -px * 1.2 : 0.0;

    canvas.save();
    canvas.translate(sx, sy);
    if (!facingRight) {
      canvas.scale(-1.0, 1.0);
    }

    final Paint p = Paint()..isAntiAlias = false;

    // 1. Draw Left & Right Legs (Rows 58..79 of the 28x80 character matrix)
    final double leftLegDx = !isGrounded
        ? -px * 2.0
        : (walkFrame == 1 ? -px * 2.5 : (walkFrame == 3 ? px * 2.5 : 0.0));
    final double leftLegDy = !isGrounded
        ? -px * 2.0
        : (walkFrame == 1 ? -px * 1.5 : 0.0);
    final double rightLegDx = !isGrounded
        ? px * 2.0
        : (walkFrame == 1 ? px * 2.5 : (walkFrame == 3 ? -px * 2.5 : 0.0));
    final double rightLegDy = !isGrounded
        ? -px * 1.0
        : (walkFrame == 3 ? -px * 1.5 : 0.0);

    _drawPixelMatrix(
      canvas,
      archBtwLeftLegMatrix,
      archBtwCharacterPalette,
      pixelSize: px,
      origin: Offset(-spriteW / 2 + leftLegDx, -legH + leftLegDy),
    );

    if (isKicking) {
      // Extended Roundhouse Kick using crisp pixel-art jeans + black/white sneaker matrix
      _drawPixelMatrix(
        canvas,
        archBtwKickingRightLegMatrix,
        archBtwCharacterPalette,
        pixelSize: px,
        origin: Offset(px * 1, -legH + px * 1),
      );
    } else {
      _drawPixelMatrix(
        canvas,
        archBtwRightLegMatrix,
        archBtwCharacterPalette,
        pixelSize: px,
        origin: Offset(-spriteW / 2 + rightLegDx, -legH + rightLegDy),
      );
    }

    // 2. Draw Upper Body (Rows 00..57: switches to raised-arm punching pose when punching!)
    _drawPixelMatrix(
      canvas,
      isPunching ? archBtwPunchingUpperBodyMatrix : archBtwUpperBodyMatrix,
      archBtwCharacterPalette,
      pixelSize: px,
      origin: Offset(-spriteW / 2, -totalH + walkBob),
    );

    // 4. Draw Equipped Detailed Purple PRS Custom 24 Electric Guitar ("Fireflower" mode!)
    if (hasGuitar) {
      final bool isStrumming =
          currentAttack == OkcAttackKind.chord && attackTimer > 0;
      final double gy = -totalH + px * 44 + walkBob;
      // Guitar strap across shoulder
      _drawPixelLine(
        canvas,
        Offset(-px * 3, -totalH + px * 27 + walkBob),
        Offset(px * 4, gy),
        pixelSize: px * 1.6,
        color: Colors.black,
      );
      drawPurplePrsGuitar(
        canvas,
        Offset(px * 3, gy),
        scale: px * 0.72,
        angle: isStrumming ? -0.34 : -0.22,
      );
    }

    // 5. Spider Web-Shooter Wrist Pixel Glow
    if (hasSpiderPower) {
      p.color = const Color(0xFF3CBCFC);
      canvas.drawRect(
        Rect.fromLTWH(px * 9, -totalH + px * 48 + walkBob, px * 3, px * 3),
        p,
      );
    }

    canvas.restore();
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
        drawPurplePrsGuitar(
          canvas,
          Offset(sx - 4, sy + 2),
          scale: 0.90,
          angle: -0.58,
        );
        _drawLabel(
          canvas,
          'PURPLE PRS [CHORDS]',
          Offset(sx, sy - 28),
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
    const double px = 1.5;
    final double phase = worldTime * 24.0 + chord.x * 0.08;

    canvas.save();
    canvas.translate(sx, sy);
    if (chord.vx < 0) {
      canvas.scale(-1.0, 1.0);
    }

    // 1. Oscillating Audio Waveform / Equalizer Bars in the Wake (x: -22..+2)
    const int barCount = 9;
    for (int i = 0; i < barCount; i++) {
      final double t = (i + 1) / barCount; // 0..1 from tail to front
      final double bx = -22.0 + i * 3.0;
      final double wave = (0.45 + 0.55 * sin(phase - i * 0.85).abs()) * t;
      final double halfH = (2.0 + wave * 11.0).floorToDouble();

      // 1px black pixel outline around each waveform bar
      p.color = const Color(0xFF020103);
      canvas.drawRect(
        Rect.fromLTWH(bx - 1, -halfH - 1, 4.0, halfH * 2 + 2.0),
        p,
      );
      // Colored harmonic bar body
      p.color = chord.color;
      canvas.drawRect(
        Rect.fromLTWH(bx, -halfH, 2.0, halfH * 2),
        p,
      );
      // Bright white center audio axis core
      p.color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(bx, -halfH * 0.35, 2.0, max(2.0, halfH * 0.7)),
        p,
      );
    }

    // 2. Three Concentric Propagating Sonic Wavefront Arcs ")))" (x: +3..+20)
    // Drawn as stepped pixel-art crescent arcs curving forward in the direction of travel
    for (int arcIdx = 0; arcIdx < 3; arcIdx++) {
      final double baseX = 3.0 + arcIdx * 6.0;
      final int halfSteps = 4 + arcIdx * 2; // 4, 6, 8 pixel steps above & below y=0
      final bool isLeadingArc = arcIdx == 2;

      // Pass 1: Black pixel outline behind the sonic arc
      p.color = const Color(0xFF020103);
      for (int s = -halfSteps; s <= halfSteps; s++) {
        final double norm = s.abs() / halfSteps;
        final double curveOffset =
            ((1.0 - norm * norm) * (3.5 + arcIdx * 1.2)).floorToDouble();
        final double ax = baseX + curveOffset;
        final double ay = s * px * 1.35;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(ax, ay),
            width: px * 2.8,
            height: px * 2.4,
          ),
          p,
        );
      }

      // Pass 2: Vibrant neon soundwave arc body + white leading-edge highlight
      for (int s = -halfSteps; s <= halfSteps; s++) {
        final double norm = s.abs() / halfSteps;
        final double curveOffset =
            ((1.0 - norm * norm) * (3.5 + arcIdx * 1.2)).floorToDouble();
        final double ax = baseX + curveOffset;
        final double ay = s * px * 1.35;

        p.color = chord.color;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(ax, ay),
            width: px * 1.7,
            height: px * 1.5,
          ),
          p,
        );
        if (s.abs() <= halfSteps - 2 || isLeadingArc) {
          p.color = Colors.white;
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(ax + px * 0.35, ay),
              width: px * 0.8,
              height: px * 1.1,
            ),
            p,
          );
        }
      }
    }

    canvas.restore();
  }

  void _drawNesBannerLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double fontSize = 10,
  }) {
    _drawLabel(
      canvas,
      text,
      center,
      color,
      fontSize: fontSize,
      bold: true,
    );
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

// --- Title Screen Hero Showcase Painter (archBTW + Purple PRS Custom 24) ---
class _SuperArchBtwTitleHeroPainter extends CustomPainter {
  final double worldTime;

  _SuperArchBtwTitleHeroPainter({required this.worldTime});

  void _drawMatrix(
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
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..isAntiAlias = false;

    // Retro stage floor pedestal
    final double floorY = size.height - 10;
    p.color = const Color(0xFF33134F);
    canvas.drawRect(Rect.fromLTWH(16, floorY, size.width - 32, 6), p);
    p.color = const Color(0xFFB878F8);
    canvas.drawRect(Rect.fromLTWH(24, floorY, size.width - 48, 2), p);

    // 1. Draw the identical 28x80 archBTW character sprite on the left-center of the stage
    final double charPx = (size.height - 16) / 80.0;
    final double charW = 28 * charPx;
    final double charX = size.width * 0.34 - charW / 2;
    final double charTopY = floorY - 80 * charPx;

    _drawMatrix(
      canvas,
      _OkcRetroGamePainter.archBtwLeftLegMatrix,
      _OkcRetroGamePainter.archBtwCharacterPalette,
      pixelSize: charPx,
      origin: Offset(charX, charTopY + 58 * charPx),
    );
    _drawMatrix(
      canvas,
      _OkcRetroGamePainter.archBtwRightLegMatrix,
      _OkcRetroGamePainter.archBtwCharacterPalette,
      pixelSize: charPx,
      origin: Offset(charX, charTopY + 58 * charPx),
    );
    _drawMatrix(
      canvas,
      _OkcRetroGamePainter.archBtwUpperBodyMatrix,
      _OkcRetroGamePainter.archBtwCharacterPalette,
      pixelSize: charPx,
      origin: Offset(charX, charTopY),
    );

    // 2. Draw the detailed Purple PRS Custom 24 showcase on the right side of the stage
    final double bob = sin(worldTime * 3.5) * 3.5;
    final double gx = size.width * 0.64;
    final double gy = size.height * 0.54 + bob;

    _OkcRetroGamePainter.drawPurplePrsGuitar(
      canvas,
      Offset(gx, gy),
      scale: charPx * 1.25,
      angle: -0.62,
    );
  }

  @override
  bool shouldRepaint(covariant _SuperArchBtwTitleHeroPainter oldDelegate) =>
      oldDelegate.worldTime != worldTime;
}
