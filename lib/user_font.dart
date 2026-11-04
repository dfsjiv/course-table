import 'dart:io';

import 'package:flutter/services.dart';

final _loaded = <String>{};

/// Registers the font file at [path] under [family]. Returns false when the
/// file is gone or is not a font the engine can read.
Future<bool> loadUserFont(String family, String path) async {
  if (_loaded.contains(family)) return true;
  try {
    final file = File(path);
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loaded.add(family);
    return true;
  } catch (_) {
    return false;
  }
}
