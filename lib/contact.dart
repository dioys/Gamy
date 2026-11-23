import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store.dart';

// Gamy's contact: the terms, the Wikipedia name tag and the Report button all use this one address.
const contactEmail = 'gamyd022@gmail.com';

// The email a Report opens: Gamy's reply (or quiz question) already filled in, nothing sent until the student
// presses Send in their own email app. Google Play requires a way to report offensive AI-made content.
Uri reportMail(String what) => Uri(
      scheme: 'mailto',
      path: contactEmail,
      query: 'subject=${Uri.encodeComponent(store.t('report_subject'))}'
          '&body=${Uri.encodeComponent('${store.t('report_body')}\n\n$what')}',
    );

// Opens the email app; with no email app (common on Windows), copies the address and says where to send it.
Future<void> report(BuildContext context, String what) async {
  final bar = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(reportMail(what));
  } catch (_) {}
  if (opened) return;
  await Clipboard.setData(ClipboardData(text: '$contactEmail\n\n$what'));
  bar.showSnackBar(SnackBar(content: Text(store.t('report_copied').replaceFirst('{email}', contactEmail))));
}
