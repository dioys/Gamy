import 'package:flutter/material.dart';

import 'account.dart';
import 'store.dart';
import 'terms.dart';

// First launch (and again whenever the terms change):
//   1. the Terms of Use and Privacy Policy, full screen, agreed with one checkbox (18 or older + agree);
//   2. a recommendation to sign in with Google, with the reasons, or "Skip for now".
class Setup extends StatefulWidget {
  const Setup({super.key});
  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  bool agree = false, signInStep = false;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: Listenable.merge([store, account]), builder: (context, _) => _page(context));

  // Agreed: already signed in (the terms changed) goes straight in; otherwise the sign-in recommendation.
  void _agreed() => account.user != null ? store.agree() : setState(() => signInStep = true);

  Future<void> _signIn() async {
    final bar = ScaffoldMessenger.of(context), err = await account.signIn();
    if (err != null) {
      bar.showSnackBar(SnackBar(content: Text(store.t(err))));
    } else if (account.user != null) {
      store.agree();
    }
  }

  Widget _page(BuildContext context) {
    final t = store.t, text = Theme.of(context).textTheme;
    final language = TextButton(onPressed: store.setLang, child: Text(store.lang == 'en' ? 'Filipino' : 'English'));
    if (signInStep) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            // Everything is drawn (not a lazy list), so "Skip for now" is there even on short windows.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/gamy/smug.png', height: 140),
              Text(t('keep_safe'), textAlign: TextAlign.center, style: text.headlineSmall),
              const SizedBox(height: 12),
              for (final why in ['why_1', 'why_2', 'why_3', 'why_4'])
                ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(t(why))),
              const SizedBox(height: 12),
              if (account.busy)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton.icon(onPressed: _signIn, icon: const Icon(Icons.login), label: Text(t('sign_in'))),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: store.agree, child: Text(t('skip'))),
              ],
              const SizedBox(height: 8),
              Text(t('skip_note'), textAlign: TextAlign.center, style: text.bodySmall),
              Align(child: language),
            ])),
          ),
        ),
      );
    }
    // The agreement uses the whole screen: the text scrolls, the checkbox and button stay at the bottom.
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(child: Text(t('terms_title'), style: text.titleLarge)),
              language,
            ]),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(border: Border.all(color: Colors.brown), borderRadius: BorderRadius.circular(8)),
              child: const SingleChildScrollView(padding: EdgeInsets.all(16), child: Text(termsText)),
            ),
          ),
          CheckboxListTile(
            value: agree,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t('agree')),
            onChanged: (v) => setState(() => agree = v!),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: agree ? _agreed : null, child: Text(t('continue'))),
            ),
          ),
        ]),
      ),
    );
  }
}
