import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'setup.dart';
import 'store.dart';

// The "Get Gamy Pro" frame. [reason] says why it popped up (already translated).
Future<void> showPro(BuildContext context, String reason) {
  final t = store.t;
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Gamy Pro', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/gamy/poor.png', height: 160), // broke Gamy asking for help
          Text(t('pro_poor'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('$reason\n\n${t('pro_perks')}\n\n${t('pro_price')}'),
          const SizedBox(height: 12),
          Text(t('pro_ai_note'), style: TextStyle(color: Colors.red.shade700)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('not_now'))),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('billing_soon'))));
          },
          child: Text(t('get_pro')),
        ),
      ],
    ),
  );
}

// Shown when the student's AI account hits its limit. Gamy doesn't pay for AI, so it explains
// the two ways to keep going, step by step.
Future<void> showAiLimit(BuildContext context) {
  final t = store.t;
  const bold = TextStyle(fontWeight: FontWeight.bold);
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('limit_title')),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t('limit_body')),
          if (store.url == null) ...[
            // Only for students who logged in with OpenRouter
            const SizedBox(height: 16),
            Text(t('limit_opt1'), style: bold),
            Text(t('credit_steps')),
            TextButton(
              onPressed: () => launchUrl(Uri.parse('https://openrouter.ai/settings/credits')),
              child: Text(t('open_credits')),
            ),
          ],
          const SizedBox(height: 16),
          Text(t('limit_opt2'), style: bold),
          Text(t('key_steps')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const Setup())); // connect another AI
          },
          child: Text(t('change_ai')),
        ),
      ],
    ),
  );
}
