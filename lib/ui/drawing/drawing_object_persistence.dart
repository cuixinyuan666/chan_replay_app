import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'drawing_object.dart';

/// Local JSON persistence for frontend DrawingObject data only.
/// It must not calculate or infer any Chan theory element.
class DrawingObjectPersistence {
  const DrawingObjectPersistence._();

  static const int _version = 1;

  static Future<List<DrawingObject>> load(String storageKey) async {
    final file = await _fileFor(storageKey);
    if (!await file.exists()) return const [];
    try {
      return decodeObjects(await file.readAsString());
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(String storageKey, List<DrawingObject> objects) async {
    final file = await _fileFor(storageKey);
    await file.parent.create(recursive: true);
    await file.writeAsString(encodeObjects(storageKey: storageKey, objects: objects), flush: true);
  }

  static String encodeObjects({required String storageKey, required List<DrawingObject> objects}) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'version': _version,
      'storageKey': storageKey,
      'updatedAt': DateTime.now().toIso8601String(),
      'objects': objects.map((e) => e.toJson()).toList(growable: false),
    });
  }

  static List<DrawingObject> decodeObjects(String text) {
    final decoded = jsonDecode(text);
    if (decoded is List) {
      return DrawingObjectCollection.fromJson(decoded.cast<Object?>()).objects;
    }
    if (decoded is Map<String, dynamic>) {
      final objects = decoded['objects'];
      if (objects is List) return DrawingObjectCollection.fromJson(objects.cast<Object?>()).objects;
    }
    return const [];
  }

  static Future<File> _fileFor(String storageKey) async {
    final dir = await getApplicationSupportDirectory();
    final safeKey = _safeKey(storageKey);
    return File('${dir.path}${Platform.pathSeparator}drawings${Platform.pathSeparator}$safeKey.json');
  }

  static String _safeKey(String raw) {
    final value = raw.trim().isEmpty ? 'default' : raw.trim();
    return value.replaceAll(RegExp('[^a-zA-Z0-9._-]+'), '_');
  }
}
