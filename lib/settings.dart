import 'package:flutter/material.dart';

import 'account.dart';
import 'brain.dart';
import 'paywall.dart';
import 'store.dart';
import 'terms.dart';

// Keep in step with "version:" in pubspec.yaml.
const appVersion = '1.0.0';

class Settings extends StatelessWidget {
  const Settings({super.key});

  Future<void> _deleteAll(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(store.t('delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('delete'))),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      Navigator.pop(context); // close Settings first, then wipe (Gamy goes back to the age check)
      store.reset();
    }
  }

  Future<void> _signIn(BuildContext context) async {
    final bar = ScaffoldMessenger.of(context), err = await account.signIn();
    if (err != null) bar.showSnackBar(SnackBar(content: Text(store.t(err))));
  }

  Future<void> _changeAccount(BuildContext context) async {
    final bar = ScaffoldMessenger.of(context), nav = Navigator.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(store.t('change_confirm').replaceFirst('{email}', account.user?.email ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('change'))),
        ],
      ),
    );
    if (yes != true) return;
    final err = await account.changeAccount();
    if (err != null) {
      bar.showSnackBar(SnackBar(content: Text(store.t(err))));
      return;
    }
    nav.pop(); // Nov 23: changed: the Account window closes too (it showed the old details)
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final bar = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(store.t('delete_account_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('delete'))),
        ],
      ),
    );
    if (yes != true) return;
    final err = await account.deleteAccount();
    if (err != null) bar.showSnackBar(SnackBar(content: Text(store.t(err))));
  }

  Future<void> _download(BuildContext context, {bool search = false}) async {
    final bar = ScaffoldMessenger.of(context);
    final why = await brain.download(search: search);
    if (why != null) bar.showSnackBar(SnackBar(content: Text(store.t('brain_failed').replaceFirst('{why}', store.t(why)))));
  }

  // Tapping a row opens its details (like About Gamy): the full explanation and the buttons.
  // The window updates by itself (download progress, signing in...).
  void _details(BuildContext context, String title, Widget Function() body) => showDialog(
        context: context,
        builder: (ctx) => ListenableBuilder(
          listenable: Listenable.merge([store, brain, account]),
          builder: (ctx, _) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: body()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('close')))],
          ),
        ),
      );

  Widget _account(BuildContext context) {
    final t = store.t, user = account.user;
    return ListTile(
      leading: const Icon(Icons.account_circle),
      title: Text(t('account')),
      subtitle: Text(user == null ? t('not_signed_in') : user.email ?? ''),
      onTap: () => _details(context, t('account'), () {
        final user = account.user;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(user == null ? t('account_off') : t('account_on').replaceFirst('{email}', user.email ?? '')),
          const SizedBox(height: 12),
          if (account.busy)
            const Center(child: CircularProgressIndicator())
          else if (user == null)
            FilledButton.icon(onPressed: () => _signIn(context), icon: const Icon(Icons.login), label: Text(t('sign_in')))
          else ...[
            OutlinedButton.icon(
                onPressed: () => _changeAccount(context),
                icon: const Icon(Icons.switch_account),
                label: Text(t('change_account'))),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: account.signOut, child: Text(t('sign_out'))),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _deleteAccount(context),
              child: Text(t('delete_account'), style: const TextStyle(color: Colors.red)),
            ),
            Text(t('delete_account_note'), style: Theme.of(context).textTheme.bodySmall),
          ],
        ]);
      }),
    );
  }

  // One row for the brain and one for smart search (an optional extra), each with its own download.
  String _status(bool search) {
    final t = store.t, has = search ? brain.hasSearch : brain.has, ready = search ? brain.searchReady : brain.ready;
    if (brain.progress != null && brain.searching == search) {
      return '${t('brain_downloading')} ${(brain.progress! * 100).round()}%';
    }
    if (brain.loading && has && !ready) return t('brain_loading');
    return ready ? t('status_on') : t(has ? 'brain_bad' : 'status_off');
  }

  Widget _model(BuildContext context, {required bool search}) {
    final t = store.t, title = t(search ? 'search_title' : 'brain');
    return ListTile(
      leading: Icon(search ? Icons.travel_explore : Icons.psychology),
      title: Text(title),
      subtitle: Text(_status(search)),
      onTap: () => _details(context, title, () {
        final has = search ? brain.hasSearch : brain.has, busy = brain.progress != null;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(t(search ? 'search_note' : 'brain_note')),
          const SizedBox(height: 8),
          Text(_status(search), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (has)
            OutlinedButton(onPressed: () => brain.remove(search: search), child: Text(t('brain_remove')))
          else
            FilledButton(
                onPressed: busy ? null : () => _download(context, search: search), child: Text(t('brain_get'))),
        ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([store, brain, account]),
        builder: (context, _) {
          final t = store.t;
          return Scaffold(
            appBar: AppBar(title: Text(t('settings'))),
            body: ListView(children: [
              // Each row shows a short status; tapping it opens the details (like About Gamy)
              _account(context),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(t('language')),
                // Under the title (not at the right edge), and shrinks if it still doesn't fit a small phone
                subtitle: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'fil', label: Text('Filipino')),
                      ],
                      selected: {store.lang},
                      onSelectionChanged: (_) => store.setLang(),
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: Text(t('night_mode')),
                value: store.dark,
                onChanged: (_) => store.toggleDark(),
              ),
              // Gamy's brain (answers in his own words) and smart search (finds answers by meaning):
              // each downloaded once, then offline
              _model(context, search: false),
              _model(context, search: true),
              ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: const Text('Gamy Pro'),
                subtitle: Text(store.pro ? t('status_on') : t('free_plan')),
                onTap: () => store.pro
                    ? _details(context, 'Gamy Pro', () => Text(t('pro_active'))) // what Pro includes
                    : showPro(context,
                        '${t('uploads_left').replaceFirst('{used}', '${store.uploads}')}\n'
                        '${t('items_left').replaceFirst('{left}', '${store.itemsLeft}')}'),
              ),
              // One row for the version, the Terms and the open-source licenses. The licenses must stay
              // reachable somewhere (llama.cpp, Firebase, SQLite... require the credit); Flutter's About
              // box has a "View licenses" button for that.
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(t('about_gamy')),
                subtitle: Text(t('about_note')),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Gamy',
                  applicationVersion: appVersion,
                  children: [
                    TextButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          content: const SingleChildScrollView(child: Text(termsText)),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
                        ),
                      ),
                      child: Text(t('terms_title')),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(t('delete_all'), style: const TextStyle(color: Colors.red)),
                subtitle: Text(t('delete_all_note')),
                onTap: () => _deleteAll(context),
              ),
            ]),
          );
        },
      );
}
