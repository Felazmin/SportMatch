import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../booking/demo_booking.dart' show bookingDate, bookingTime;
import 'notification_models.dart';
import 'notification_database_factory.dart';

class NotificationStore {
  NotificationStore({DatabaseFactory? factory, this.path})
    : _factory = factory ?? notificationDatabaseFactory();
  final DatabaseFactory _factory;
  final String? path;
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    try {
      return await _factory.openDatabase(
        path ??
            p.join(
              await notificationDatabaseDirectory(_factory),
              'sportmatch_notifications.db',
            ),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner TEXT NOT NULL, eventKey TEXT NOT NULL, bookingId TEXT NOT NULL,
            kind TEXT NOT NULL CHECK(kind IN ('confirmed','changed','cancelled','reminder')),
            title TEXT NOT NULL, body TEXT NOT NULL, created INTEGER NOT NULL,
            scheduled INTEGER, readAt INTEGER,
            deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1)),
            UNIQUE(owner,eventKey))''');
            await db.execute(
              'CREATE INDEX notifications_owner_time ON notifications(owner,deleted,scheduled,created)',
            );
            await db.execute('''CREATE TABLE reminder_preferences (
            owner TEXT PRIMARY KEY, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
            minutes INTEGER NOT NULL CHECK(minutes IN (1,15,30,60)))''');
            await db.execute('''CREATE TABLE booking_notice_states (
            owner TEXT NOT NULL, bookingId TEXT NOT NULL, fingerprint TEXT NOT NULL,
            confirmed INTEGER NOT NULL, cancelled INTEGER NOT NULL,
            PRIMARY KEY(owner,bookingId))''');
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<ReminderPreferences> preferences(String owner) async {
    final rows = await (await database).query(
      'reminder_preferences',
      where: 'owner = ?',
      whereArgs: [owner],
    );
    return rows.isEmpty
        ? const ReminderPreferences()
        : ReminderPreferences(
            enabled: rows.single['enabled'] == 1,
            minutes: rows.single['minutes'] as int,
          );
  }

  Future<void> savePreferences(String owner, ReminderPreferences value) async {
    if (owner.isEmpty ||
        !ReminderPreferences.leadTimes.contains(value.minutes)) {
      throw ArgumentError('Invalid reminder preferences');
    }
    await (await database).insert('reminder_preferences', {
      'owner': owner,
      'enabled': value.enabled ? 1 : 0,
      'minutes': value.minutes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> reconcile(
    String owner,
    List<BookingNoticeState> bookings,
    DateTime now,
  ) async {
    final prefs = await preferences(owner);
    await (await database).transaction((tx) async {
      final desired = <String>{};
      for (final b in bookings) {
        final previous = await tx.query(
          'booking_notice_states',
          where: 'owner = ? AND bookingId = ?',
          whereArgs: [owner, b.id],
        );
        final old = previous.firstOrNull;
        final active = b.confirmed && !b.cancelled && b.start.isAfter(now);
        final details =
            '${b.venue} · Sân ${b.court}\n${bookingDate(b.start)} · ${bookingTime(b.start)}';
        Future<void> insert(
          String kind,
          String title, {
          DateTime? scheduled,
          String? key,
        }) async {
          await tx.insert('notifications', {
            'owner': owner,
            'eventKey': key ?? '$kind:${b.id}:${b.fingerprint}',
            'bookingId': b.id,
            'kind': kind,
            'title': title,
            'body': details,
            'created': now.millisecondsSinceEpoch,
            'scheduled': scheduled?.millisecondsSinceEpoch,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        if (active && (old == null || old['confirmed'] != 1)) {
          await insert('confirmed', 'Lịch đặt đã được xác nhận');
        } else if (active &&
            old != null &&
            old['fingerprint'] != b.fingerprint) {
          await insert('changed', 'Lịch đặt đã thay đổi');
        }
        if (b.cancelled &&
            old != null &&
            old['cancelled'] != 1 &&
            old['confirmed'] == 1) {
          await insert('cancelled', 'Lịch đặt đã hủy');
        }
        if (active && !b.suppressed && prefs.enabled) {
          final time = b.start.subtract(Duration(minutes: prefs.minutes));
          final key = 'reminder:${b.id}:${b.fingerprint}:${prefs.minutes}';
          if (time.isAfter(now)) {
            desired.add(key);
            await insert(
              'reminder',
              'Sắp đến giờ chơi',
              scheduled: time,
              key: key,
            );
          }
        }
        await tx.insert('booking_notice_states', {
          'owner': owner,
          'bookingId': b.id,
          'fingerprint': b.fingerprint,
          'confirmed': b.confirmed ? 1 : 0,
          'cancelled': b.cancelled ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Keep deletion tombstones so reconciliation cannot resurrect user-deleted items.
      final pending = await tx.query(
        'notifications',
        where:
            "owner = ? AND kind = 'reminder' AND scheduled > ? AND deleted = 0",
        whereArgs: [owner, now.millisecondsSinceEpoch],
      );
      for (final row in pending) {
        if (!desired.contains(row['eventKey'])) {
          await tx.delete(
            'notifications',
            where: 'owner = ? AND id = ?',
            whereArgs: [owner, row['id']],
          );
        }
      }
    });
  }

  Future<List<InboxNotice>> list(String owner) async =>
      (await (await database).query(
        'notifications',
        where: 'owner = ? AND deleted = 0',
        whereArgs: [owner],
        orderBy: 'COALESCE(scheduled,created) DESC, id DESC',
      )).map(InboxNotice.fromMap).toList();

  Future<InboxNotice?> find(String owner, int id) async {
    final rows = await (await database).query(
      'notifications',
      where: 'owner = ? AND id = ? AND deleted = 0',
      whereArgs: [owner, id],
    );
    return rows.isEmpty ? null : InboxNotice.fromMap(rows.single);
  }

  Future<void> markRead(String owner, int id, DateTime now) async {
    await (await database).update(
      'notifications',
      {'readAt': now.millisecondsSinceEpoch},
      where: 'owner = ? AND id = ? AND deleted = 0',
      whereArgs: [owner, id],
    );
  }

  Future<void> markAllRead(String owner, DateTime now) async {
    await (await database).update(
      'notifications',
      {'readAt': now.millisecondsSinceEpoch},
      where:
          'owner = ? AND deleted = 0 AND (scheduled IS NULL OR scheduled <= ?)',
      whereArgs: [owner, now.millisecondsSinceEpoch],
    );
  }

  Future<void> delete(String owner, int id) async {
    await (await database).update(
      'notifications',
      {'deleted': 1},
      where: 'owner = ? AND id = ?',
      whereArgs: [owner, id],
    );
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }
}
