import 'package:sqflite/sqflite.dart';

DatabaseFactory notificationDatabaseFactory() => databaseFactorySqflitePlugin;
Future<String> notificationDatabaseDirectory(DatabaseFactory factory) =>
    factory.getDatabasesPath();
