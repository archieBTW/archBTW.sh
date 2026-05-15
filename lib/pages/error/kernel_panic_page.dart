import 'dart:async';
import 'dart:math';
import 'package:archbtw_sh/global/colors.dart';
import 'package:flutter/material.dart';

class KernelPanicPage extends StatefulWidget {
  const KernelPanicPage({super.key});

  @override
  State<KernelPanicPage> createState() => _KernelPanicPageState();
}

class _KernelPanicPageState extends State<KernelPanicPage> {
  final List<String> _lines = [];
  final ScrollController _scrollController = ScrollController();
  bool _isPanic = false;
  Timer? _timer;
  int _lineIndex = 0;

  final List<String> _panicLogs = [
    "[    0.000000] Linux version 6.8.0-archbtw (gcc version 13.2.1) #1 SMP PREEMPT_DYNAMIC",
    "[    0.000000] Command line: initrd=\\initramfs-linux.img root=PARTUUID=deadbeef-01 rw quiet",
    "[    0.000000] x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'",
    "[    0.000000] x86/fpu: Supporting XSAVE feature 0x002: 'SSE registers'",
    "[    0.000000] x86/fpu: Supporting XSAVE feature 0x004: 'AVX registers'",
    "[    0.000000] BIOS-e820: [mem 0x0000000000000000-0x000000000009ffff] usable",
    "[    0.000000] BIOS-e820: [mem 0x0000000000100000-0x00000000bfffffff] usable",
    "[    0.000001] NX (Execute Disable) protection: active",
    "[    0.000002] SMBIOS 3.5.0 present.",
    "[    0.000123] DMI: archBTW Virtual Machine/archBTW-VM, BIOS 1.16.2-1.fc38 04/01/2014",
    "[    0.001456] tsc: Fast TSC calibration failed",
    "[    0.012345] Calibrating delay loop... 5988.12 BogoMIPS (lpj=2994060)",
    "[    0.123456] devtmpfs: initialized",
    "[    0.234567] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 7645041785100000 ns",
    "[    0.345678] NET: Registered Data Link Protocol family 0",
    "[    0.456789] Storage device found: /dev/sda1 (ext4)",
    "[    0.567890] EXT4-fs (sda1): mounting root file system",
    "[    0.678901] EXT4-fs (sda1): ERROR: unexpected journal error -5",
    "[    0.789012] EXT4-fs (sda1): critical error: cannot read superblock",
    "[    0.890123] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)",
    "[    0.890124] CPU: 0 PID: 1 Comm: swapper/0 Not tainted 6.8.0-archbtw #1",
    "[    0.890125] Hardware name: archBTW Virtual Machine",
    "[    0.890126] Call Trace:",
    "[    0.890127]  <TASK>",
    "[    0.890128]  dump_stack_lvl+0x44/0x5c",
    "[    0.890129]  panic+0x10d/0x2ad",
    "[    0.890130]  mount_block_root+0x1a8/0x1b4",
    "[    0.890131]  mount_root+0x6e/0x81",
    "[    0.890132]  prepare_namespace+0x13b/0x182",
    "[    0.890133]  kernel_init_freeable+0x231/0x256",
    "[    0.890134]  ? rest_init+0xce/0xce",
    "[    0.890135]  kernel_init+0x17/0x130",
    "[    0.890136]  ret_from_fork+0x1f/0x30",
    "[    0.890137]  </TASK>",
    "[    0.890138] ---[ end Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0) ]---",
  ];

  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  void _startBootSequence() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_lineIndex < _panicLogs.length) {
        setState(() {
          _lines.add(_panicLogs[_lineIndex]);
          _lineIndex++;
          if (_panicLogs[_lineIndex - 1].contains("Kernel panic")) {
            _isPanic = true;
          }
        });
        _scrollToBottom();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The Log Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _lines.length + 1,
              itemBuilder: (context, index) {
                if (index == _lines.length) {
                  return _isPanic ? _buildRebootPrompt() : const SizedBox.shrink();
                }
                return Text(
                  _lines[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),

          // CRT Scanlines Effect
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
              child: _buildScanlines(),
            ),
          ),

          // Flickering overlay
          if (_isPanic)
            const IgnorePointer(
              child: FlickeringOverlay(),
            ),

          // Glitch Effect
          if (_isPanic)
            IgnorePointer(
              child: GlitchEffect(),
            ),
        ],
      ),
    );
  }

  Widget _buildScanlines() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: List.generate(
            (constraints.maxHeight / 3).floor(),
            (index) => Container(
              height: 1,
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRebootPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "\n[!] KERNEL PANIC: VFS: Unable to mount root fs",
            style: TextStyle(
              color: Colors.redAccent,
              fontFamily: 'JetBrainsMono',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "404 - SYSTEM ERROR\n------------------\nTHE REQUESTED PAGE DOES NOT EXIST IN THE CURRENT NAMESPACE.",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushReplacementNamed('/'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  color: Colors.transparent,
                ),
                child: const Text(
                  "REBOOT_SYSTEM_FORCE",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlitchEffect extends StatefulWidget {
  const GlitchEffect({super.key});

  @override
  State<GlitchEffect> createState() => _GlitchEffectState();
}

class _GlitchEffectState extends State<GlitchEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_random.nextDouble() > 0.1) return const SizedBox.shrink();
        
        return Stack(
          children: [
            Positioned(
              top: _random.nextDouble() * MediaQuery.of(context).size.height,
              left: 0,
              right: 0,
              child: Container(
                height: _random.nextDouble() * 20,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Positioned(
              left: _random.nextDouble() * MediaQuery.of(context).size.width,
              top: 0,
              bottom: 0,
              child: Container(
                width: _random.nextDouble() * 2,
                color: Colors.red.withOpacity(0.1),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FlickeringOverlay extends StatefulWidget {
  const FlickeringOverlay({super.key});

  @override
  State<FlickeringOverlay> createState() => _FlickeringOverlayState();
}

class _FlickeringOverlayState extends State<FlickeringOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: Colors.red.withOpacity(_random.nextDouble() * 0.03),
        );
      },
    );
  }
}
