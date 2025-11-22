import 'dart:async';
import 'dart:math';
import 'package:archbtw_sh/global/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

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

  final int _rows = 7; 
  final int _cols = 4; 
  final int _targetScore = 1000;
  
  final List<Color> _pillColors = [
    Colors.redAccent,
    Colors.lightBlueAccent,
    Colors.greenAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
  ];

  late List<List<Color?>> _grid; 
  Point<int>? _selectedPoint;
  int _score = 0;
  bool _isWon = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initGrid();
    _playRandomBackgroundMusic();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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

  void _initGrid() {
    _grid = List.generate(
      _rows, 
      (y) => List.generate(
        _cols, 
        (x) => _pillColors[Random().nextInt(_pillColors.length)]
      )
    );

    _resolveMatches(initial: true);

    setState(() {
      _score = 0;
      _isWon = false;
      _isProcessing = false;
      _selectedPoint = null;
    });
  }

  void _handleTap(int x, int y) {
    if (_isProcessing || _isWon) return;

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

    await Future.delayed(const Duration(milliseconds: 200));

    bool hasMatch = await _resolveMatches();

    if (!hasMatch) {
      if (mounted) {
        setState(() {
          final temp = _grid[p1.y][p1.x];
          _grid[p1.y][p1.x] = _grid[p2.y][p2.x];
          _grid[p2.y][p2.x] = temp;
          _isProcessing = false;
        });
      }
    }
  }

  // --- Core Game Loop ---
  Future<bool> _resolveMatches({bool initial = false}) async {
    Set<Point<int>> matchedPoints = {};

    // 1. Horizontal
    for (int y = 0; y < _rows; y++) {
      for (int x = 0; x < _cols - 2; x++) {
        final c = _grid[y][x];
        if (c == null) continue;
        if (_grid[y][x + 1] == c && _grid[y][x + 2] == c) {
          matchedPoints.add(Point(x, y));
          matchedPoints.add(Point(x + 1, y));
          matchedPoints.add(Point(x + 2, y));
          int k = x + 3;
          while (k < _cols && _grid[y][k] == c) {
            matchedPoints.add(Point(k, y));
            k++;
          }
        }
      }
    }

    // 2. Vertical
    for (int x = 0; x < _cols; x++) {
      for (int y = 0; y < _rows - 2; y++) {
        final c = _grid[y][x];
        if (c == null) continue;
        if (_grid[y + 1][x] == c && _grid[y + 2][x] == c) {
          matchedPoints.add(Point(x, y));
          matchedPoints.add(Point(x, y + 1));
          matchedPoints.add(Point(x, y + 2));
          int k = y + 3;
          while (k < _rows && _grid[k][x] == c) {
            matchedPoints.add(Point(x, k));
            k++;
          }
        }
      }
    }

    // 3. Diagonal Down-Right
    for (int y = 0; y < _rows - 2; y++) {
      for (int x = 0; x < _cols - 2; x++) {
        final c = _grid[y][x];
        if (c == null) continue;
        if (_grid[y + 1][x + 1] == c && _grid[y + 2][x + 2] == c) {
          matchedPoints.add(Point(x, y));
          matchedPoints.add(Point(x + 1, y + 1));
          matchedPoints.add(Point(x + 2, y + 2));
          int k = 3;
          while (y + k < _rows && x + k < _cols && _grid[y + k][x + k] == c) {
            matchedPoints.add(Point(x + k, y + k));
            k++;
          }
        }
      }
    }

    // 4. Diagonal Down-Left
    for (int y = 0; y < _rows - 2; y++) {
      for (int x = 2; x < _cols; x++) {
        final c = _grid[y][x];
        if (c == null) continue;
        if (_grid[y + 1][x - 1] == c && _grid[y + 2][x - 2] == c) {
          matchedPoints.add(Point(x, y));
          matchedPoints.add(Point(x - 1, y + 1));
          matchedPoints.add(Point(x - 2, y + 2));
          int k = 3;
          while (y + k < _rows && x - k >= 0 && _grid[y + k][x - k] == c) {
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
            if (_score >= _targetScore) _isWon = true;
          });
        }
        await Future.delayed(const Duration(milliseconds: 200));
      } else {
        for (var p in matchedPoints) {
          _grid[p.y][p.x] = null;
        }
      }

      await _applyGravity();
      await _resolveMatches(initial: initial);
      return true;
    }

    if (!initial && mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
    return false;
  }

  Future<void> _applyGravity() async {
    bool moved = false;
    for (int x = 0; x < _cols; x++) {
      int writeIdx = _rows - 1;
      for (int readIdx = _rows - 1; readIdx >= 0; readIdx--) {
        if (_grid[readIdx][x] != null) {
          _grid[writeIdx][x] = _grid[readIdx][x];
          if (writeIdx != readIdx) {
            _grid[readIdx][x] = null;
            moved = true;
          }
          writeIdx--;
        }
      }
      for (int i = writeIdx; i >= 0; i--) {
        _grid[i][x] = _pillColors[Random().nextInt(_pillColors.length)];
        moved = true;
      }
    }
    if (moved && mounted) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));
    }
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
          _isWon ? "ROOT ACCESS GRANTED" : "./compile_data.sh",
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            color: _isWon ? Colors.green : kAccentColor,
            fontSize: 16,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "DATA: $_score/$_targetScore",
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
      body: _isWon ? _buildWinScreen() : _buildGameLayout(),
    );
  }

  Widget _buildWinScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: kAccentColor, size: 80),
          const SizedBox(height: 20),
          const Text(
            "COMPILATION COMPLETE",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              color: kAccentColor,
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
            onPressed: _initGrid,
            child: const Text("sudo reboot", style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 18)),
          )
        ],
      ),
    );
  }

  Widget _buildGameLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth - 8; 
        final double maxHeight = constraints.maxHeight - 8;
        
        double cellSize = maxWidth / _cols;
        if (cellSize * _rows > maxHeight) {
          cellSize = maxHeight / _rows;
        }

        return Center(
          child: SizedBox(
            width: cellSize * _cols,
            height: cellSize * _rows,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _cols,
                childAspectRatio: 1.0,
              ),
              itemCount: _rows * _cols,
              itemBuilder: (context, index) {
                final int y = index ~/ _cols;
                final int x = index % _cols;
                return GestureDetector(
                  onTap: () => _handleTap(x, y),
                  child: _buildPillCell(x, y, cellSize),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPillCell(int x, int y, double size) {
    final color = _grid[y][x];
    if (color == null) return const SizedBox(); 

    final isSelected = _selectedPoint != null && _selectedPoint!.x == x && _selectedPoint!.y == y;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Layer 1: The Pill
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            color.withOpacity(0.6), 
            BlendMode.srcATop, 
          ),
          child: Text(
            '💊',
            style: TextStyle(
              fontSize: size * 0.85, 
              height: 1.0,
              decoration: TextDecoration.none,
              color: Colors.white, 
            ),
          ),
        ),

        // Layer 2: Selection Ring
        if (isSelected)
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5), 
                  blurRadius: 15, 
                  spreadRadius: 2
                )
              ],
            ),
          ),
      ],
    );
  }
}