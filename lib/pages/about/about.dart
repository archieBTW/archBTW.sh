import 'package:archbtw_sh/global/colors.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768.0;
    final EdgeInsets padding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 120.0, vertical: 48.0)
        : const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0);

    final baseStyle = TextStyle(
      color: kTextColor,
      fontSize: isDesktop ? 16 : 14,
      height: 1.6,
      fontFamily: 'JetBrainsMono',
    );

    const Color santaRed = Color(0xFFE53935);
    const Color santaWhite = Colors.white;

    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: const [
                    TextSpan(
                      text: " __________________\n"
                          "< hi. i'm archBTW. >\n"
                          " ------------------\n"
                          "       \\     ",
                    ),
                    TextSpan(
                      text: "*\n",
                      style: TextStyle(
                        color: santaWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: "        \\   "),
                    TextSpan(
                      text: "/.\\\n",
                      style: TextStyle(
                        color: santaRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: "         \\ "),
                    TextSpan(
                      text: "/...\\\n",
                      style: TextStyle(
                        color: santaRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: "          "),
                    TextSpan(
                      text: "(=====)\n",
                      style: TextStyle(
                        color: santaWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: "            ^__^\n"
                          "            (oo)\\_______\n"
                          "            (__)\\       )\\/\\\n"
                          "                ||----w |\n"
                          "                ||     ||\n\n\n"
                          "I started this project at the beginning of 2024 as a sort of musical diary. I've played guitar since I was a kid and started writing music in 5th grade. This continued into my later years, writing acoustic songs since I didn't have a band or know how to use music software. For several years, I was even a soundcloud rapper. As cringe as that was, it did teach me a lot about writing and using software so archBTW wouldn't exist without that experience.\n\n"
                          "archBTW has been my way of combining the emo confessionals I grew up with and the stream-of-consciousness hip hop that I fell in love with in my 20's. All wrapped in a bedroom-indie package. \n\n"
                          "I write and produce all of my music myself from the guitar and bass down to the synths and drums. I'm a huge fan of bandlab for this (it's way better and more capable than people think). I play a modded purple Harley Benton PRS-style guitar mainly but also have an SG, Tele, Mitchell acoustic, and occasionally borrow a strat. \n\n"
                          "All of the guitar sounds you hear come from various pedals (the main 2 being a fender amp simulator and a ts-808 clone) sometimes mixed with some digital effects depending on the song. \n\n"
                          "More background on me as a person:\n\n"
                          "My name is Archer and I live in Oklahoma City with my wife, dog, cat, and bearded dragon. When I'm not writing and making music, I'm working as a DevOps Engineer or coding on my personal projects. Before DevOps, I worked as a software developer and before that, as a systems administrator so DevOps has been a fun way to combine the two worlds.\n\n"
                          "Coding and music are huge passions of mine, but aside from those, I'm also a pretty big gearhead, a theology nerd, and a huge Linux fanboy.\n\n"
                          "Oh, I also have a mild obsession with Sanrio, specifically My Melody.\n\n"
                          "If you'd like to know more, click on the music tab. Like I said, it's pretty much my diary.\n\n"
                          "-archBTW\n\n",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
