import 'package:flutter/material.dart';

import 'paywall.dart';
import 'setup.dart';
import 'store.dart';
import 'terms.dart';

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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final t = store.t;
          return Scaffold(
            appBar: AppBar(title: Text(t('settings'))),
            body: ListView(children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(t('language')),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'fil', label: Text('Filipino')),
                  ],
                  selected: {store.lang},
                  onSelectionChanged: (_) => store.setLang(),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: Text(t('night_mode')),
                value: store.dark,
                onChanged: (_) => store.toggleDark(),
              ),
              ListTile(
                leading: const Icon(Icons.key),
                title: Text(t('change_ai')),
                // Opens the connect screen on top; the current AI stays until a new one is saved
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Setup())),
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: Text(store.pro ? 'Gamy Pro' : t('free_plan')),
                subtitle: store.pro
                    ? null
                    : Text('${t('uploads_left').replaceFirst('{used}', '${store.uploads}')}\n'
                        '${t('items_left').replaceFirst('{left}', '${store.itemsLeft}')}'),
                onTap: store.pro ? null : () => showPro(context, t('pro_why')),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(t('terms_title')),
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: const SingleChildScrollView(child: Text(termsText)),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
                  ),
                ),
              ),
              // Credits the open-source packages Gamy uses (their licenses require it)
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(t('licenses')),
                onTap: () => showLicensePage(context: context, applicationName: 'Gamy'),
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
