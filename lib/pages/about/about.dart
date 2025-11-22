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

    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Max width for readability
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                """
 __________________
< hi. i'm archBTW. >
 ------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
              ||----w |
              ||     ||


I started this project at the beginning of 2024 as a sort of musical diary. I've played guitar since I was a kid and started writing music in 5th grade. This continued into my later years, writing acoustic songs since I didn't have a band or know how to use music software. For several years, I was even a soundcloud rapper. As cringe as that was, it did teach me a lot about writing and using software so archBTW wouldn't exist without that experience.

archBTW has been my way of combining the emo confessionals I grew up with and the stream-of-consciousness hip hop that I fell in love with in my 20's. All wrapped in a bedroom-indie package. 

I write and produce all of my music myself from the guitar and bass down to the synths and drums. I'm a huge fan of bandlab for this (it's way better and more capable than people think). I play a modded purple Harley Benton PRS-style guitar mainly but also have an SG, Tele, Mitchell acoustic, and occasionally borrow a strat. 

All of the guitar sounds you hear come from various pedals (the main 2 being a fender amp simulator and a ts-808 clone) sometimes mixed with some digital effects depending on the song. 

More background on me as a person:

My real name is Billy and I grew up in Jacksonville, FL before moving to OKC where I've lived for the past 20 years. I live in a small apartment with my wife who is my best friend, a tortie cat who is my next best friend, and a pitbull/corgie mix who is also a close homie. 

I work as a software developer, mainly on mobile apps using flutter (I actually made this site with flutter), but I also work on other various projects using a multitude of programming languages. I'm also a huge fan of Linux and I've been using it since 2014. The name "archBTW." actually comes from a Linux meme. 

I have Bipolar Disorder Type I and have struggled with addiction for many years. Mainly alcohol and amphetamines but dabbling in pretty much everything I could get my hands on. I've been clean for a couple years now! 

I'm a devoted Christian but I'm not like other Christians, I'm a cool Christian 😎 Jokes aside, I'm not afraid to admit I'm a sinner and I won't pretend I'm not. I'm a human. I also try my best to love everybody. Gay, atheist, satanic, I don't really give af. Just don't be an asshole and you're cool with me. 

So that's pretty much me in a nutshell. If you wanna know more, check out some of my music. Like I said, it's pretty much my diary. 

-archBTW

""",
                style: TextStyle(
                  color: kTextColor,
                  fontSize: isDesktop ? 16 : 14,
                  height: 1.6, // Line height
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}