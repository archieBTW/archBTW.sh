import 'dart:async';

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/about/about.dart';
import 'package:archbtw_sh/pages/error/kernel_panic_page.dart';
import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:archbtw_sh/pages/merch/merch__page.dart';
import 'package:archbtw_sh/pages/music/music_page.dart';
import 'package:archbtw_sh/widgets/header.dart';
import 'package:archbtw_sh/widgets/loading_waveform.dart';
import 'package:archbtw_sh/pages/source_code/source_code_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart'
    if (dart.library.io) 'package:archbtw_sh/global/noop_url_strategy.dart';

void main() {
  usePathUrlStrategy();
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
          bodyMedium: TextStyle(
            color: kTextColor,
            fontSize: 16,
            fontFamily: 'JetBrainsMono',
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          );
        } else if (settings.name == '/source') {
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const SourceCodePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          );
        }
        return MaterialPageRoute(builder: (context) => const KernelPanicPage());
      },
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
  bool _loadAbout = false;
  bool _loadMusic = false;
  bool _loadMerch = false;

  final Widget _homePage = const RepaintBoundary(child: HomePage());

  @override
  void initState() {
    super.initState();
    _startStaggeredLoading();
  }

  Future<void> _startStaggeredLoading() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    setState(() => _loadAbout = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _loadMusic = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
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
          Header(currentIndex: _currentIndex, onItemTapped: _onItemTapped),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _homePage,
                _loadAbout
                    ? const AboutPage()
                    : const Center(child: WaveformLoader()),
                _loadMusic
                    ? const MusicPage()
                    : const Center(child: WaveformLoader()),
                _loadMerch
                    ? const MerchPage()
                    : const Center(child: WaveformLoader()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
