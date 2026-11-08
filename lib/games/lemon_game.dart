import 'dart:async';
import 'dart:math';
import 'package:archbtw_sh/global/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

enum LemonItemType {
  lemon,
  crosstopPill,
  elixirPotion,
  blueCandle,
  coffeeCup,
  cherrySeven,
}

extension LemonItemTypeMeta on LemonItemType {
  Color get themeColor {
    switch (this) {
      case LemonItemType.lemon:
        return const Color(0xFFFACC15);
      case LemonItemType.crosstopPill:
        return const Color(0xFFEF4444);
      case LemonItemType.elixirPotion:
        return const Color(0xFFA855F7);
      case LemonItemType.blueCandle:
        return const Color(0xFF38BDF8);
      case LemonItemType.coffeeCup:
        return const Color(0xFFD97706);
      case LemonItemType.cherrySeven:
        return const Color(0xFFEC4899);
    }
  }

  String get label {
    switch (this) {
      case LemonItemType.lemon:
        return 'LEMON';
      case LemonItemType.crosstopPill:
        return 'CROSSTOP';
      case LemonItemType.elixirPotion:
        return 'ELIXIR';
      case LemonItemType.blueCandle:
        return 'CANDLEWAX';
      case LemonItemType.coffeeCup:
        return 'COLOMBIAN';
      case LemonItemType.cherrySeven:
        return 'CHERRY 7';
    }
  }
}

class Pill {
  final LemonItemType type;
  final String id;

  Pill(this.type) : id = UniqueKey().toString();

  Color get color => type.themeColor;
}

class LemonsGame extends StatefulWidget {
  const LemonsGame({super.key});

  @override
  State<LemonsGame> createState() => _LemonsGameState();
}

class _LemonsGameState extends State<LemonsGame> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _playlist = [
    'almost_intelligent.wav',
    'crosstops.wav',
    'c_u_next_tuesday.wav',
    'drinking_outta_cups.wav',
    'elixir.wav',
    'florence.wav',
    'it_seemed_like_a_good_idea_at_the_time.wav',
    'you_call_this_mercy.wav',
    'midnight_oil.wav',
    'i_may_not_be_a_smart_man_but_i_know_what_love_is.wav',
    'lets_take_it_apart_and_put_it_back_together.wav',
    'and_thats_how_it_happened.wav',
    'third_times_a_charm.wav',
  ];

  List<String> _musicQueue = [];
  StreamSubscription? _playerCompleteSubscription;

  final int _rows = 8;
  final int _cols = 5;

  final List<LemonItemType> _itemTypes = LemonItemType.values;

  late List<List<Pill?>> _grid;
  Point<int>? _selectedPoint;

  int _score = 0;
  bool _isWon = false;
  bool _isGameOver = false;
  bool _isProcessing = false;

  Timer? _gameTimer;
  int _secondsRemaining = 180;

  @override
  void initState() {
    super.initState();
    _initGrid(resetScore: true);
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.release);

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
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
      final fullPath = 'music/lemons/$nextSong';
      await _audioPlayer.setSource(AssetSource(fullPath));
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Audio Error: $e');
    }
  }

  Future<void> _cleanupStragglers() async {
    final Map<LemonItemType, int> typeCounts = {};
    for (final row in _grid) {
      for (final item in row) {
        if (item != null) {
          typeCounts[item.type] = (typeCounts[item.type] ?? 0) + 1;
        }
      }
    }

    final List<LemonItemType> doomedTypes = [];
    typeCounts.forEach((type, count) {
      if (count > 0 && count < 3) {
        doomedTypes.add(type);
      }
    });

    if (doomedTypes.isEmpty) return;

    bool changed = false;
    setState(() {
      for (int y = 0; y < _rows; y++) {
        for (int x = 0; x < _cols; x++) {
          final item = _grid[y][x];
          if (item != null && doomedTypes.contains(item.type)) {
            _grid[y][x] = null;
            _score += 5;
            changed = true;
          }
        }
      }
    });

    if (changed) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _applyGravity();
      await _resolveMatches();
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
    final rng = Random();
    _grid = List.generate(_rows, (_) => List<Pill?>.filled(_cols, null));

    for (int y = 0; y < _rows; y++) {
      for (int x = 0; x < _cols; x++) {
        LemonItemType proposedType;
        do {
          proposedType = _itemTypes[rng.nextInt(_itemTypes.length)];
        } while (!_isMatchSafe(_grid, x, y, proposedType, isTopDown: true));

        _grid[y][x] = Pill(proposedType);
      }
    }

    setState(() {
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

    final List<Pill> availableItems = [];
    for (final row in _grid) {
      for (final item in row) {
        if (item != null) availableItems.add(item);
      }
    }
    availableItems.shuffle();

    final List<List<Pill?>> newGrid = List.generate(
      _rows,
      (_) => List<Pill?>.filled(_cols, null),
    );

    int itemIndex = 0;

    for (int y = _rows - 1; y >= 0; y--) {
      for (int x = 0; x < _cols; x++) {
        if (itemIndex >= availableItems.length) break;

        int foundIndex = -1;

        for (int k = itemIndex; k < availableItems.length; k++) {
          if (_isMatchSafe(
            newGrid,
            x,
            y,
            availableItems[k].type,
            isTopDown: false,
          )) {
            foundIndex = k;
            break;
          }
        }

        if (foundIndex != -1) {
          final temp = availableItems[itemIndex];
          availableItems[itemIndex] = availableItems[foundIndex];
          availableItems[foundIndex] = temp;
        }

        newGrid[y][x] = availableItems[itemIndex];
        itemIndex++;
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

  bool _isMatchSafe(
    List<List<Pill?>> tempGrid,
    int x,
    int y,
    LemonItemType type, {
    required bool isTopDown,
  }) {
    if (x >= 2) {
      if (tempGrid[y][x - 1]?.type == type &&
          tempGrid[y][x - 2]?.type == type) {
        return false;
      }
    }

    if (isTopDown) {
      if (y >= 2) {
        if (tempGrid[y - 1][x]?.type == type &&
            tempGrid[y - 2][x]?.type == type) {
          return false;
        }
      }

      if (x >= 2 && y >= 2) {
        if (tempGrid[y - 1][x - 1]?.type == type &&
            tempGrid[y - 2][x - 2]?.type == type) {
          return false;
        }
      }
      if (x <= _cols - 3 && y >= 2) {
        if (tempGrid[y - 1][x + 1]?.type == type &&
            tempGrid[y - 2][x + 2]?.type == type) {
          return false;
        }
      }
    } else {
      if (y <= _rows - 3) {
        if (tempGrid[y + 1][x]?.type == type &&
            tempGrid[y + 2][x]?.type == type) {
          return false;
        }
      }

      if (x >= 2 && y <= _rows - 3) {
        if (tempGrid[y + 1][x - 1]?.type == type &&
            tempGrid[y + 2][x - 2]?.type == type) {
          return false;
        }
      }

      if (x <= _cols - 3 && y <= _rows - 3) {
        if (tempGrid[y + 1][x + 1]?.type == type &&
            tempGrid[y + 2][x + 2]?.type == type) {
          return false;
        }
      }
    }

    return true;
  }

  void _handleTap(int x, int y) {
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

    await Future.delayed(const Duration(milliseconds: 300));

    final bool hasMatch = await _resolveMatches();

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

  Future<bool> _resolveMatches({bool initial = false}) async {
    final Set<Point<int>> matchedPoints = {};

    LemonItemType? getType(int x, int y) => _grid[y][x]?.type;

    for (int y = 0; y < _rows; y++) {
      for (int x = 0; x < _cols - 2; x++) {
        final t = getType(x, y);
        if (t == null) continue;
        if (getType(x + 1, y) == t && getType(x + 2, y) == t) {
          matchedPoints.addAll([Point(x, y), Point(x + 1, y), Point(x + 2, y)]);
          int k = x + 3;
          while (k < _cols && getType(k, y) == t) {
            matchedPoints.add(Point(k, y));
            k++;
          }
        }
      }
    }

    for (int x = 0; x < _cols; x++) {
      for (int y = 0; y < _rows - 2; y++) {
        final t = getType(x, y);
        if (t == null) continue;
        if (getType(x, y + 1) == t && getType(x, y + 2) == t) {
          matchedPoints.addAll([Point(x, y), Point(x, y + 1), Point(x, y + 2)]);
          int k = y + 3;
          while (k < _rows && getType(x, k) == t) {
            matchedPoints.add(Point(x, k));
            k++;
          }
        }
      }
    }

    for (int y = 0; y < _rows - 2; y++) {
      for (int x = 0; x < _cols - 2; x++) {
        final t = getType(x, y);
        if (t == null) continue;
        if (getType(x + 1, y + 1) == t && getType(x + 2, y + 2) == t) {
          matchedPoints.addAll([
            Point(x, y),
            Point(x + 1, y + 1),
            Point(x + 2, y + 2),
          ]);
          int k = 3;
          while (y + k < _rows &&
              x + k < _cols &&
              getType(x + k, y + k) == t) {
            matchedPoints.add(Point(x + k, y + k));
            k++;
          }
        }
      }
    }

    for (int y = 0; y < _rows - 2; y++) {
      for (int x = 2; x < _cols; x++) {
        final t = getType(x, y);
        if (t == null) continue;
        if (getType(x - 1, y + 1) == t && getType(x - 2, y + 2) == t) {
          matchedPoints.addAll([
            Point(x, y),
            Point(x - 1, y + 1),
            Point(x - 2, y + 2),
          ]);
          int k = 3;
          while (y + k < _rows && x - k >= 0 && getType(x - k, y + k) == t) {
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
            for (final p in matchedPoints) {
              _grid[p.y][p.x] = null;
            }
            _score += matchedPoints.length * 10;
          });
        }
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        for (final p in matchedPoints) {
          _grid[p.y][p.x] = null;
        }
      }

      await _applyGravity();
      await _resolveMatches(initial: initial);
      return true;
    }

    if (!initial) {
      await _cleanupStragglers();
      _checkWinCondition();
    }

    if (!initial && mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
    return false;
  }

  void _checkWinCondition() {
    bool isEmpty = true;
    for (final row in _grid) {
      for (final item in row) {
        if (item != null) {
          isEmpty = false;
          break;
        }
      }
    }
    if (isEmpty && !_isWon) {
      setState(() {
        _isWon = true;
        _gameTimer?.cancel();
      });
    }
  }

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
    }
    if (moved && mounted) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  String get _timerString {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1021),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B17),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kAccentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isWon
              ? 'NO MORE MELANCHOLY'
              : (_isGameOver ? 'TIMEOUT' : _timerString),
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            color: _isWon
                ? const Color(0xFFFACC15)
                : (_isGameOver ? Colors.red : kAccentColor),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  'SCORE: $_score',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (!_isWon && !_isGameOver)
          ? FloatingActionButton(
              tooltip: 'Shuffle Board',
              onPressed: _shuffleGrid,
              backgroundColor: const Color(0xFFFACC15),
              child: const Icon(Icons.shuffle, color: Colors.black),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
              Color(0xFF060913),
            ],
          ),
        ),
        child: Stack(
          children: [
            if (_isWon) _buildWinScreen(),
            if (_isGameOver && !_isWon) _buildLoseScreen(),
            if (!_isWon && !_isGameOver) _buildGameLayout(),
          ],
        ),
      ),
    );
  }

  Widget _buildWinScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFACC15), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFACC15).withValues(alpha: 0.25),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 90,
              height: 90,
              child: CustomPaint(
                painter: _LemonItemPainter(type: LemonItemType.lemon),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "LIFE'S LEMONS CLEARED!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                color: Color(0xFFFACC15),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
              ),
              onPressed: () => _initGrid(resetScore: false),
              child: const Text(
                'squeeze another batch',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoseScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.redAccent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 76),
            const SizedBox(height: 20),
            const Text(
              'CONNECTION TIMED OUT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
              ),
              onPressed: () => _initGrid(resetScore: true),
              child: const Text(
                'retry',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth - 20;
        final double maxHeight = constraints.maxHeight - 20;

        double cellSize = maxWidth / _cols;
        if (cellSize * _rows > maxHeight) {
          cellSize = maxHeight / _rows;
        }

        final double boardWidth = cellSize * _cols;
        final double boardHeight = cellSize * _rows;
        final double xOffset = (constraints.maxWidth - boardWidth) / 2;
        final double yOffset = (constraints.maxHeight - boardHeight) / 2;

        final List<Widget> gridWidgets = [
          // Cartoon Board Frame
          Positioned(
            left: xOffset - 6,
            top: yOffset - 6,
            width: boardWidth + 12,
            height: boardHeight + 12,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090D1A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ];

        for (int y = 0; y < _rows; y++) {
          for (int x = 0; x < _cols; x++) {
            gridWidgets.add(
              Positioned(
                left: xOffset + (x * cellSize),
                top: yOffset + (y * cellSize),
                width: cellSize,
                height: cellSize,
                child: Container(
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.45),
                    border: Border.all(color: Colors.white12, width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _handleTap(x, y),
                  ),
                ),
              ),
            );
          }
        }

        for (int y = 0; y < _rows; y++) {
          for (int x = 0; x < _cols; x++) {
            final item = _grid[y][x];
            if (item == null) continue;

            gridWidgets.add(
              AnimatedPositioned(
                key: Key(item.id),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutBack,
                left: xOffset + (x * cellSize),
                top: yOffset + (y * cellSize),
                width: cellSize,
                height: cellSize,
                child: IgnorePointer(
                  child: _buildCartoonItemCell(x, y, cellSize, item),
                ),
              ),
            );
          }
        }

        return Stack(children: gridWidgets);
      },
    );
  }

  Widget _buildCartoonItemCell(int x, int y, double size, Pill item) {
    final bool isSelected =
        _selectedPoint != null &&
        _selectedPoint!.x == x &&
        _selectedPoint!.y == y;
    final Color baseColor = item.color;

    return Center(
      child: AnimatedScale(
        scale: isSelected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: SizedBox(
          width: size * 0.90,
          height: size * 0.90,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.35),
                radius: 1.0,
                colors: [
                  Color.lerp(baseColor, Colors.white, 0.32)!,
                  baseColor.withValues(alpha: 0.85),
                  Color.lerp(baseColor, Colors.black, 0.45)!,
                ],
              ),
              borderRadius: BorderRadius.circular(size * 0.24),
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                width: isSelected ? 3.2 : 2.2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.85),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  offset: const Offset(0, 3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.11),
              child: CustomPaint(
                painter: _LemonItemPainter(type: item.type),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LemonItemPainter extends CustomPainter {
  final LemonItemType type;

  const _LemonItemPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = min(size.width, size.height) * 0.46;

    final Paint outline = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.11).clamp(1.6, 3.0)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case LemonItemType.lemon:
        // "No more melancholy, only life's lemons"
        // Detailed cartoon lemon with tips, green leaf, and glossy shine
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-0.35);

        final Path lemonBody = Path()
          ..moveTo(-r * 1.05, 0)
          ..quadraticBezierTo(-r * 0.75, -r * 0.78, 0, -r * 0.72)
          ..quadraticBezierTo(r * 0.75, -r * 0.78, r * 1.05, 0)
          ..quadraticBezierTo(r * 0.75, r * 0.78, 0, r * 0.72)
          ..quadraticBezierTo(-r * 0.75, r * 0.78, -r * 1.05, 0)
          ..close();

        canvas.drawPath(
          lemonBody,
          Paint()..color = const Color(0xFFFDE047),
        );
        // Bottom shading arc
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(0, r * 0.1),
            width: r * 1.6,
            height: r * 1.0,
          ),
          0.1,
          pi - 0.2,
          false,
          Paint()..color = const Color(0xFFEAB308),
        );
        canvas.drawPath(lemonBody, outline);

        // Specular highlight
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(-r * 0.15, -r * 0.22),
            width: r * 1.1,
            height: r * 0.5,
          ),
          pi + 0.3,
          1.4,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..strokeCap = StrokeCap.round,
        );

        // Green citrus leaf on top
        final Path leaf = Path()
          ..moveTo(-r * 0.2, -r * 0.68)
          ..quadraticBezierTo(-r * 0.05, -r * 1.25, r * 0.55, -r * 1.05)
          ..quadraticBezierTo(r * 0.25, -r * 0.62, -r * 0.2, -r * 0.68)
          ..close();
        canvas.drawPath(leaf, Paint()..color = const Color(0xFF22C55E));
        canvas.drawPath(leaf, outline);
        canvas.restore();
        break;

      case LemonItemType.crosstopPill:
        // "[crosstops] Pill pop in peace"
        // Cartoon two-tone capsule + white scored crosstop tablet
        canvas.save();
        canvas.translate(c.dx - r * 0.18, c.dy - r * 0.12);
        canvas.rotate(-0.55);
        final RRect topHalf = RRect.fromRectAndCorners(
          Rect.fromLTWH(-r * 0.42, -r * 0.78, r * 0.84, r * 0.78),
          topLeft: Radius.circular(r * 0.42),
          topRight: Radius.circular(r * 0.42),
        );
        final RRect bottomHalf = RRect.fromRectAndCorners(
          Rect.fromLTWH(-r * 0.42, 0, r * 0.84, r * 0.78),
          bottomLeft: Radius.circular(r * 0.42),
          bottomRight: Radius.circular(r * 0.42),
        );
        canvas.drawRRect(topHalf, Paint()..color = const Color(0xFFEF4444));
        canvas.drawRRect(bottomHalf, Paint()..color = Colors.white);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: r * 0.84,
              height: r * 1.56,
            ),
            Radius.circular(r * 0.42),
          ),
          outline,
        );
        canvas.drawLine(
          Offset(-r * 0.42, 0),
          Offset(r * 0.42, 0),
          outline,
        );
        canvas.restore();

        // Foreground crosstop tablet with '+' score lines
        final Offset tabCenter = c + Offset(r * 0.32, r * 0.28);
        canvas.drawCircle(
          tabCenter,
          r * 0.52,
          Paint()..color = const Color(0xFFF8FAFC),
        );
        canvas.drawCircle(tabCenter, r * 0.52, outline);
        canvas.drawLine(
          tabCenter + Offset(-r * 0.32, 0),
          tabCenter + Offset(r * 0.32, 0),
          outline,
        );
        canvas.drawLine(
          tabCenter + Offset(0, -r * 0.32),
          tabCenter + Offset(0, r * 0.32),
          outline,
        );
        break;

      case LemonItemType.elixirPotion:
        // "[elixir] A violent, greedy alchemist. Amethyst, channeling"
        // Bubbling amethyst potion flask with cork stopper
        final Path cork = Path()
          ..moveTo(c.dx - r * 0.22, c.dy - r * 0.78)
          ..lineTo(c.dx - r * 0.28, c.dy - r * 1.05)
          ..lineTo(c.dx + r * 0.28, c.dy - r * 1.05)
          ..lineTo(c.dx + r * 0.22, c.dy - r * 0.78)
          ..close();
        canvas.drawPath(cork, Paint()..color = const Color(0xFFB45309));
        canvas.drawPath(cork, outline);

        // Glass neck
        canvas.drawRect(
          Rect.fromCenter(
            center: c + Offset(0, -r * 0.62),
            width: r * 0.46,
            height: r * 0.36,
          ),
          Paint()..color = const Color(0xFFE0E7FF),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: c + Offset(0, -r * 0.62),
            width: r * 0.46,
            height: r * 0.36,
          ),
          outline,
        );

        // Bulbous flask body
        final Offset bulbCenter = c + Offset(0, r * 0.16);
        canvas.drawCircle(
          bulbCenter,
          r * 0.74,
          Paint()..color = const Color(0xFFDDD6FE),
        );
        // Glowing purple elixir liquid inside
        canvas.drawArc(
          Rect.fromCircle(center: bulbCenter, radius: r * 0.65),
          -0.2,
          pi + 0.4,
          true,
          Paint()..color = const Color(0xFF9333EA),
        );
        // Magic bubbles
        canvas.drawCircle(
          bulbCenter + Offset(-r * 0.22, r * 0.12),
          r * 0.12,
          Paint()..color = const Color(0xFFF0ABFC),
        );
        canvas.drawCircle(
          bulbCenter + Offset(r * 0.18, -r * 0.08),
          r * 0.09,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(bulbCenter, r * 0.74, outline);
        break;

      case LemonItemType.blueCandle:
        // "Blue candle wax drips onto bolded yellow letters" / "Mirtazipine and candlewax"
        final RRect candleBody = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c + Offset(0, r * 0.24),
            width: r * 0.92,
            height: r * 1.18,
          ),
          Radius.circular(r * 0.16),
        );
        canvas.drawRRect(
          candleBody,
          Paint()..color = const Color(0xFF0284C7),
        );
        canvas.drawRRect(candleBody, outline);

        // Dripping blue wax down the candle front
        final Path waxDrips = Path()
          ..moveTo(c.dx - r * 0.46, c.dy - r * 0.32)
          ..quadraticBezierTo(
            c.dx - r * 0.25,
            c.dy + r * 0.22,
            c.dx - r * 0.12,
            c.dy - r * 0.15,
          )
          ..quadraticBezierTo(
            c.dx + r * 0.08,
            c.dy + r * 0.38,
            c.dx + r * 0.22,
            c.dy - r * 0.12,
          )
          ..quadraticBezierTo(
            c.dx + r * 0.36,
            c.dy + r * 0.12,
            c.dx + r * 0.46,
            c.dy - r * 0.32,
          )
          ..close();
        canvas.drawPath(waxDrips, Paint()..color = const Color(0xFF7DD3FC));
        canvas.drawPath(waxDrips, outline);

        // Wick & Butane/Candle Flame
        canvas.drawLine(
          c + Offset(0, -r * 0.35),
          c + Offset(0, -r * 0.52),
          outline,
        );
        final Path outerFlame = Path()
          ..moveTo(c.dx, c.dy - r * 1.08)
          ..quadraticBezierTo(
            c.dx + r * 0.38,
            c.dy - r * 0.65,
            c.dx,
            c.dy - r * 0.48,
          )
          ..quadraticBezierTo(
            c.dx - r * 0.38,
            c.dy - r * 0.65,
            c.dx,
            c.dy - r * 1.08,
          )
          ..close();
        canvas.drawPath(outerFlame, Paint()..color = const Color(0xFFF97316));
        canvas.drawPath(outerFlame, outline);
        canvas.drawCircle(
          c + Offset(0, -r * 0.68),
          r * 0.14,
          Paint()..color = const Color(0xFFFEF08A),
        );
        break;

      case LemonItemType.coffeeCup:
        // "10th cup of Colombian" / "drinking outta cups"
        // Cup handle
        canvas.drawArc(
          Rect.fromCenter(
            center: c + Offset(r * 0.52, r * 0.12),
            width: r * 0.62,
            height: r * 0.68,
          ),
          -pi / 2,
          pi,
          false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.18,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: c + Offset(r * 0.52, r * 0.12),
            width: r * 0.62,
            height: r * 0.68,
          ),
          -pi / 2,
          pi,
          false,
          outline,
        );

        // Mug body
        final RRect mug = RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: c + Offset(-r * 0.08, r * 0.16),
            width: r * 1.15,
            height: r * 1.08,
          ),
          bottomLeft: Radius.circular(r * 0.45),
          bottomRight: Radius.circular(r * 0.45),
          topLeft: Radius.circular(r * 0.1),
          topRight: Radius.circular(r * 0.1),
        );
        canvas.drawRRect(mug, Paint()..color = const Color(0xFFFFFBEB));
        canvas.drawRRect(mug, outline);

        // Dark Colombian coffee surface
        canvas.drawOval(
          Rect.fromCenter(
            center: c + Offset(-r * 0.08, -r * 0.34),
            width: r * 1.12,
            height: r * 0.34,
          ),
          Paint()..color = const Color(0xFF451A03),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: c + Offset(-r * 0.08, -r * 0.34),
            width: r * 1.12,
            height: r * 0.34,
          ),
          outline,
        );

        // Rising steam curls
        final Paint steamPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..strokeCap = StrokeCap.round;
        for (int s = -1; s <= 1; s += 2) {
          final double sx = c.dx - r * 0.08 + s * r * 0.24;
          final Path steam = Path()
            ..moveTo(sx, c.dy - r * 0.55)
            ..quadraticBezierTo(
              sx + s * r * 0.14,
              c.dy - r * 0.78,
              sx - s * r * 0.06,
              c.dy - r * 0.98,
            );
          canvas.drawPath(steam, steamPaint);
        }
        break;

      case LemonItemType.cherrySeven:
        // "The sevens are repetitive. Cherry on top of cherry-flavored sedatives."
        final Offset leftCherry = c + Offset(-r * 0.42, r * 0.38);
        final Offset rightCherry = c + Offset(r * 0.42, r * 0.38);
        final Offset stemTop = c + Offset(0, -r * 0.88);

        // Green arched cherry stems
        final Path stems = Path()
          ..moveTo(leftCherry.dx, leftCherry.dy - r * 0.2)
          ..quadraticBezierTo(
            c.dx - r * 0.35,
            c.dy - r * 0.45,
            stemTop.dx,
            stemTop.dy,
          )
          ..quadraticBezierTo(
            c.dx + r * 0.35,
            c.dy - r * 0.45,
            rightCherry.dx,
            rightCherry.dy - r * 0.2,
          );
        canvas.drawPath(
          stems,
          Paint()
            ..color = const Color(0xFF16A34A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..strokeCap = StrokeCap.round,
        );

        // Twin glossy cartoon cherries
        for (final pos in [leftCherry, rightCherry]) {
          canvas.drawCircle(
            pos,
            r * 0.44,
            Paint()..color = const Color(0xFFE11D48),
          );
          canvas.drawCircle(pos, r * 0.44, outline);
          canvas.drawCircle(
            pos + Offset(-r * 0.14, -r * 0.14),
            r * 0.12,
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        }

        // Golden Lucky '7' badge in the center
        final TextPainter sevenTp = TextPainter(
          text: TextSpan(
            text: '7',
            style: TextStyle(
              color: const Color(0xFFFACC15),
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w900,
              fontSize: r * 1.05,
              shadows: const [
                Shadow(
                  color: Color(0xFF0F172A),
                  offset: Offset(1.5, 1.5),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        sevenTp.paint(
          canvas,
          c - Offset(sevenTp.width / 2, sevenTp.height * 0.72),
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LemonItemPainter oldDelegate) =>
      oldDelegate.type != type;
}
