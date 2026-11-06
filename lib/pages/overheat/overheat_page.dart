import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum OverheatPhase {
  overheating,
  announcement,
  fading,
  fireplace,
}

class OverheatPage extends StatefulWidget {
  const OverheatPage({super.key});

  @override
  State<OverheatPage> createState() => _OverheatPageState();
}

class _OverheatPageState extends State<OverheatPage>
    with SingleTickerProviderStateMixin {
  OverheatPhase _phase = OverheatPhase.overheating;

  // Timers
  Timer? _sequenceTimer;
  Timer? _shakeTimer;
  Timer? _logTimer;
  Timer? _fireTimer;
  Timer? _cursorTimer;

  // Phase 1: Overheating log simulation & meters
  final List<String> _overheatLogs = [
    "[    0.000000] ACPI: ACPI thermal trip points reached!",
    "[    0.041029] thermal thermal_zone0: critical temperature reached (105 C)",
    "[    0.108231] CPU0: Core temperature above threshold, cpu clock throttled!",
    "[    0.189442] coretemp: TCC activation temperature exceeded on CPU 0..7",
    "[    0.280194] cooling_device0: max cooling state 100% engaged (8500 RPM)",
    "[    0.391002] WARNING: HEAT DISSIPATION SATURATION DETECTED",
    "[    0.512998] ACPI: \\_TZ.THM0: CRITICAL THERMAL EVENT IN PROGRESS",
    "[    0.640129] KERNEL PANIC IMMINENT: CPU SILICON EXCEEDING SAFE LIMITS",
    "[    0.781290] TEMPERATURE RUNAWAY: +15°C/s [112°C -> 128°C -> 149°C]",
    "[    0.920194] EMERGENCY: COOLING SUB-SYSTEM FAILURE",
    "[    1.104291] SYSTEM OVERHEATING: HARDWARE THERMAL TRIP DETECTED!",
    "[    1.290112] CRITICAL: FLASHPOINT REACHED IN SYSTEM CORE",
  ];
  final List<String> _displayedLogs = [];
  int _logIndex = 0;
  int _temperature = 45;
  double _shakeX = 0;
  double _shakeY = 0;
  bool _redFlash = false;
  final ScrollController _logScrollController = ScrollController();

  // Phase 2: Announcement
  bool _showCursor = true;

  // Phase 3 & 4: Fade controller & Full-Screen ASCII Fire simulation
  late AnimationController _fadeController;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _fireplaceOpacityAnimation;

  final Random _rand = Random();

  // Full-screen dynamic fire grid
  int _heatCols = 0;
  int _heatRows = 0;
  List<List<int>> _heat = [];

  // Flame intensity (controlled via Up/Down arrows like fireplace-cli)
  int _flameHeight = 8; // Range 4..12

  static const List<String> _fireRamp = [
    ' ',
    '.',
    ':',
    '-',
    '=',
    '+',
    '*',
    '#',
    '%',
    '@',
  ];

  static const List<Color> _firePalette = [
    Colors.transparent,
    Color(0xFF3E1205), // dark smoky ember
    Color(0xFF6B1B0C), // dark crimson
    Color(0xFF9E2300), // deep red
    Color(0xFFC73600), // red-orange
    Color(0xFFE85400), // fiery orange
    Color(0xFFFF7A00), // bright flame orange
    Color(0xFFFFB300), // warm amber gold
    Color(0xFFFFEE58), // bright yellow
    Color(0xFFFFFFFF), // pure white-hot center
  ];

  @override
  void initState() {
    super.initState();

    // Animation controller for fading out announcement and fading in fireplace
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _textOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fireplaceOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _phase = OverheatPhase.fireplace;
          });
        }
      }
    });

    _startOverheatingSequence();
  }

  void _startOverheatingSequence() {
    // Shake timer
    _shakeTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      if (_phase == OverheatPhase.overheating) {
        setState(() {
          _shakeX = (_rand.nextDouble() * 6) - 3;
          _shakeY = (_rand.nextDouble() * 6) - 3;
          _redFlash = !_redFlash;
        });
      }
    });

    // Feed logs and increase temperature rapidly
    _logTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      if (_logIndex < _overheatLogs.length) {
        setState(() {
          _displayedLogs.add(_overheatLogs[_logIndex]);
          _logIndex++;
          _temperature = (_temperature + 12).clamp(45, 185);
        });
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      } else {
        timer.cancel();
      }
    });

    // After 3.5 seconds of overheating, transition to announcement
    _sequenceTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      _shakeTimer?.cancel();
      _logTimer?.cancel();
      setState(() {
        _phase = OverheatPhase.announcement;
        _shakeX = 0;
        _shakeY = 0;
      });

      // Cursor blinking for announcement (fixed position, no layout shift)
      _cursorTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
        if (!mounted) return;
        setState(() {
          _showCursor = !_showCursor;
        });
      });

      // Display announcement for 2.8 seconds, then start crossfade to fireplace
      _sequenceTimer = Timer(const Duration(milliseconds: 2800), () {
        if (!mounted) return;
        _cursorTimer?.cancel();
        _startFireplaceSimulation();
        setState(() {
          _phase = OverheatPhase.fading;
        });
        _fadeController.forward();
      });
    });
  }

  void _startFireplaceSimulation() {
    // Fire animation runs indefinitely at ~50ms (~20 FPS matching fireplace-cli)
    _fireTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      _updateFire();
      setState(() {});
    });
  }

  void _ensureGridSize(int cols, int rows) {
    if (_heatCols == cols && _heatRows == rows) return;
    _heatCols = cols;
    _heatRows = rows;
    _heat = List.generate(rows, (_) => List.filled(cols, 0));
  }

  void _updateFire() {
    if (_heatCols <= 0 || _heatRows <= 0 || _heat.isEmpty) return;

    // 1. Ignite bottom 2 rows with randomized fuel across the entire screen width
    for (int x = 0; x < _heatCols; x++) {
      if (_rand.nextDouble() < 0.88) {
        _heat[_heatRows - 1][x] = 9;
        _heat[_heatRows - 2][x] = 7 + _rand.nextInt(3);
      } else {
        _heat[_heatRows - 1][x] = 5 + _rand.nextInt(4);
        _heat[_heatRows - 2][x] = _rand.nextInt(5);
      }
    }

    // 2. Propagate upward (fireplace / aafire cellular automaton)
    // Dynamic decay rate influenced by _flameHeight
    final double decayProb = (14.0 - _flameHeight) / 10.0;

    for (int y = 0; y < _heatRows - 2; y++) {
      for (int x = 0; x < _heatCols; x++) {
        int decay = _rand.nextDouble() < decayProb ? 1 : 0;
        if (y < _heatRows * 0.45 && _rand.nextBool()) decay += 1;
        if (y < _heatRows * 0.25) decay += _rand.nextInt(2);

        int spread = _rand.nextInt(3) - 1; // -1, 0, or 1
        int srcX = (x + spread).clamp(0, _heatCols - 1);
        int srcY = min(_heatRows - 1, y + 1 + (_rand.nextDouble() < 0.2 ? 1 : 0));
        _heat[y][x] = max(0, _heat[srcY][srcX] - decay);
      }
    }
  }

  void _exit() {
    Navigator.of(context).pop();
  }

  void _adjustFlame(int delta) {
    setState(() {
      _flameHeight = (_flameHeight + delta).clamp(4, 12);
    });
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _shakeTimer?.cancel();
    _logTimer?.cancel();
    _fireTimer?.cancel();
    _cursorTimer?.cancel();
    _fadeController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.keyQ) {
            _exit();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.keyW) {
            _adjustFlame(1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.keyS) {
            _adjustFlame(-1);
          }
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // If in fireplace stage or fading stage, click anywhere exits
          if (_phase == OverheatPhase.fireplace || _phase == OverheatPhase.fading) {
            _exit();
          } else {
            // If user clicks during early overheating, skip directly to fireplace
            _skipToFireplace();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Content: overheating alert, announcement, or full-screen fire
              _buildCurrentPhaseContent(),

              // Subtle CRT red flash vignette during overheating
              if (_phase == OverheatPhase.overheating && _redFlash)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          Colors.transparent,
                          Colors.red.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                ),

              // Close button in top-right
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 24),
                  tooltip: "exit",
                  onPressed: _exit,
                ),
              ),

              // Instructions / status hint in fireplace mode
              if (_phase == OverheatPhase.fireplace || _phase == OverheatPhase.fading)
                Positioned(
                  top: 24,
                  left: 24,
                  child: IgnorePointer(
                    child: Text(
                      "[ click anywhere to exit ]",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _skipToFireplace() {
    _shakeTimer?.cancel();
    _logTimer?.cancel();
    _sequenceTimer?.cancel();
    _cursorTimer?.cancel();
    _shakeX = 0;
    _shakeY = 0;
    _startFireplaceSimulation();
    setState(() {
      _phase = OverheatPhase.fireplace;
    });
  }

  Widget _buildCurrentPhaseContent() {
    switch (_phase) {
      case OverheatPhase.overheating:
        return Transform.translate(
          offset: Offset(_shakeX, _shakeY),
          child: Center(child: _buildOverheatingView()),
        );
      case OverheatPhase.announcement:
        return Center(child: _buildAnnouncementText());
      case OverheatPhase.fading:
        return Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: _fireplaceOpacityAnimation,
              child: _buildFullScreenFire(),
            ),
            Center(
              child: FadeTransition(
                opacity: _textOpacityAnimation,
                child: _buildAnnouncementText(),
              ),
            ),
          ],
        );
      case OverheatPhase.fireplace:
        return _buildFullScreenFire();
    }
  }

  // --- Phase 1: Overheating Alert & Logs ---
  Widget _buildOverheatingView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final double logHeight =
            (constraints.maxHeight * 0.40).clamp(160.0, 280.0);

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 24.0,
              vertical: isMobile ? 16.0 : 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Warning Box
                Container(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    border: Border.all(
                      color: _redFlash ? Colors.redAccent : Colors.deepOrange,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: _redFlash
                                  ? Colors.redAccent
                                  : Colors.orangeAccent,
                              size: isMobile ? 22 : 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "SYSTEM OVERHEATING",
                              style: TextStyle(
                                color: _redFlash
                                    ? Colors.redAccent
                                    : Colors.orangeAccent,
                                fontFamily: 'JetBrainsMono',
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: isMobile ? 1.2 : 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "THERMAL RUNAWAY // TEMP: $_temperature°C // CRITICAL",
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'JetBrainsMono',
                            fontSize: isMobile ? 11 : 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Live Kernel Thermal Log Output
                Container(
                  height: logHeight,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    controller: _logScrollController,
                    itemCount: _displayedLogs.length,
                    itemBuilder: (context, index) {
                      final log = _displayedLogs[index];
                      final isCrit = log.contains("CRITICAL") ||
                          log.contains("OVERHEATING") ||
                          log.contains("PANIC") ||
                          log.contains("EMERGENCY");
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: isCrit ? Colors.redAccent : Colors.white70,
                            fontFamily: 'JetBrainsMono',
                            fontSize: isMobile ? 11 : 12,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Phase 2: Announcement ---
  // Symmetrical layout prevents any horizontal shifting when cursor blinks
  Widget _buildAnnouncementText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;
          final double fontSize = isDesktop ? 30 : 20;

          final textStyle = TextStyle(
            color: Colors.white,
            fontFamily: 'JetBrainsMono',
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            shadows: const [
              Shadow(color: Colors.white38, blurRadius: 20),
            ],
          );

          final cursorStyle = TextStyle(
            color: Colors.white,
            fontFamily: 'JetBrainsMono',
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          );

          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hidden dummy cursor on left to perfectly balance the right cursor
                Opacity(
                  opacity: 0.0,
                  child: Text("_", style: cursorStyle),
                ),
                Text(
                  "third-degree coming march 2027",
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                // Visible blinking cursor on right - Opacity changes paint only, zero layout change
                Opacity(
                  opacity: _showCursor ? 1.0 : 0.0,
                  child: Text("_", style: cursorStyle),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Phase 4: Full-Screen ASCII Fire (fireplace-cli aesthetic) ---
  Widget _buildFullScreenFire() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;

        // Responsive font sizing to densely fill the screen
        final double fontSize = width < 600 ? 10.0 : 13.0;
        final double charWidth = fontSize * 0.60;
        final double charHeight = fontSize * 1.15;

        final int cols = (width / charWidth).floor().clamp(30, 200);
        final int rows = (height / charHeight).floor().clamp(15, 90);

        _ensureGridSize(cols, rows);

        if (_heat.isEmpty || _heatRows != rows || _heatCols != cols) {
          return const SizedBox.expand();
        }

        // Build spans using Run-Length Encoding (RLE) for high performance
        final spans = <TextSpan>[];

        for (int y = 0; y < rows; y++) {
          int currentHeat = _heat[y][0].clamp(0, 9);
          int runCount = 0;

          for (int x = 0; x < cols; x++) {
            final int h = _heat[y][x].clamp(0, 9);
            if (h == currentHeat) {
              runCount++;
            } else {
              if (runCount > 0) {
                spans.add(
                  TextSpan(
                    text: _fireRamp[currentHeat] * runCount,
                    style: TextStyle(
                      color: _firePalette[currentHeat],
                      fontWeight:
                          currentHeat >= 7 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }
              currentHeat = h;
              runCount = 1;
            }
          }
          if (runCount > 0) {
            spans.add(
              TextSpan(
                text: _fireRamp[currentHeat] * runCount,
                style: TextStyle(
                  color: _firePalette[currentHeat],
                  fontWeight:
                      currentHeat >= 7 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }
          if (y < rows - 1) {
            spans.add(const TextSpan(text: '\n'));
          }
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: cols * charWidth,
            height: rows * charHeight,
            child: Text.rich(
              TextSpan(children: spans),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: fontSize,
                height: 1.15,
                letterSpacing: 0,
              ),
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      },
    );
  }
}
