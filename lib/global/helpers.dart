import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  final Uri uri = Uri.parse(url);
  if (!await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  )) {
    debugPrint('Could not launch $url');
  }
}

