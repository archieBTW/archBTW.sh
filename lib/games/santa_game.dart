import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const String kPlayerEmoji = '💸'; 
const String kBulletEmoji = '🎁'; 
const Color kMoneyGreen = Color(0xFF00FF00); 

enum EnemyType {
  santa,    // Big Boss
  baby,     // Fast & erratic
  snowman,  // Zig Zag
  cookie    // Slow fodder
}

class SantasInvadersGame extends StatefulWidget {
  const SantasInvadersGame({super.key});

  @override
  State<SantasInvadersGame> createState() => _SantasInvadersGameState();
}

class _SantasInvadersGameState extends State<SantasInvadersGame> with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer(); 

  // Game State
  double playerX = 0.0;
  List<_Bullet> bullets = [];
  List<_Enemy> enemies = [];
  int score = 0;
  bool isGameOver = false;
  bool isPlaying = false;

  // Controls State
  bool _movingLeft = false;
  bool _movingRight = false;

  // Loop Logic
  late Ticker _ticker;
  double _time = 0; 
  final double _playerMoveSpeed = 0.03;

final List<String> _playlist = ['rudolph.wav', 'whos_a_ho.wav', 'xmas_tree.wav', 'workshop.wav'];

  List<String> _musicQueue = [];
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _resetGame();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    // _playRandomBackgroundMusic();
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
    // 1. Don't loop a single song; stop when it finishes so we can trigger the next one
    _audioPlayer.setReleaseMode(ReleaseMode.release);

    // 2. Listen for the song ending
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _playNextTrack();
    });

    // 3. Start the queue
    _playNextTrack();
  }

  Future<void> _playNextTrack() async {
    if (_playlist.isEmpty) return;

    // A. If queue is empty, refill and shuffle
    if (_musicQueue.isEmpty) {
      _musicQueue = List.of(_playlist)..shuffle();
    }

    // B. Get the next song
    final nextSong = _musicQueue.removeAt(0);

    try {
      // Note: Using the specific folder for this game
      final fullPath = 'music/santas_cookies/$nextSong';
      await _audioPlayer.setSource(AssetSource(fullPath));
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  // Future<void> _playRandomBackgroundMusic() async {
  //   try {
      
  //     final randomFileName = tracks[Random().nextInt(tracks.length)];
  //     await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
  //     await _audioPlayer.setVolume(0.5); 
  //     await _audioPlayer.play(AssetSource('music/santas_cookies/$randomFileName'));
  //   } catch (e) {
  //     debugPrint("Error playing music: $e");
  //   }
  // }

  void _resetGame() {
    setState(() {
      playerX = 0.0;
      bullets.clear();
      enemies.clear();
      score = 0;
      isGameOver = false;
      isPlaying = true;
      _movingLeft = false;
      _movingRight = false;
      _time = 0;
      
      _spawnWave();
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _spawnWave() {
    // We now spawn fewer enemies with specific counts
    // 2 Santas (Bosses) at the top
    _spawnSpecificEnemies(EnemyType.santa, count: 2, y: -0.9);
    
    // 3 Snowmen (Zig Zaggers) below them
    _spawnSpecificEnemies(EnemyType.snowman, count: 3, y: -0.6);
    
    // 3 Babies (Fast jittery ones) 
    _spawnSpecificEnemies(EnemyType.baby, count: 3, y: -0.3);
    
    // 4 Cookies (Slow fodder) at the front
    _spawnSpecificEnemies(EnemyType.cookie, count: 4, y: 0.0);
  }

  void _spawnSpecificEnemies(EnemyType type, {required int count, required double y}) {
    if (count <= 0) return;
    // Calculate spacing to center them
    // available width is roughly 1.6 (-0.8 to 0.8)
    double totalWidth = 1.4;
    double gap = count > 1 ? totalWidth / (count - 1) : 0;
    double startX = -(totalWidth / 2);

    for (int i = 0; i < count; i++) {
      // If only 1 enemy, center it. Otherwise, spread them.
      double xPos = count == 1 ? 0.0 : startX + (gap * i);
      
      enemies.add(_Enemy(
        x: xPos, 
        y: y, 
        type: type,
        initialX: xPos 
      ));
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!isPlaying || isGameOver) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
        _resetGame();
      }
      return;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _movingLeft = true;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) _movingRight = true;
      if (event.logicalKey == LogicalKeyboardKey.space) _shoot();
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _movingLeft = false;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) _movingRight = false;
    }
  }

  void _onTick(Duration elapsed) {
    if (!isPlaying || isGameOver) return;

    setState(() {
      _time += 0.05;

      // 1. Player Movement
      if (_movingLeft) playerX -= _playerMoveSpeed;
      if (_movingRight) playerX += _playerMoveSpeed;
      playerX = playerX.clamp(-0.95, 0.95);

      // 2. Bullet Movement
      for (var b in bullets) b.y -= 0.03;
      bullets.removeWhere((b) => b.y < -1.2);

      // 3. Enemy Logic
      for (var e in enemies) {
        _updateEnemyPosition(e);

        // Wrap around Logic
        if (e.y > 1.2) {
          e.y = -1.3; 
          // Randomize X slightly on respawn
          e.initialX = (Random().nextDouble() * 1.4) - 0.7;
          e.x = e.initialX;
        }
      }

      // 4. Collision: Bullet vs Enemy
      List<_Bullet> bulletsToRemove = [];
      List<_Enemy> enemiesToRemove = [];

      for (var b in bullets) {
        for (var e in enemies) {
          double dx = b.x - e.x;
          double dy = b.y - e.y;
          if (sqrt(dx * dx + dy * dy) < 0.1) {
            bulletsToRemove.add(b);
            enemiesToRemove.add(e);
            score += 100;
          }
        }
      }
      
      // 5. Collision: Player vs Enemy
      for (var e in enemies) {
        double dx = playerX - e.x;
        double dy = 0.9 - e.y;
        if (sqrt(dx * dx + dy * dy) < 0.12) {
          _gameOver();
        }
      }

      bullets.removeWhere((b) => bulletsToRemove.contains(b));
      enemies.removeWhere((e) => enemiesToRemove.contains(e));

      // Auto-spawn next wave if cleared
      if (enemies.isEmpty) {
        _spawnWave(); // Uses the new cleaner spawn logic
      }
    });
  }

  void _updateEnemyPosition(_Enemy e) {
    switch (e.type) {
      case EnemyType.santa:
        e.y += 0.0015; 
        e.x = e.initialX + sin(_time * 0.3 + e.offset) * 0.3;
        break;
        
      case EnemyType.baby:
        // "Jittery" - Medium fall, fast shake
        e.y += 0.0035;
        e.x = e.initialX + sin(_time * 6 + e.offset) * 0.05;
        break;

      case EnemyType.snowman:
        // "Zig Zag" - Diagonal bounce
        e.y += 0.0025;
        e.x += (e.dx * 0.6);
        if (e.x > 0.9 || e.x < -0.9) e.dx *= -1;
        break;

      case EnemyType.cookie:
        // "Floater" - Very slow fall
        e.y += 0.001;
        e.x = e.initialX + cos(_time * 1.0 + e.offset) * 0.15;
        break;
    }
  }

  void _gameOver() {
    setState(() {
      isGameOver = true;
      isPlaying = false;
    });
    HapticFeedback.heavyImpact();
  }

  void _shoot() {
    if (!isPlaying || isGameOver) return;
    if (bullets.length >= 3) return; 
    
    setState(() {
      bullets.add(_Bullet(x: playerX, y: 0.8));
    });
    HapticFeedback.lightImpact();
  }

  void _movePlayerTouch(DragUpdateDetails details, double screenWidth) {
    if (!isPlaying) return;
    setState(() {
      playerX += (details.delta.dx / (screenWidth / 2));
      playerX = playerX.clamp(-0.95, 0.95);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text("holiday_consumerism.sh", style: TextStyle(color: Colors.white, fontFamily: 'JetBrainsMono', fontSize: 16)),
        centerTitle: true,
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => _movePlayerTouch(d, constraints.maxWidth),
              onTap: _shoot,
              child: Stack(
                children: [
                  // Game Canvas
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SpacePainter(
                        playerX: playerX,
                        bullets: bullets,
                        enemies: enemies,
                      ),
                    ),
                  ),
                  // Score
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Text(
                      "SPENT: \$$score",
                      style: const TextStyle(
                        color: kMoneyGreen,
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  // Overlay
                  if (!isPlaying || isGameOver)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          border: Border.all(color: kMoneyGreen),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: kMoneyGreen.withOpacity(0.4), blurRadius: 10)]
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isGameOver ? "BANKRUPTCY" : "CONSUMERISM SIM",
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isGameOver 
                                  ? "TOTAL SPENT: \$$score" 
                                  : "DON'T TOUCH THE MERCH\n(ARROWS/DRAG TO MOVE)",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kMoneyGreen,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: _resetGame,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                isGameOver ? "RE-MORTGAGE (SPACE)" : "SHOP NOW",
                                style: const TextStyle(fontFamily: 'JetBrainsMono'),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Bullet { 
  double x; 
  double y; 
  _Bullet({required this.x, required this.y}); 
}

class _Enemy { 
  double x; 
  double y; 
  double initialX; 
  EnemyType type;
  double offset; 
  double dx; 

  _Enemy({
    required this.x, 
    required this.y, 
    required this.type,
    this.initialX = 0.0,
  }) : offset = Random().nextDouble() * 10,
       dx = (Random().nextBool() ? 0.01 : -0.01);

  String get emoji {
    switch (type) {
      case EnemyType.baby: return '👶';
      case EnemyType.santa: return '🎅';
      case EnemyType.snowman: return '⛄';
      case EnemyType.cookie: return '🍪';
    }
  }
}

class _SpacePainter extends CustomPainter {
  final double playerX;
  final List<_Bullet> bullets;
  final List<_Enemy> enemies;

  _SpacePainter({required this.playerX, required this.bullets, required this.enemies});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    
    void drawEmoji(String text, double normX, double normY, double fontSize) {
      final textSpan = TextSpan(text: text, style: TextStyle(fontSize: fontSize));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      final screenX = center.dx + (normX * (size.width / 2));
      final screenY = center.dy + (normY * (size.height / 2));
      textPainter.paint(canvas, Offset(screenX - textPainter.width / 2, screenY - textPainter.height / 2));
    }

    drawEmoji(kPlayerEmoji, playerX, 0.9, 45);
    for (var b in bullets) drawEmoji(kBulletEmoji, b.x, b.y, 24);
    for (var e in enemies) drawEmoji(e.emoji, e.x, e.y, 32);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}