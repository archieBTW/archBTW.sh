import 'dart:async';

import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/about/about.dart';
import 'package:archbtw_sh/pages/error/kernel_panic_page.dart';
import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:archbtw_sh/pages/merch/merch__page.dart';
import 'package:archbtw_sh/pages/music/album_item_list.dart';
import 'package:archbtw_sh/pages/music/music_page.dart';
import 'package:archbtw_sh/pages/overheat/overheat_page.dart';
import 'package:archbtw_sh/widgets/floating_music_toast.dart';
import 'package:archbtw_sh/widgets/header.dart';
import 'package:archbtw_sh/widgets/holiday_snow_overlay.dart';
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
      builder: (context, child) {
        return Stack(
          children: [if (child != null) child, const FloatingMusicToast()],
        );
      },
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
        } else if (settings.name == '/overheat' ||
            settings.name == '/third-degree') {
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const OverheatPage(),
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
  bool _didPrecache = false;

  Timer? _staggerTimer1;
  Timer? _staggerTimer2;
  Timer? _staggerTimer3;

  final Widget _homePage = const RepaintBoundary(child: HomePage());
  final Widget _aboutPage = const RepaintBoundary(child: AboutPage());
  final Widget _musicPage = const RepaintBoundary(child: MusicPage());
  final Widget _merchPage = const RepaintBoundary(child: MerchPage());
  final Widget _snowOverlay = const Positioned.fill(
    child: HolidaySnowOverlay(),
  );

  @override
  void initState() {
    super.initState();
    _startStaggeredLoading();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      for (final item in albumItems) {
        precacheImage(AssetImage(item.coverUrl), context);
      }
    }
  }

  void _startStaggeredLoading() {
    _staggerTimer1 = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _loadAbout = true);
    });
    _staggerTimer2 = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _loadMusic = true);
    });
    _staggerTimer3 = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _loadMerch = true);
    });
  }

  @override
  void dispose() {
    _staggerTimer1?.cancel();
    _staggerTimer2?.cancel();
    _staggerTimer3?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 1) {
        _loadAbout = true;
        _staggerTimer1?.cancel();
      }
      if (index == 2) {
        _loadMusic = true;
        _staggerTimer2?.cancel();
      }
      if (index == 3) {
        _loadMerch = true;
        _staggerTimer3?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Header(currentIndex: _currentIndex, onItemTapped: _onItemTapped),
              Expanded(
                child: RepaintBoundary(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _homePage,
                      _loadAbout
                          ? _aboutPage
                          : const Center(child: WaveformLoader()),
                      _loadMusic
                          ? _musicPage
                          : const Center(child: WaveformLoader()),
                      _loadMerch
                          ? _merchPage
                          : const Center(child: WaveformLoader()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _snowOverlay,
        ],
      ),
    );
  }
}
