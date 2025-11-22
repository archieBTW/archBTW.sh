import 'package:archbtw_sh/global/colors.dart';
import 'package:archbtw_sh/pages/about/about.dart';
import 'package:archbtw_sh/pages/home/home_page.dart';
import 'package:archbtw_sh/pages/merch/merch__page.dart';
import 'package:archbtw_sh/pages/music/music_page.dart';
import 'package:archbtw_sh/widgets/header.dart';
import 'package:flutter/material.dart';

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
          bodyMedium: TextStyle(color: kTextColor, fontSize: 16, fontFamily: 'JetBrainsMono', ),
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

  final List<Widget> _screens = [
    const HomePage(),
    const AboutPage(),
    const MusicPage(),
    const MerchPage(),
  ];

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
                children: _screens,
              ),
            ),
          ],
        ),
    );
  }
}

