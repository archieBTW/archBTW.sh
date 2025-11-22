import 'dart:async';
import 'dart:math';
import 'package:archbtw_sh/global/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WhaleGame extends StatefulWidget {
  const WhaleGame({super.key});

  @override
  State<WhaleGame> createState() => _WhaleGameState();
}

class _WhaleGameState extends State<WhaleGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final List<String> _playlist = [
    'all_aboard_full.wav',
    'beluga_full.wav',
    'dear_carpenter_full.wav',
    'limbofull.wav',
    'sos_full.wav',
    'the_fish_was_this_big.wav'
  ];

  List<String> _musicQueue = [];
  StreamSubscription? _playerCompleteSubscription;

  // --- Physics Variables ---
  static double birdYaxis = 0;
  double time = 0;
  double height = 0;
  double initialHeight = birdYaxis;
  bool gameHasStarted = false;
  bool gameOver = false;
  
  int score = 0;
  int highScore = 0;

  // --- Barrier Variables ---
  static double barrierXone = 2.5;
  double barrierXtwo = 2.5 + 1.8; 
  double barrierYone = 0; 
  double barrierYtwo = -0.5;

  final FocusNode _gameFocusNode = FocusNode();
  Timer? _timer;

@override
  void initState() {
    super.initState();
    
    // Initialize the smart playlist player
    _setupAudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_gameFocusNode);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerCompleteSubscription?.cancel(); // Cancel listener to prevent memory leaks
    _gameFocusNode.dispose();
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
      final fullPath = 'music/blubber/$nextSong';
      await _audioPlayer.setSource(AssetSource(fullPath));
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  // @override
  // void initState() {
  //   super.initState();
    
  //   _playRandomMusic();

  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     FocusScope.of(context).requestFocus(_gameFocusNode);
  //   });
  // }

  // Future<void> _playRandomMusic() async {
  //   if (_playlist.isEmpty) return;

  //   try {
  //     final randomTrack = _playlist[Random().nextInt(_playlist.length)];
      
  //     await _audioPlayer.setVolume(0.5);
      
  //     await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
  //     await _audioPlayer.play(AssetSource('music/blubber/$randomTrack'));
  //   } catch (e) {
  //     debugPrint("Error playing audio: $e");
  //   }
  // }

  // @override
  // void dispose() {
  //   _timer?.cancel();
  //   _gameFocusNode.dispose();
  //   _audioPlayer.dispose();
  //   super.dispose();
  // }

  void jump() {
    if (gameOver) {
      resetGame();
    } else if (!gameHasStarted) {
      startGame();
    } else {
      setState(() {
        time = 0;
        initialHeight = birdYaxis;
      });
    }
  }

  void startGame() {
    gameHasStarted = true;
    gameOver = false;
    score = 0;
    birdYaxis = 0;
    initialHeight = birdYaxis;
    barrierXone = 2.5;
    barrierXtwo = 2.5 + 1.8;
    barrierYone = 0; 
    barrierYtwo = -0.5;
    time = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      
      // Physics
      time += 0.025;
      height = -4.5 * time * time + 2.1 * time; 
      
      setState(() {
        birdYaxis = initialHeight - height;

        barrierXone -= 0.03;
        barrierXtwo -= 0.03;

        if (barrierXone < -2) {
          barrierXone += 3.6;
          barrierYone = _randomizeGap();
          score++;
        }
        if (barrierXtwo < -2) {
          barrierXtwo += 3.6;
          barrierYtwo = _randomizeGap();
          score++;
        }
      });

      if (_checkCollision()) {
        _timer?.cancel();
        setState(() {
          gameOver = true;
          gameHasStarted = false; 
          if (score > highScore) highScore = score;
        });
      }
    });
  }

  void resetGame() {
    setState(() {
      birdYaxis = 0;
      gameHasStarted = false;
      gameOver = false;
      score = 0;
      barrierXone = 2.5;
      barrierXtwo = 2.5 + 1.8;
    });
  }

  double _randomizeGap() {
    return (Random().nextDouble() * 1.2) - 0.6;
  }

bool _checkCollision() {
    // 1. Floor/Ceiling
    if (birdYaxis > 1.2 || birdYaxis < -1.1) return true;

    bool checkSingleBarrier(double bX, double bY) {
      // Define the Gap Size in Alignment Units (Same as visuals below)
      const double gapHeight = 0.7; 
      
      // Whale Size Compensation
      // The whale isn't a single point; it has height (approx 0.1). 
      // We shrink the safe zone by half the whale's height so the *edges* of the whale collide.
      const double whaleHalfHeight = 0.05; 

      // Horizontal Check
      // Check if the whale (width ~0.4) overlaps the pipe (width ~0.5)
      bool horizontalOverlap = (bX > -0.65 && bX < -0.35);

      if (horizontalOverlap) {
        // Vertical Check
        // The "Safe Zone" is the distance from the center of the gap to the wall.
        // Formula: (Gap / 2) - (Whale / 2)
        double safeDist = (gapHeight / 2) - whaleHalfHeight;

        // If the distance between the bird and the gap center is larger than safeDist, HIT.
        if ((birdYaxis - bY).abs() > safeDist) {
          return true;
        }
      }
      return false;
    }

    if (checkSingleBarrier(barrierXone, barrierYone)) return true;
    if (checkSingleBarrier(barrierXtwo, barrierYtwo)) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, 
      body: Center(
        child: KeyboardListener(
          focusNode: _gameFocusNode,
          autofocus: true, 
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.arrowUp) {
                jump();
              }
            }
          },
          child: GestureDetector(
            onTap: jump,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent, width: 2),
                color: Colors.black,
              ),
              child: Stack(
                children: [
                  // 1. Game World
                  Column(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Stack(
                          children: [
                            // Background Grid
                            const _TerminalGrid(),
                            
                            // Barriers
                            _AsciiBarrier(barrierX: barrierXone, barrierY: barrierYone),
                            _AsciiBarrier(barrierX: barrierXtwo, barrierY: barrierYtwo),

                            // The Whale
                            AnimatedContainer(
                              alignment: Alignment(-0.5, birdYaxis),
                              duration: const Duration(milliseconds: 0),
                              child: const _AsciiWhale(),
                            ),

                            // Messages
                            if (!gameHasStarted && !gameOver)
                               const _OverlayMessage(title: "FloppyWhale", subtitle: "The belly of this fish is cold and damp."),
                            
                            if (gameOver)
                               _OverlayMessage(title: "Should've listened in the first place", subtitle: "SCORE: $score // RETRY?"),
                          ],
                        ),
                      ),
                      
                      // 2. Status Bar
                      Container(
                        height: 60,
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text("PID: $score", style: const TextStyle(color: kTerminalGreen, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold)),
                                 Text("MAX: $highScore", style: TextStyle(color: kTerminalGreen.withOpacity(0.6), fontFamily: 'JetBrainsMono', fontSize: 12)),
                               ],
                             ),
                             const Text("root@archBTW:~/floppy_whale.sh", style: TextStyle(color: Colors.white, fontFamily: 'JetBrainsMono')),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 3. Scanlines
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.02),
                            Colors.transparent,
                          ],
                          tileMode: TileMode.repeated
                        ),
                      ),
                      child: CustomPaint(painter: _ScanlinePainter()),
                    ),
                  ),

                  // Close Button
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayMessage extends StatelessWidget {
  final String title;
  final String subtitle;
  const _OverlayMessage({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: kAccentColor),
            color: Colors.black
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: kTerminalGreen, fontSize: 24, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(subtitle, style: const TextStyle(color: kTextColor, fontSize: 14, fontFamily: 'JetBrainsMono', letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsciiWhale extends StatelessWidget {
  const _AsciiWhale();

  static const String whaleArt = r"""
                                    ','. '. ; : ,','
                                      '..'.,',..'
                                         ';.'  ,'
                                          ;;
                                          ;'
                            :._   _.------------.___
                    __      :__:-'                  '--.
             __   ,' .'    .'             ______________'.
           /__ '.-  _\___.'          0  .' .'  .'  _.-_.'
              '._                     .-': .' _.' _.'_.'
       snd       '----'._____________.'_'._:_:_.-'--'
""";

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120, 
      height: 80, 
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          whaleArt,
          style: const TextStyle(
            color: kTextColor,
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.bold,
            height: 1.0, 
          ),
        ),
      ),
    );
  }
}


class _AsciiBarrier extends StatelessWidget {
  final double barrierX;
  final double barrierY; 
  const _AsciiBarrier({required this.barrierX, required this.barrierY});

  @override
  Widget build(BuildContext context) {
    // Must match gapHeight in _checkCollision exactly
    const double gapSize = 0.7; 

    return Container(
      alignment: Alignment(barrierX, 0),
      child: Column(
        children: [
          // TOP PIPE
          Expanded(
            // Calculate the flex based on how much space is ABOVE the gap
            // Formula: Total Space (2.0) - Bottom Space - Gap
            flex: ((1 + barrierY - (gapSize / 2)) * 1000).toInt().clamp(1, 2000),
            child: Container(
              width: 80, 
              alignment: Alignment.bottomCenter,
              // Clip to prevent the text from spilling into the gap
              child: ClipRect(child: const _GlitchBlock(isTop: true)),
            ),
          ),
          
          // THE GAP
          // We use Spacer with flex to ensure the gap is exactly proportional
          // to the alignment coordinates used in physics.
          Spacer(flex: (gapSize * 1000).toInt()), 
          
          // BOTTOM PIPE
          Expanded(
             // Calculate the flex based on how much space is BELOW the gap
            flex: ((1 - barrierY - (gapSize / 2)) * 1000).toInt().clamp(1, 2000),
            child: Container(
              width: 80,
              alignment: Alignment.topCenter,
              child: ClipRect(child: const _GlitchBlock(isTop: false)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlitchBlock extends StatelessWidget {
  final bool isTop;
  const _GlitchBlock({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int lines = (constraints.maxHeight / 14).floor(); 
        return ClipRect(
          child: Column(
            mainAxisAlignment: isTop ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: List.generate(lines, (index) {
              return Text(
                index % 2 == 0 ? "██████████" : "▓▓▓▓▓▓▓▓▓▓",
                style: const TextStyle(
                  color: kTerminalGreen, 
                  fontFamily: 'JetBrainsMono', 
                  fontSize: 14, 
                  height: 1.0,
                  letterSpacing: -2
                ),
              );
            }),
          ),
        );
      }
    );
  }
}

class _TerminalGrid extends StatelessWidget {
  const _TerminalGrid();
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.15,
      child: Image.network(
        "https://upload.wikimedia.org/wikipedia/commons/1/1a/Blank_Go_board.png", 
        repeat: ImageRepeat.repeat,
        color: kTerminalGreen,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.cover,
        errorBuilder: (c,e,s) => Container(), 
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 1;
    for (double i = 0; i < size.height; i += 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(old) => false;
}

