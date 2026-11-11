import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai.dart';
import 'store.dart';
import 'terms.dart';

// First launch: age check, then the terms, then connecting the student's own AI account.
class Setup extends StatefulWidget {
  const Setup({super.key});
  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  bool adult = false, agree = false; // adult: passed the age check
  bool waiting = false, checking = false, phoneCode = false, advanced = false;
  String key = '', url = '', model = '', code = '';
  String? verifier; // secret for the phone login

  void _say(String k) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.t(k))));

  void _show(String text) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          content: SingleChildScrollView(child: Text(text)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('close')))],
        ),
      );

  // Saves the connection, and closes this screen if it was opened from Settings.
  void _connected(String k, [String? u, String? m]) {
    store.connect(k, u, m);
    _say('connected');
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _openRouter() async {
    if (Platform.isAndroid) {
      verifier = newVerifier();
      setState(() => phoneCode = true); // show the "paste your code" box
      await openRouterPhoneLogin(verifier!);
      return;
    }
    setState(() => waiting = true);
    String? k;
    try {
      k = await openRouterLogin();
    } catch (_) {}
    if (!mounted || !waiting) return; // cancelled
    setState(() => waiting = false);
    if (k == null) {
      _say('login_failed');
    } else {
      _connected(k);
    }
  }

  Future<void> _useCode() async {
    setState(() => checking = true);
    String? k;
    try {
      k = await exchangeCode(code, verifier!);
    } catch (_) {}
    if (!mounted) return;
    setState(() => checking = false);
    if (k == null) {
      _say('code_failed');
    } else {
      _connected(k);
    }
  }

  // Recognizes the service from the key, picks a model, sends one test message, then saves.
  Future<void> _checkKey() async {
    if (key.isEmpty) {
      _say('need_key');
      return;
    }
    var u = url.isNotEmpty ? url : knownUrl(key);
    if (u == null) {
      setState(() => advanced = true); // unknown service: ask for its address and model
      _say('unknown_key');
      return;
    }
    if (!u.startsWith('http')) u = 'https://$u';
    u = u.replaceAll(RegExp(r'/+$'), '');
    final isOpenRouter = u == openRouterUrl;
    setState(() => checking = true);
    try {
      final m = model.isNotEmpty ? model : (isOpenRouter ? 'openrouter/free' : await pickModel(u, key));
      try {
        await testAi(u, m, key);
      } catch (e) {
        if (e != 'limit') rethrow; // a used-up limit still means the key works
      }
      if (mounted) _connected(key, isOpenRouter ? null : u, isOpenRouter ? null : m);
    } catch (e) {
      if (mounted) _say(e is String && ['bad_key', 'not_found', 'offline', 'slow'].contains(e) ? 'check_$e' : 'check_ai_error');
    }
    if (mounted) setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final t = store.t;
    return Scaffold(
      // A back arrow appears when this screen was opened from Settings ("Change AI")
      appBar: Navigator.canPop(context) ? AppBar() : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
            if (!store.agreed && !adult) ...[
              // Step 1: age check
              Image.asset('assets/gamy/smug.png', height: 160),
              Text(t('welcome'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(t('age_note'), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => setState(() => adult = true), child: Text(t('is_adult'))),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Platform.isAndroid ? SystemNavigator.pop() : exit(0),
                child: Text(t('under_18')),
              ),
            ] else if (!store.agreed) ...[
              // Step 2: read the terms, then agree below them
              Text(t('terms_title'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Container(
                height: 360,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.brown), borderRadius: BorderRadius.circular(8)),
                child: const SingleChildScrollView(child: Text(termsText)),
              ),
              CheckboxListTile(value: agree, title: Text(t('agree')), onChanged: (v) => setState(() => agree = v!)),
              FilledButton(onPressed: agree ? store.agree : null, child: Text(t('continue'))),
            ] else ...[
              // Step 3: connect an AI account
              Image.asset('assets/gamy/happy_1.png', height: 160),
              Text(t('connect'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(t('connect_why'), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: waiting || checking ? null : _openRouter, child: Text(t('openrouter'))),
              if (waiting) ...[
                Padding(padding: const EdgeInsets.all(8), child: Text(t('waiting'), textAlign: TextAlign.center)),
                TextButton(onPressed: () => setState(() => waiting = false), child: Text(t('cancel'))),
              ],
              if (phoneCode) ...[
                // Phone login: OpenRouter shows a code after logging in; the student pastes it here.
                const SizedBox(height: 8),
                Text(t('paste_code')),
                TextField(decoration: InputDecoration(labelText: t('or_code')), onChanged: (v) => code = v),
                const SizedBox(height: 8),
                FilledButton(onPressed: checking ? null : _useCode, child: Text(t('use_code'))),
              ],
              const SizedBox(height: 24),
              Text(t('own_api'), style: const TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: t('api_key')),
                onChanged: (v) => key = v.trim(),
              ),
              if (advanced) ...[
                // Only for services Gamy doesn't recognize from the key
                TextField(
                  decoration: InputDecoration(labelText: t('api_url'), hintText: 'https://.../v1'),
                  onChanged: (v) => url = v.trim(),
                ),
                TextField(
                  decoration: InputDecoration(labelText: t('api_model')),
                  onChanged: (v) => model = v.trim(),
                ),
              ],
              const SizedBox(height: 8),
              if (checking) Text(t('checking'), textAlign: TextAlign.center),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: () => _show(t('key_steps')), child: Text(t('how_key'))),
                OutlinedButton(onPressed: checking ? null : _checkKey, child: Text(t('check_save'))),
              ]),
            ],
            Align(
              child: TextButton(onPressed: store.setLang, child: Text(store.lang == 'en' ? 'Filipino' : 'English')),
            ),
          ]),
        ),
      ),
    );
  }
}
