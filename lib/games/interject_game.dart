// import 'dart:async';
// import 'dart:math';
// import 'package:archbtw_sh/global/colors.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/material.dart';

// class InterjectGame extends StatefulWidget {
//   const InterjectGame({super.key});

//   @override
//   State<InterjectGame> createState() => _InterjectGameState();
// }

// class _InterjectGameState extends State<InterjectGame> {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   final List<String> _playlist = [
//     'oakwood.m4a', 
//     'parseltongue.m4a', 
//     'badluck.wav',
//     'so_its.wav',
//     'lunch.wav'
//   ];

//   final int _rows = 7; 
//   final int _cols = 4; 
//   final int _targetScore = 1000;
  
//   final List<Color> _pillColors = [
//     Colors.redAccent,
//     Colors.lightBlueAccent,
//     Colors.greenAccent,
//     Colors.amberAccent,
//     Colors.purpleAccent,
//     Colors.pinkAccent,
//   ];

//   late List<List<Color?>> _grid; 
//   Point<int>? _selectedPoint;
//   int _score = 0;
//   bool _isWon = false;
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     _initGrid();
//     _playRandomBackgroundMusic();
//   }

//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     super.dispose();
//   }

//   Future<void> _playRandomBackgroundMusic() async {
//     if (_playlist.isEmpty) return;
//     try {
//       final randomFileName = _playlist[Random().nextInt(_playlist.length)];
//       final fullPath = 'music/interject/$randomFileName';
//       await _audioPlayer.setSource(AssetSource(fullPath));
//       await _audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await _audioPlayer.setVolume(0.5);
//       await _audioPlayer.resume();
//     } catch (e) {
//       debugPrint("Audio Error: $e");
//     }
//   }

//   void _initGrid() {
//     _grid = List.generate(
//       _rows, 
//       (y) => List.generate(
//         _cols, 
//         (x) => _pillColors[Random().nextInt(_pillColors.length)]
//       )
//     );

//     _resolveMatches(initial: true);

//     setState(() {
//       _score = 0;
//       _isWon = false;
//       _isProcessing = false;
//       _selectedPoint = null;
//     });
//   }

//   void _handleTap(int x, int y) {
//     if (_isProcessing || _isWon) return;

//     setState(() {
//       if (_selectedPoint == null) {
//         _selectedPoint = Point(x, y);
//       } else if (_selectedPoint!.x == x && _selectedPoint!.y == y) {
//         _selectedPoint = null;
//       } else {
//         final dx = (x - _selectedPoint!.x).abs();
//         final dy = (y - _selectedPoint!.y).abs();
        
//         final isNeighbor = dx <= 1 && dy <= 1 && !(dx == 0 && dy == 0);

//         if (isNeighbor) {
//           _attemptSwap(_selectedPoint!, Point(x, y));
//           _selectedPoint = null;
//         } else {
//           _selectedPoint = Point(x, y);
//         }
//       }
//     });
//   }

//   Future<void> _attemptSwap(Point<int> p1, Point<int> p2) async {
//     setState(() {
//       _isProcessing = true;
//       final temp = _grid[p1.y][p1.x];
//       _grid[p1.y][p1.x] = _grid[p2.y][p2.x];
//       _grid[p2.y][p2.x] = temp;
//     });

//     await Future.delayed(const Duration(milliseconds: 200));

//     bool hasMatch = await _resolveMatches();

//     if (!hasMatch) {
//       if (mounted) {
//         setState(() {
//           final temp = _grid[p1.y][p1.x];
//           _grid[p1.y][p1.x] = _grid[p2.y][p2.x];
//           _grid[p2.y][p2.x] = temp;
//           _isProcessing = false;
//         });
//       }
//     }
//   }

//   // --- Core Game Loop ---
//   Future<bool> _resolveMatches({bool initial = false}) async {
//     Set<Point<int>> matchedPoints = {};

//     // 1. Horizontal
//     for (int y = 0; y < _rows; y++) {
//       for (int x = 0; x < _cols - 2; x++) {
//         final c = _grid[y][x];
//         if (c == null) continue;
//         if (_grid[y][x + 1] == c && _grid[y][x + 2] == c) {
//           matchedPoints.add(Point(x, y));
//           matchedPoints.add(Point(x + 1, y));
//           matchedPoints.add(Point(x + 2, y));
//           int k = x + 3;
//           while (k < _cols && _grid[y][k] == c) {
//             matchedPoints.add(Point(k, y));
//             k++;
//           }
//         }
//       }
//     }

//     // 2. Vertical
//     for (int x = 0; x < _cols; x++) {
//       for (int y = 0; y < _rows - 2; y++) {
//         final c = _grid[y][x];
//         if (c == null) continue;
//         if (_grid[y + 1][x] == c && _grid[y + 2][x] == c) {
//           matchedPoints.add(Point(x, y));
//           matchedPoints.add(Point(x, y + 1));
//           matchedPoints.add(Point(x, y + 2));
//           int k = y + 3;
//           while (k < _rows && _grid[k][x] == c) {
//             matchedPoints.add(Point(x, k));
//             k++;
//           }
//         }
//       }
//     }

//     // 3. Diagonal Down-Right
//     for (int y = 0; y < _rows - 2; y++) {
//       for (int x = 0; x < _cols - 2; x++) {
//         final c = _grid[y][x];
//         if (c == null) continue;
//         if (_grid[y + 1][x + 1] == c && _grid[y + 2][x + 2] == c) {
//           matchedPoints.add(Point(x, y));
//           matchedPoints.add(Point(x + 1, y + 1));
//           matchedPoints.add(Point(x + 2, y + 2));
//           int k = 3;
//           while (y + k < _rows && x + k < _cols && _grid[y + k][x + k] == c) {
//             matchedPoints.add(Point(x + k, y + k));
//             k++;
//           }
//         }
//       }
//     }

//     // 4. Diagonal Down-Left
//     for (int y = 0; y < _rows - 2; y++) {
//       for (int x = 2; x < _cols; x++) {
//         final c = _grid[y][x];
//         if (c == null) continue;
//         if (_grid[y + 1][x - 1] == c && _grid[y + 2][x - 2] == c) {
//           matchedPoints.add(Point(x, y));
//           matchedPoints.add(Point(x - 1, y + 1));
//           matchedPoints.add(Point(x - 2, y + 2));
//           int k = 3;
//           while (y + k < _rows && x - k >= 0 && _grid[y + k][x - k] == c) {
//             matchedPoints.add(Point(x - k, y + k));
//             k++;
//           }
//         }
//       }
//     }

//     if (matchedPoints.isNotEmpty) {
//       if (!initial) {
//         if (mounted) {
//           setState(() {
//             for (var p in matchedPoints) {
//               _grid[p.y][p.x] = null;
//             }
//             _score += matchedPoints.length * 10;
//             if (_score >= _targetScore) _isWon = true;
//           });
//         }
//         await Future.delayed(const Duration(milliseconds: 200));
//       } else {
//         for (var p in matchedPoints) {
//           _grid[p.y][p.x] = null;
//         }
//       }

//       await _applyGravity();
//       await _resolveMatches(initial: initial);
//       return true;
//     }

//     if (!initial && mounted) {
//       setState(() {
//         _isProcessing = false;
//       });
//     }
//     return false;
//   }

//   Future<void> _applyGravity() async {
//     bool moved = false;
//     for (int x = 0; x < _cols; x++) {
//       int writeIdx = _rows - 1;
//       for (int readIdx = _rows - 1; readIdx >= 0; readIdx--) {
//         if (_grid[readIdx][x] != null) {
//           _grid[writeIdx][x] = _grid[readIdx][x];
//           if (writeIdx != readIdx) {
//             _grid[readIdx][x] = null;
//             moved = true;
//           }
//           writeIdx--;
//         }
//       }
//       for (int i = writeIdx; i >= 0; i--) {
//         _grid[i][x] = _pillColors[Random().nextInt(_pillColors.length)];
//         moved = true;
//       }
//     }
//     if (moved && mounted) {
//       setState(() {});
//       await Future.delayed(const Duration(milliseconds: 200));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: kAccentColor),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: Text(
//           _isWon ? "ROOT ACCESS GRANTED" : "./compile_data.sh",
//           style: TextStyle(
//             fontFamily: 'JetBrainsMono',
//             color: _isWon ? Colors.green : kAccentColor,
//             fontSize: 16,
//           ),
//         ),
//         actions: [
//           Center(
//             child: Padding(
//               padding: const EdgeInsets.only(right: 16.0),
//               child: Text(
//                 "DATA: $_score/$_targetScore",
//                 style: const TextStyle(
//                   fontFamily: 'JetBrainsMono', 
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           )
//         ],
//       ),
//       body: _isWon ? _buildWinScreen() : _buildGameLayout(),
//     );
//   }

//   Widget _buildWinScreen() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.check_circle_outline, color: kAccentColor, size: 80),
//           const SizedBox(height: 20),
//           const Text(
//             "COMPILATION COMPLETE",
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontFamily: 'JetBrainsMono',
//               color: kAccentColor,
//               fontWeight: FontWeight.bold,
//               fontSize: 24,
//             ),
//           ),
//           const SizedBox(height: 40),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//               backgroundColor: kAccentColor,
//               foregroundColor: Colors.black,
//             ),
//             onPressed: _initGrid,
//             child: const Text("sudo reboot", style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 18)),
//           )
//         ],
//       ),
//     );
//   }

//   Widget _buildGameLayout() {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final double maxWidth = constraints.maxWidth - 8; 
//         final double maxHeight = constraints.maxHeight - 8;
        
//         double cellSize = maxWidth / _cols;
//         if (cellSize * _rows > maxHeight) {
//           cellSize = maxHeight / _rows;
//         }

//         return Center(
//           child: SizedBox(
//             width: cellSize * _cols,
//             height: cellSize * _rows,
//             child: GridView.builder(
//               physics: const NeverScrollableScrollPhysics(),
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: _cols,
//                 childAspectRatio: 1.0,
//               ),
//               itemCount: _rows * _cols,
//               itemBuilder: (context, index) {
//                 final int y = index ~/ _cols;
//                 final int x = index % _cols;
//                 return GestureDetector(
//                   onTap: () => _handleTap(x, y),
//                   child: _buildPillCell(x, y, cellSize),
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildPillCell(int x, int y, double size) {
//     final color = _grid[y][x];
//     if (color == null) return const SizedBox(); 

//     final isSelected = _selectedPoint != null && _selectedPoint!.x == x && _selectedPoint!.y == y;

//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         // Layer 1: The Pill
//         ColorFiltered(
//           colorFilter: ColorFilter.mode(
//             color.withOpacity(0.6), 
//             BlendMode.srcATop, 
//           ),
//           child: Text(
//             '💊',
//             style: TextStyle(
//               fontSize: size * 0.85, 
//               height: 1.0,
//               decoration: TextDecoration.none,
//               color: Colors.white, 
//             ),
//           ),
//         ),

//         // Layer 2: Selection Ring
//         if (isSelected)
//           Container(
//             width: size * 0.9,
//             height: size * 0.9,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.white, width: 3),
//               boxShadow: [
//                 BoxShadow(
//                   color: color.withOpacity(0.5), 
//                   blurRadius: 15, 
//                   spreadRadius: 2
//                 )
//               ],
//             ),
//           ),
//       ],
//     );
//   }
// }

import 'dart:async';
import 'dart:math';
import 'package:archbtw_sh/global/colors.dart'; // Assumes this exists based on your snippet
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

// 1. Data Class to track unique pills for animation
class Pill {
  final Color color;
  final String id;

  Pill(this.color) : id = UniqueKey().toString();
}

class InterjectGame extends StatefulWidget {
  const InterjectGame({super.key});

  @override
  State<InterjectGame> createState() => _InterjectGameState();
}

class _InterjectGameState extends State<InterjectGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _playlist = [
    'oakwood.m4a',
    'parseltongue.m4a',
    'badluck.wav',
    'so_its.wav',
    'lunch.wav'
  ];

  List<String> _musicQueue = [];
  
  // NEW: Subscription to listen for song completion
  StreamSubscription? _playerCompleteSubscription;

  final int _rows = 8; // Slightly taller to account for non-refilling
  final int _cols = 5;
  
  // 2. High Contrast Colors
  final List<Color> _pillColors = [
    const Color(0xFFE53935), // Red
    const Color(0xFF1E88E5), // Blue
    const Color(0xFF43A047), // Green
    const Color(0xFFFDD835), // Yellow
    const Color(0xFF8E24AA), // Purple
    const Color(0xFFFB8C00), // Orange
  ];

  late List<List<Pill?>> _grid;
  Point<int>? _selectedPoint;
  
  // Game State
  int _score = 0;
  bool _isWon = false;
  bool _isGameOver = false;
  bool _isProcessing = false;

  // Timer State
  Timer? _gameTimer;
  int _secondsRemaining = 180; // 3 Minutes

  @override
  void initState() {
    super.initState();
    _initGrid(resetScore: true);
    
    // Initialize Audio Logic
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    // Cancel the listener so it doesn't try to play music after closing
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

void _setupAudioPlayer() {
    // 1. Set the player to STOP when a song finishes (instead of looping)
    _audioPlayer.setReleaseMode(ReleaseMode.release);

    // 2. Listen for when the song finishes to trigger the next one
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _playNextTrack();
    });

    // 3. Start the first track
    _playNextTrack();
  }

  Future<void> _playNextTrack() async {
    if (_playlist.isEmpty) return;

    // A. If the queue is empty, refill it with a fresh shuffle
    if (_musicQueue.isEmpty) {
      _musicQueue = List.of(_playlist)..shuffle();
    }

    // B. Pop the next song from the queue
    final nextSong = _musicQueue.removeAt(0);

    try {
      final fullPath = 'music/interject/$nextSong';
      await _audioPlayer.setSource(AssetSource(fullPath));
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint("Audio Error: $e");
      // Optional: Try next song if this one fails to load
      // _playNextTrack(); 
    }
  }

  Future<void> _cleanupStragglers() async {
    // 1. Count how many of each color exist on the board
    Map<Color, int> colorCounts = {};
    for (var row in _grid) {
      for (var pill in row) {
        if (pill != null) {
          colorCounts[pill.color] = (colorCounts[pill.color] ?? 0) + 1;
        }
      }
    }

    // 2. Identify colors that are impossible to match (count < 3)
    List<Color> doomedColors = [];
    colorCounts.forEach((color, count) {
      if (count > 0 && count < 3) {
        doomedColors.add(color);
      }
    });

    if (doomedColors.isEmpty) return;

    // 3. Remove the doomed pills
    bool changed = false;
    setState(() {
      for (int y = 0; y < _rows; y++) {
        for (int x = 0; x < _cols; x++) {
          final pill = _grid[y][x];
          if (pill != null && doomedColors.contains(pill.color)) {
            _grid[y][x] = null;
            // Optional: Give a small pity score for auto-cleared items
            _score += 5; 
            changed = true;
          }
        }
      }
    });

    // 4. If we removed things, we need to apply gravity and check for new matches
    if (changed) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _applyGravity();
      // Recursively check matches, which might trigger cleanup again
      await _resolveMatches(); 
    }
  }

  Future<void> _playRandomBackgroundMusic() async {
    if (_playlist.isEmpty) return;
    try {
      final randomFileName = _playlist[Random().nextInt(_playlist.length)];
      final fullPath = 'music/interject/$randomFileName';
      await _audioPlayer.setSource(AssetSource(fullPath));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _secondsRemaining = 180;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _isGameOver = true;
          _gameTimer?.cancel();
        }
      });
    });
  }

  void _initGrid({bool resetScore = true}) {
    // Initialize empty grid
    _grid = List.generate(
      _rows,
      (_) => List<Pill?>.filled(_cols, null),
    );

    // Fill Top-to-Bottom
    for (int y = 0; y < _rows; y++) {
      
      for (int x = 0; x < _cols; x++) {
        Color proposedColor;
        // Keep picking colors until one doesn't make a match
        do {
          
          proposedColor = _pillColors[Random().nextInt(_pillColors.length)];
          
        } while (!_isMatchSafe(_grid, x, y, proposedColor, isTopDown: true));

        _grid[y][x] = Pill(proposedColor);
      }
    }

    setState(() {
      // ONLY reset score if specifically asked (e.g., Game Over)
      if (resetScore) _score = 0; 
      
      _isWon = false;
      _isGameOver = false;
      _isProcessing = false;
      _selectedPoint = null;
    });

    _startTimer();
  }

  Future<void> _shuffleGrid() async {
    if (_isProcessing || _isWon || _isGameOver) return;

    setState(() {
      _isProcessing = true;
    });

    List<Pill> availablePills = [];
    for (var row in _grid) {
      for (var pill in row) {
        if (pill != null) availablePills.add(pill);
      }
    }
    availablePills.shuffle();

    List<List<Pill?>> newGrid = List.generate(
      _rows,
      (_) => List<Pill?>.filled(_cols, null),
    );

    int pillIndex = 0;
    
    // Fill Bottom-to-Top
    for (int y = _rows - 1; y >= 0; y--) {
      for (int x = 0; x < _cols; x++) {
        if (pillIndex >= availablePills.length) break;

        int foundIndex = -1;
        
        for (int k = pillIndex; k < availablePills.length; k++) {
          // Pass isTopDown: false because we are checking DOWNWARD neighbors
          if (_isMatchSafe(newGrid, x, y, availablePills[k].color, isTopDown: false)) {
            foundIndex = k;
            break;
          }
        }

        if (foundIndex != -1) {
          final temp = availablePills[pillIndex];
          availablePills[pillIndex] = availablePills[foundIndex];
          availablePills[foundIndex] = temp;
        } 

        newGrid[y][x] = availablePills[pillIndex];
        pillIndex++;
      }
    }

    setState(() {
      _grid = newGrid;
      _selectedPoint = null; 
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _resolveMatches();

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Helper to ensure we don't place 3-in-a-row during shuffle
  bool _isSafeForShuffle(List<List<Pill?>> tempGrid, int x, int y, Color color) {
    // Check Left (x-1, x-2)
    if (x >= 2) {
      if (tempGrid[y][x - 1]?.color == color && tempGrid[y][x - 2]?.color == color) {
        return false;
      }
    }

    // Check Down (y+1, y+2) - since we fill Bottom-Up, these are already populated
    if (y < _rows - 2) {
      if (tempGrid[y + 1][x]?.color == color && tempGrid[y + 2][x]?.color == color) {
        return false;
      }
    }

    return true;
  }

  bool _isMatchSafe(List<List<Pill?>> tempGrid, int x, int y, Color color, {required bool isTopDown}) {
    // 1. Horizontal (Always check Left)
    if (x >= 2) {
      if (tempGrid[y][x - 1]?.color == color && tempGrid[y][x - 2]?.color == color) {
        return false;
      }
    }

    if (isTopDown) {
      // --- Generating New Level (Filling Top -> Down) ---
      
      // Check Up
      if (y >= 2) {
        if (tempGrid[y - 1][x]?.color == color && tempGrid[y - 2][x]?.color == color) return false;
      }
      // Check Diagonal Up-Left
      if (x >= 2 && y >= 2) {
        if (tempGrid[y - 1][x - 1]?.color == color && tempGrid[y - 2][x - 2]?.color == color) return false;
      }
      // Check Diagonal Up-Right
      if (x <= _cols - 3 && y >= 2) {
        if (tempGrid[y - 1][x + 1]?.color == color && tempGrid[y - 2][x + 2]?.color == color) return false;
      }

    } else {
      // --- Shuffling (Filling Bottom -> Up) ---
      
      // Check Down
      if (y <= _rows - 3) {
        if (tempGrid[y + 1][x]?.color == color && tempGrid[y + 2][x]?.color == color) return false;
      }
      // Check Diagonal Down-Left
      if (x >= 2 && y <= _rows - 3) {
        if (tempGrid[y + 1][x - 1]?.color == color && tempGrid[y + 2][x - 2]?.color == color) return false;
      }
      // Check Diagonal Down-Right
      if (x <= _cols - 3 && y <= _rows - 3) {
        if (tempGrid[y + 1][x + 1]?.color == color && tempGrid[y + 2][x + 2]?.color == color) return false;
      }
    }

    return true;
  }

  void _handleTap(int x, int y) {
    // Prevent interaction if animation running, won, lost, or clicking empty space
    if (_isProcessing || _isWon || _isGameOver || _grid[y][x] == null) return;

    setState(() {
      if (_selectedPoint == null) {
        _selectedPoint = Point(x, y);
      } else if (_selectedPoint!.x == x && _selectedPoint!.y == y) {
        _selectedPoint = null;
      } else {
        final dx = (x - _selectedPoint!.x).abs();
        final dy = (y - _selectedPoint!.y).abs();

        final isNeighbor = dx <= 1 && dy <= 1 && !(dx == 0 && dy == 0);

        if (isNeighbor) {
          _attemptSwap(_selectedPoint!, Point(x, y));
          _selectedPoint = null;
        } else {
          _selectedPoint = Point(x, y);
        }
      }
    });
  }

  Future<void> _attemptSwap(Point<int> p1, Point<int> p2) async {
    setState(() {
      _isProcessing = true;
      final temp = _grid[p1.y][p1.x];
      _grid[p1.y][p1.x] = _grid[p2.y][p2.x];
      _grid[p2.y][p2.x] = temp;
    });

    // 3. Animation Delay: Wait for the swap animation to finish visually
    await Future.delayed(const Duration(milliseconds: 300));

    bool hasMatch = await _resolveMatches();

    if (!hasMatch) {
      if (mounted) {
        setState(() {
          // Swap back if no match
          final temp = _grid[p1.y][p1.x];
          _grid[p1.y][p1.x] = _grid[p2.y][p2.x];
          _grid[p2.y][p2.x] = temp;
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _resolveMatches({bool initial = false}) async {
    Set<Point<int>> matchedPoints = {};

    Color? getColor(int x, int y) => _grid[y][x]?.color;

    // 1. Horizontal
    for (int y = 0; y < _rows; y++) {
      for (int x = 0; x < _cols - 2; x++) {
        final c = getColor(x, y);
        if (c == null) continue;
        if (getColor(x + 1, y) == c && getColor(x + 2, y) == c) {
          matchedPoints.addAll([Point(x, y), Point(x + 1, y), Point(x + 2, y)]);
          int k = x + 3;
          while (k < _cols && getColor(k, y) == c) {
            matchedPoints.add(Point(k, y));
            k++;
          }
        }
      }
    }

    // 2. Vertical
    for (int x = 0; x < _cols; x++) {
      for (int y = 0; y < _rows - 2; y++) {
        final c = getColor(x, y);
        if (c == null) continue;
        if (getColor(x, y + 1) == c && getColor(x, y + 2) == c) {
          matchedPoints.addAll([Point(x, y), Point(x, y + 1), Point(x, y + 2)]);
          int k = y + 3;
          while (k < _rows && getColor(x, k) == c) {
            matchedPoints.add(Point(x, k));
            k++;
          }
        }
      }
    }

    // 3. Diagonal Down-Right
    for (int y = 0; y < _rows - 2; y++) {
      for (int x = 0; x < _cols - 2; x++) {
        final c = getColor(x, y);
        if (c == null) continue;
        if (getColor(x + 1, y + 1) == c && getColor(x + 2, y + 2) == c) {
          matchedPoints.addAll([Point(x, y), Point(x + 1, y + 1), Point(x + 2, y + 2)]);
          int k = 3;
          while (y + k < _rows && x + k < _cols && getColor(x + k, y + k) == c) {
            matchedPoints.add(Point(x + k, y + k));
            k++;
          }
        }
      }
    }

    // 4. Diagonal Down-Left
    for (int y = 0; y < _rows - 2; y++) {
      for (int x = 2; x < _cols; x++) {
        final c = getColor(x, y);
        if (c == null) continue;
        if (getColor(x - 1, y + 1) == c && getColor(x - 2, y + 2) == c) {
          matchedPoints.addAll([Point(x, y), Point(x - 1, y + 1), Point(x - 2, y + 2)]);
          int k = 3;
          while (y + k < _rows && x - k >= 0 && getColor(x - k, y + k) == c) {
            matchedPoints.add(Point(x - k, y + k));
            k++;
          }
        }
      }
    }

    if (matchedPoints.isNotEmpty) {
      if (!initial) {
        if (mounted) {
          setState(() {
            for (var p in matchedPoints) {
              _grid[p.y][p.x] = null;
            }
            _score += matchedPoints.length * 10;
          });
        }
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        for (var p in matchedPoints) {
          _grid[p.y][p.x] = null;
        }
      }

      await _applyGravity();
      await _resolveMatches(initial: initial);
      return true;
    }

    // --- NEW LOGIC START ---
    // If no standard matches were found, check if we have any unwinnable stragglers.
    if (!initial) {
      await _cleanupStragglers();
      _checkWinCondition();
    }
    // --- NEW LOGIC END ---

    if (!initial && mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
    return false;
  }

  void _checkWinCondition() {
    bool isEmpty = true;
    for(var row in _grid) {
      for(var pill in row) {
        if(pill != null) {
          isEmpty = false;
          break;
        }
      }
    }
    if(isEmpty && !_isWon) {
       setState(() {
         _isWon = true;
         _gameTimer?.cancel();
       });
    }
  }

  // 4. Gravity without spawning new items
  Future<void> _applyGravity() async {
    bool moved = false;
    for (int x = 0; x < _cols; x++) {
      int writeIdx = _rows - 1;
      for (int readIdx = _rows - 1; readIdx >= 0; readIdx--) {
        if (_grid[readIdx][x] != null) {
          if (writeIdx != readIdx) {
            _grid[writeIdx][x] = _grid[readIdx][x];
            _grid[readIdx][x] = null;
            moved = true;
          }
          writeIdx--;
        }
      }
      // Note: We do NOT fill the top with new random pills anymore
    }
    if (moved && mounted) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  String get _timerString {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kAccentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isWon ? "SYSTEM CLEAN" : (_isGameOver ? "TIMEOUT" : _timerString),
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            color: _isWon ? Colors.green : (_isGameOver ? Colors.red : kAccentColor),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "DATA CLEARED: $_score",
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
        
      ),
      floatingActionButton: (!_isWon && !_isGameOver) 
          ? FloatingActionButton(
              onPressed: _shuffleGrid,
              backgroundColor: kAccentColor,
              child: const Icon(Icons.shuffle, color: Colors.black),
            )
          : null,
      body: Stack(
        children: [
          if (_isWon) _buildWinScreen(),
          if (_isGameOver && !_isWon) _buildLoseScreen(),
          if (!_isWon && !_isGameOver) _buildGameLayout(),
        ],
      ),
    );
  }

  Widget _buildWinScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          const Text(
            "ROOT ACCESS GRANTED",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: kAccentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () => _initGrid(resetScore: false),
            child: const Text("sudo reboot", style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 18)),
          )
        ],
      ),
    );
  }

  Widget _buildLoseScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 80),
          const SizedBox(height: 20),
          const Text(
            "CONNECTION TIMED OUT",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: kAccentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () => _initGrid(resetScore: true),
            child: const Text("retry", style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 18)),
          )
        ],
      ),
    );
  }

  // 5. New Layout Engine using Stack for Animations
  Widget _buildGameLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth - 16;
        final double maxHeight = constraints.maxHeight - 16;

        // Calculate cell size to fit everything
        double cellSize = maxWidth / _cols;
        if (cellSize * _rows > maxHeight) {
          cellSize = maxHeight / _rows;
        }
        
        // Center the grid horizontally/vertically
        final double xOffset = (constraints.maxWidth - (cellSize * _cols)) / 2;
        final double yOffset = (constraints.maxHeight - (cellSize * _rows)) / 2;

        List<Widget> pillWidgets = [];

        // Background Grid (Static placeholders)
        for (int y = 0; y < _rows; y++) {
          for (int x = 0; x < _cols; x++) {
            pillWidgets.add(
              Positioned(
                left: xOffset + (x * cellSize),
                top: yOffset + (y * cellSize),
                width: cellSize,
                height: cellSize,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // Tap detection must be on the grid slots, not just the moving pills
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _handleTap(x, y),
                  ),
                ),
              )
            );
          }
        }

        // Moving Pills (Animated)
        for (int y = 0; y < _rows; y++) {
          for (int x = 0; x < _cols; x++) {
            final pill = _grid[y][x];
            if (pill == null) continue;

            pillWidgets.add(
              AnimatedPositioned(
                // Unique key ensures the widget slides instead of snapping
                key: Key(pill.id), 
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutBack,
                left: xOffset + (x * cellSize),
                top: yOffset + (y * cellSize),
                width: cellSize,
                height: cellSize,
                child: IgnorePointer( // Let taps pass through to the grid slots below
                  child: _buildPillCell(x, y, cellSize, pill),
                ),
              ),
            );
          }
        }

        return Stack(
          children: pillWidgets,
        );
      },
    );
  }

  Widget _buildPillCell(int x, int y, double size, Pill pill) {
    final isSelected = _selectedPoint != null && _selectedPoint!.x == x && _selectedPoint!.y == y;

    return Center(
      child: SizedBox(
        width: size * 0.9,
        height: size * 0.9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The Pill visual
            Container(
              decoration: BoxDecoration(
                color: pill.color,
                borderRadius: BorderRadius.circular(size * 0.3),
                boxShadow: [
                   BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 3,
                  ),
                  // Glossy highlight
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    offset: const Offset(-2, -2),
                    blurRadius: 2,
                    // inset: true
                  ),
                ]
              ),
              child: Center(
                child: Text(
                  '💊',
                  style: TextStyle(
                    fontSize: size * 0.5,
                    height: 1.0,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ),

            // Selection Ring
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.3),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: pill.color.withOpacity(0.8),
                      blurRadius: 15,
                      spreadRadius: 2
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}