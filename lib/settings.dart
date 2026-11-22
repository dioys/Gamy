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
    if (!await brain.download(search: search)) bar.showSnackBar(SnackBar(content: Text(store.t('brain_failed'))));
  }

  // One row for the brain and one for smart search (an optional extra), each with its own download.
  Widget _model(BuildContext context, {required bool search}) {
    final t = store.t, has = search ? brain.hasSearch : brain.has, ready = search ? brain.searchReady : brain.ready;
    final mine = brain.progress != null && brain.searching == search; // this one is downloading
    return ListTile(
      leading: Icon(search ? Icons.travel_explore : Icons.psychology),
      title: Text(t(search ? 'search_title' : 'brain')),
      subtitle: Text(mine
          ? '${t('brain_downloading')} ${(brain.progress! * 100).round()}%'
          : brain.loading && has && !ready
              ? t('brain_loading')
              : ready
                  ? t('brain_on')
                  : t(has ? 'brain_bad' : (search ? 'search_note' : 'brain_note'))),
      trailing: mine || (brain.loading && has && !ready)
          ? null
          : has
              ? TextButton(onPressed: () => brain.remove(search: search), child: Text(t('brain_remove')))
              : FilledButton(
                  onPressed: brain.progress != null ? null : () => _download(context, search: search),
                  child: Text(t('brain_get'))),
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
              // Optional Google account: a copy of the lessons online, so they survive a reinstall or a new device
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text(t('account')),
                // The button sits under the text (not at the right edge), so long Filipino labels fit small phones
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(account.user == null
                      ? t('account_off')
                      : t('account_on').replaceFirst('{email}', account.user!.email ?? '')),
                  const SizedBox(height: 8),
                  if (account.busy)
                    const CircularProgressIndicator()
                  else if (account.user == null)
                    FilledButton.icon(
                        onPressed: () => _signIn(context), icon: const Icon(Icons.login), label: Text(t('sign_in')))
                  else
                    OutlinedButton(onPressed: account.signOut, child: Text(t('sign_out'))),
                ]),
              ),
              if (account.user != null)
                ListTile(
                  leading: const Icon(Icons.no_accounts, color: Colors.red),
                  title: Text(t('delete_account'), style: const TextStyle(color: Colors.red)),
                  subtitle: Text(t('delete_account_note')),
                  onTap: account.busy ? null : () => _deleteAccount(context),
                ),
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
                title: Text(store.pro ? 'Gamy Pro' : t('free_plan')),
                subtitle: store.pro
                    ? Text(t('pro_active')) // what Pro includes, so it's clear even while it's on
                    : Text('${t('uploads_left').replaceFirst('{used}', '${store.uploads}')}\n'
                        '${t('items_left').replaceFirst('{left}', '${store.itemsLeft}')}'),
                onTap: store.pro ? null : () => showPro(context, t('pro_why')),
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
