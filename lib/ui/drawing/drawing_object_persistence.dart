import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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

  static Future<String?> exportToFile({required String storageKey, required List<DrawingObject> objects}) async {
    final text = encodeObjects(storageKey: storageKey, objects: objects);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出手动画线 JSON',
      fileName: '${_safeKey(storageKey)}.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) await file.writeAsString(text, flush: true);
    return path;
  }

  static Future<List<DrawingObject>?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '导入手动画线 JSON',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.bytes != null) return decodeObjects(utf8.decode(file.bytes!, allowMalformed: true));
    if (file.path != null) return decodeObjects(await File(file.path!).readAsString());
    return const [];
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
