import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

class DeviceService {
  static const channel = MethodChannel('fitnotes/device');

  static Future<T?> call<T>(String method, [Map<String, Object?>? arguments]) async {
    if (!Platform.isAndroid) return null;
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> saveFile(String name, Uint8List bytes, {String mime = 'application/octet-stream'}) async {
    if (Platform.isAndroid) return await call<bool>('saveFile', {'name': name, 'bytes': bytes, 'mime': mime}) ?? false;
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    await XFile.fromData(bytes, name: name, mimeType: mime).saveTo(location.path);
    return true;
  }
}
