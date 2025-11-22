import 'dart:async';

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/about/about.dart';
import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:archbtw_sh/pages/merch/merch__page.dart';
import 'package:archbtw_sh/pages/music/music_page.dart';
import 'package:archbtw_sh/widgets/header.dart';
import 'package:archbtw_sh/widgets/loading_waveform.dart';
import 'package:archbtw_sh/widgets/social_icons.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  runApp(const ArchWebsite());
}

class ArchWebsite extends StatelessWidget {
  const ArchWebsite({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'archBTW.',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'JetBrainsMono',
        scaffoldBackgroundColor: kBackgroundColor,
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: kTextColor, fontSize: 16, fontFamily: 'JetBrainsMono'),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Individual loading states for the Staggered/Cascade load
  bool _loadAbout = false;
  bool _loadMusic = false;
  bool _loadMerch = false;

  // Constant instance of HomePage
  final Widget _homePage = const RepaintBoundary(child: HomePage());

  @override
  void initState() {
    super.initState();
    _startStaggeredLoading();
  }

  Future<void> _startStaggeredLoading() async {
    // 1. Wait the initial 2.8 seconds
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    // 2. Load About Page
    setState(() => _loadAbout = true);

    // 3. Wait a small breath (200ms) so the UI thread can breathe 
    // and render the next frame of your typing animation
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // 4. Load Music Page
    setState(() => _loadMusic = true);

    // 5. Wait another small breath
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // 6. Load Merch Page
    setState(() => _loadMerch = true);
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Header(
            currentIndex: _currentIndex,
            onItemTapped: _onItemTapped,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                // Index 0: Home (Always loaded)
                _homePage,

                // Index 1: About (Loads at 2.8s)
                _loadAbout ? const AboutPage() : const Center(child: WaveformLoader()),

                // Index 2: Music (Loads at ~3.0s)
                _loadMusic ? const MusicPage() : const Center(child: WaveformLoader()),

                // Index 3: Merch (Loads at ~3.2s)
                _loadMerch ? const MerchPage() : const Center(child: WaveformLoader()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

