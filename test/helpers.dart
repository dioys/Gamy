import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Shared test setup. Tests never touch your real Gamy data: the app "saves" into a temporary folder.

// A pretend module, with course and contact lines that Gamy must ignore.
const sample = '''
Computer Systems Servicing
Instructor: Juan Cruz, email juan@school.edu, mobile 0917-123-4567

A central processing unit is the main chip that carries out the instructions of a computer program.
Random access memory is a short-term memory that holds the data the computer is using right now.
A hard disk drive is a storage device that keeps data even when the computer is turned off.
A power supply unit is the part that converts electricity from the wall into power the computer can use.
The motherboard is the main circuit board that connects all the parts of a computer together.
An operating system is the software that manages the hardware and runs other programs.
Cache memory: a small, very fast memory inside the processor that stores data used often.
''';

// What rules.dart should find in [sample]: meaning (as shown in questions) -> term.
const facts = {
  'The main chip that carries out the instructions of a computer program': 'central processing unit',
  'A short-term memory that holds the data the computer is using right now': 'Random access memory',
  'A storage device that keeps data even when the computer is turned off': 'hard disk drive',
  'The part that converts electricity from the wall into power the computer can use': 'power supply unit',
  'The main circuit board that connects all the parts of a computer together': 'motherboard',
  'The software that manages the hardware and runs other programs': 'operating system',
  'A small, very fast memory inside the processor that stores data used often': 'Cache memory',
};

Map<String, dynamic> subject() => {
      'name': 'CSS',
      'modules': [
        {'name': 'Module 1', 'text': sample}
      ],
      'scores': [],
    };

// Points path_provider at a folder instead of the real app folder.
class FakePath extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  FakePath(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

// A brand-new, empty Gamy saved in a new temporary folder. Returns the folder (delete it after the test).
Future<Directory> freshStore() async {
  final dir = await Directory.systemTemp.createTemp('gamy_test');
  PathProviderPlatform.instance = FakePath(dir.path);
  store
    ..lang = 'en'
    ..dark = false
    ..agreedTo = null
    ..pro = true
    ..uploads = 0
    ..weekItems = 0
    ..weekStart = null
    ..moods = ['idle', 'idle']
    ..subjects = [];
  await store.load();
  return dir;
}
