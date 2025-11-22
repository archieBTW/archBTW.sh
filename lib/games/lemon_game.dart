import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LemonsGame extends StatefulWidget {
  const LemonsGame({super.key});

  @override
  State<LemonsGame> createState() => _LemonsGameState();
}

class _LemonsGameState extends State<LemonsGame> with SingleTickerProviderStateMixin {
  static const List<String> songList = [
    'ai.wav',
    'crosstops.wav',
    'cunt.wav',
    'cups.wav',
    'elixir.wav',
    'florence.wav',
    'it_seemed_like_a_good_idea_at_the_time.wav',
    'mercy.wav',
    'midnight_oil.wav',
    'smart_man.wav',
    'take_it_apart.wav',
    'thats_how.wav',
    'third_time.wav',
  ];

  static const double playerYOffset = 100.0; 
  static const double playerWidth = 70.0; // Adjusted for Basket Emoji width
  static const double playerHeight = 70.0; // Adjusted for Basket Emoji height
  static const double lemonSize = 35.0;
  static const double keyboardSpeed = 10.0; // Slightly faster response for keys
  
  final Random _rng = Random();
  late Ticker _ticker;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FocusNode _focusNode = FocusNode();

  double playerX = 0;
  double screenWidth = 0;
  double screenHeight = 0;
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int lives = 5;
  
  bool _isMovingLeft = false;
  bool _isMovingRight = false;

  List<LemonEntity> lemons = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _playRandomSong();
    
    // Force focus immediately so keyboard works without clicking first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _playRandomSong() async {
    if (songList.isEmpty) return;
    try {
      final filename = songList[_rng.nextInt(songList.length)];
      final path = 'music/lemons/$filename'; 
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  void _startGame() {
    setState(() {
      score = 0;
      lives = 5;
      lemons.clear();
      isGameOver = false;
      isPlaying = true;
      if (screenWidth > 0) {
        playerX = (screenWidth / 2) - (playerWidth / 2);
      }
      // Re-grab focus on start to ensure keys work if user clicked away
      FocusScope.of(context).requestFocus(_focusNode);
    });
    _ticker.start();
  }

  void _stopGame({required bool gameOver}) {
    _ticker.stop();
    setState(() {
      isPlaying = false;
      isGameOver = gameOver;
      _isMovingLeft = false;
      _isMovingRight = false;
    });
  }

  void _onTick(Duration elapsed) {
    if (!isPlaying) return;

    setState(() {
      // 1. Handle Keyboard Movement
      if (_isMovingLeft) {
        playerX -= keyboardSpeed;
      }
      if (_isMovingRight) {
        playerX += keyboardSpeed;
      }

      // Clamp Player to Screen
      if (playerX < 0) playerX = 0;
      if (playerX > screenWidth - playerWidth) playerX = screenWidth - playerWidth;

      // 2. Spawn Lemons
      // Chance increases slightly with score
      if (_rng.nextDouble() < 0.015 + (score * 0.0001)) {
        lemons.add(LemonEntity(
          x: _rng.nextDouble() * (screenWidth - lemonSize),
          y: -50,
          
          speed: 1.5 + _rng.nextDouble() * 3.0 + (score * 0.005), 
          isRotten: _rng.nextDouble() < 0.3, 
        ));
      }

      // 3. Update Lemons & Collisions
      final double playerTop = screenHeight - playerYOffset;
      final double playerBottom = screenHeight - 20; 
      
      for (int i = lemons.length - 1; i >= 0; i--) {
        final lemon = lemons[i];
        lemon.y += lemon.speed;

        final bool hitX = (lemon.x + (lemonSize/2) > playerX) && 
                          (lemon.x + (lemonSize/2) < playerX + playerWidth);
        
        final bool hitY = (lemon.y + lemonSize > playerTop + 10) && 
                          (lemon.y < playerBottom);

        // Caught
        if (hitX && hitY) {
          if (lemon.isRotten) {
            lives--;
            if (lives <= 0) _stopGame(gameOver: true);
          } else {
            score += 10;
          }
          lemons.removeAt(i);
          continue;
        }

        // Floor
        if (lemon.y > screenHeight) {
          if (!lemon.isRotten) {
            lives--;
            if (lives <= 0) _stopGame(gameOver: true);
          }
          lemons.removeAt(i);
        }
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() => _isMovingLeft = true);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() => _isMovingRight = true);
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() => _isMovingLeft = false);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() => _isMovingRight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            screenWidth = constraints.maxWidth;
            screenHeight = constraints.maxHeight;
            
            if (!isPlaying && !isGameOver && playerX == 0) {
              playerX = (screenWidth / 2) - (playerWidth / 2);
            }

            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) {
                    if (isPlaying) {
                      setState(() {
                        playerX += details.delta.dx;
                        if (playerX < 0) playerX = 0;
                        if (playerX > screenWidth - playerWidth) playerX = screenWidth - playerWidth;
                      });
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        for (final lemon in lemons)
                          Positioned(
                            left: lemon.x,
                            top: lemon.y,
                            child: _buildLemon(lemon),
                          ),
                        Positioned(
                          left: playerX,
                          bottom: 20,
                          child: _buildPlayer(),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SCORE: $score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'JetBrainsMono',
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              FontAwesomeIcons.heart,
                              color: index < lives ? const Color(0xFFE74C3C) : Colors.grey.withOpacity(0.3),
                              size: 24,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 10,
                  left: 10,
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),

                if (!isPlaying)
                  Container(
                    color: Colors.black.withOpacity(0.85),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isGameOver ? "LIFE GAVE YOU LEMONS" : "LIFE'S LEMONS",
                            style: const TextStyle(
                              color: Color(0xFFB072FF),
                              fontFamily: 'JetBrainsMono',
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isGameOver)
                            Text(
                              "Final Score: $score",
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'JetBrainsMono',
                                fontSize: 24,
                              ),
                            ),
                          const SizedBox(height: 48),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB072FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _startGame,
                            child: Text(
                              isGameOver ? "TRY AGAIN" : "START GAME",
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Use Arrow Keys or Drag to Move\nCatch Yellow. Dodge Brown.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 14,
                            ),
                          ),
                        ],
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

  Widget _buildLemon(LemonEntity lemon) {
    if (lemon.isRotten) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFF5D4037),
          BlendMode.srcATop,
        ),
        child: const Text('🍋', style: TextStyle(fontSize: 35)),
      );
    } else {
      return const Text('🍋', style: TextStyle(fontSize: 35));
    }
  }

  Widget _buildPlayer() {
    return SizedBox(
      width: playerWidth,
      height: playerHeight,
      child: const Center(
        child: Text(
          '🧺',
          style: TextStyle(
            fontSize: 65, 
          ),
        ),
      ),
    );
  }
}

class LemonEntity {
  double x;
  double y;
  double speed;
  bool isRotten;

  LemonEntity({
    required this.x,
    required this.y,
    required this.speed,
    required this.isRotten,
  });
}