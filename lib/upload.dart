import 'dart:io';

import 'package:flutter/material.dart';

import 'account.dart';
import 'paywall.dart';
import 'store.dart';

class Upload extends StatefulWidget {
  const Upload({super.key});
  @override
  State<Upload> createState() => _UploadState();
}

class _UploadState extends State<Upload> {
  bool busy = false;

  Future<void> _addSubject() async {
    var name = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(store.t('add_subject')),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: store.t('subject_name')),
          onChanged: (v) => name = v,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('add'))),
        ],
      ),
    );
    if (ok == true && name.trim().isNotEmpty) store.addSubject(name.trim());
  }

  Future<void> _addModule(Map s) async {
    if (!store.canUpload) return showPro(context, store.t('pro_uploads')); // free plan: 3 uploads total
    setState(() => busy = true);
    final failed = await store.addModules(s, ask: _askSame); // several files can be picked at once
    if (!mounted) return;
    setState(() => busy = false);
    final pro = failed.remove('pro_uploads');
    if (failed.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failed.join('\n')), duration: const Duration(seconds: 6)));
    }
    if (pro) showPro(context, store.t('pro_uploads')); // the free plan ran out halfway through the files
  }

  // The file is already in this subject: keep both, replace the old one, or skip it.
  Future<String> _askSame(String name) async =>
      await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(store.t('same_file').replaceFirst('{name}', name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: Text(store.t('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: Text(store.t('replace'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'both'), child: Text(store.t('keep_both'))),
          ],
        ),
      ) ??
      'cancel';

  Future<void> _signIn() async {
    final err = await account.signIn();
    if (err != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.t(err))));
  }

  Future<void> _deleteSubject(Map s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(store.t('confirm_delete')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('delete'))),
        ],
      ),
    );
    if (yes == true) store.remove(store.subjects, s);
  }

  @override
  Widget build(BuildContext context) {
    final t = store.t;
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Wrap instead of Row: a long label (Filipino, big phone font) wraps instead of running off the screen
      Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.icon(onPressed: busy ? null : _addSubject, icon: const Icon(Icons.add), label: Text(t('add_subject'))),
        if (busy) const CircularProgressIndicator(),
      ]),
      const SizedBox(height: 12),
      // Not signed in: the lessons live only on this device, so say so (and offer the sign-in)
      if (account.user == null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_off),
            title: Text(t('not_saved')),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: account.busy ? null : _signIn, child: Text(t('sign_in'))),
            ),
          ),
        ),
      if (!store.pro)
        Text(t('uploads_left').replaceFirst('{used}', '${store.uploads}'), style: Theme.of(context).textTheme.bodySmall),
      if (store.subjects.isEmpty) Text(t('no_subjects')),
      for (final s in store.subjects)
        Card(
          key: ObjectKey(s),
          child: ExpansionTile(
            title: Text(s['name']),
            subtitle: Text('${(s['modules'] as List).length} ${t('modules')}'),
            children: [
              for (final m in s['modules'])
                ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(m['name']),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => store.remove(s['modules'], m)),
                ),
              OverflowBar(children: [
                TextButton.icon(
                  onPressed: busy ? null : () => _addModule(s),
                  icon: const Icon(Icons.upload_file),
                  label: Text(t(Platform.isAndroid ? 'add_module_photo' : 'add_module')),
                ),
                TextButton(
                  onPressed: () => _deleteSubject(s),
                  child: Text(t('delete_subject'), style: const TextStyle(color: Colors.red)),
                ),
              ]),
            ],
          ),
        ),
    ]);
  }
}
