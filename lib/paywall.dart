import 'package:flutter/material.dart';

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
