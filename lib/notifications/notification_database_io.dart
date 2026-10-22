import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

DatabaseFactory notificationDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi;
  }
  return databaseFactory;
}

Future<String> notificationDatabaseDirectory(DatabaseFactory factory) async {
  if (Platform.isWindows || Platform.isLinux) {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return directory.path;
  }
  return factory.getDatabasesPath();
}
