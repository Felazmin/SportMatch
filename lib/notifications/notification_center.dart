import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/demo_session.dart';
import '../demo/demo_finance.dart';
import 'notification_models.dart';
import 'notification_store.dart';
import 'reminder_gateway.dart';

class NotificationCenter extends ChangeNotifier {
  NotificationCenter({
    required this.session,
    required this.store,
    required this.gateway,
  });
  final DemoSession session;
  final NotificationStore store;
  final ReminderGateway gateway;
  ValueChanged<InboxNotice>? onOpen;
  List<InboxNotice> notices = const [];
  ReminderPreferences preferences = const ReminderPreferences();
  String? error;
  bool permissionDenied = false, loading = true;
  bool updating = false;
  bool _permissionRefused = false;
  bool _started = false, _disposed = false, _nativeReady = false;
  String? _actor, _scheduledOwner = '__initial__';
  int _generation = 0;
  int? _tap;
  Timer? _timer;
  final _scheduled = <int, DateTime>{};
  Future<void> _tail = Future.value();
  Future<void> _closed = Future.value();
  String? get owner =>
      session.initialized &&
          session.user != null &&
          session.role == DemoRole.player
      ? session.user!.identifier
      : null;
  DateTime get now => session.now;
  int get unread => notices.where((n) => n.due(now) && n.readAt == null).length;
  bool get supported => gateway.supported;

  void start({bool periodic = true}) {
    if (_started || _disposed) return;
    _started = true;
    session.addListener(_changed);
    if (periodic) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
    }
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    if (_actor != owner) {
      _actor = owner;
      _generation++;
      notices = const [];
      preferences = const ReminderPreferences();
      error = null;
      permissionDenied = false;
      _permissionRefused = false;
      loading = owner != null;
      notifyListeners();
    }
    unawaited(sync());
  }

  Future<void> _enqueue(Future<void> Function() task) {
    _tail = _tail.then((_) async {
      if (_disposed) return;
      try {
        await task();
      } catch (_) {
        if (!_disposed) {
          error =
              'Chưa cập nhật được thông báo hoặc lịch nhắc. Vui lòng thử lại.';
          loading = false;
          notifyListeners();
        }
      }
    });
    return _tail;
  }

  Future<void> sync() {
    final actor = owner, generation = _generation;
    final states = actor == null
        ? <BookingNoticeState>[]
        : session.bookings.map((b) {
            final payment = session.paymentFor(b);
            return BookingNoticeState(
              id: b.id,
              venue: b.venueName,
              court: b.court,
              start: b.start,
              hours: b.hours,
              revision: b.revision,
              confirmed: payment?.state == DemoPaymentState.approved,
              cancelled: b.cancelled,
              suppressed:
                  payment?.cancellation == DemoCancellationState.requested ||
                  b.attendance != DemoAttendance.pending,
            );
          }).toList();
    return _enqueue(() async {
      if (generation != _generation || actor != owner) return;
      if (!_nativeReady) {
        try {
          await gateway.initialize((id) {
            _tap = id;
            unawaited(sync());
          });
          _nativeReady = true;
        } catch (_) {
          error = 'Chưa khởi tạo được thông báo trên thiết bị.';
        }
      }
      if (_scheduledOwner != actor) {
        await gateway.cancelAll();
        _scheduled.clear();
        _scheduledOwner = actor;
      }
      if (actor == null) {
        loading = false;
        if (!_disposed) notifyListeners();
        return;
      }
      if (!await session.flush()) {
        await gateway.cancelAll();
        _scheduled.clear();
        throw StateError('Session not durable');
      }
      await store.reconcile(actor, states, now);
      final prefs = await store.preferences(actor),
          rows = await store.list(actor);
      if (_disposed || generation != _generation || actor != owner) return;
      final allowed =
          _nativeReady && supported && await gateway.permissionGranted();
      final desired =
          rows.where((n) => n.kind == 'reminder' && !n.due(now)).toList()
            ..sort((a, b) => a.scheduled!.compareTo(b.scheduled!));
      // Stay below the iOS pending-notification limit; always choose the nearest games.
      final targets = allowed && prefs.enabled
          ? desired.take(60).toList()
          : <InboxNotice>[];
      final ids = targets.map((n) => n.id).toSet();
      for (final id in _scheduled.keys.toList()) {
        if (!ids.contains(id)) {
          await gateway.cancel(id);
          _scheduled.remove(id);
        }
      }
      for (final n in targets) {
        if (_disposed || generation != _generation || actor != owner) return;
        if (_scheduled[n.id] != n.scheduled) {
          await gateway.schedule(n);
          _scheduled[n.id] = n.scheduled!;
        }
      }
      if (_disposed || generation != _generation || actor != owner) return;
      notices = List.unmodifiable(rows);
      preferences = prefs;
      permissionDenied = _permissionRefused || (prefs.enabled && !allowed);
      loading = false;
      error = null;
      final tap = _tap;
      if (tap != null) {
        _tap = null;
        final row = rows.where((n) => n.id == tap).firstOrNull;
        if (row != null) onOpen?.call(row);
      }
      notifyListeners();
    });
  }

  Future<void> setPreferences(bool enabled, int minutes) {
    if (_disposed || updating) return Future.value();
    updating = true;
    notifyListeners();
    final actor = owner, generation = _generation;
    final task = _enqueue(() async {
      if (actor == null || actor != owner || generation != _generation) return;
      var allowed = false;
      if (enabled) {
        await gateway.initialize((id) {
          _tap = id;
          unawaited(sync());
        });
        _nativeReady = true;
        allowed = await gateway.requestPermission();
      }
      if (actor != owner || generation != _generation) return;
      await store.savePreferences(
        actor,
        ReminderPreferences(enabled: enabled && allowed, minutes: minutes),
      );
      _permissionRefused = enabled && !allowed;
      permissionDenied = _permissionRefused;
    });
    return task.then((_) => sync()).whenComplete(() {
      updating = false;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> markRead(int id) =>
      _mutate((actor) => store.markRead(actor, id, now));
  Future<void> markAllRead() =>
      _mutate((actor) => store.markAllRead(actor, now));
  Future<void> delete(int id) => _mutate((actor) => store.delete(actor, id));
  Future<void> _mutate(Future<void> Function(String actor) action) {
    final actor = owner, generation = _generation;
    return _enqueue(() async {
      if (actor != null && actor == owner && generation == _generation) {
        await action(actor);
      }
    }).then((_) => sync());
  }

  Future<InboxNotice?> resolve(int id) async {
    final actor = owner;
    if (actor == null) return null;
    final row = await store.find(actor, id);
    return owner == actor && row?.owner == actor ? row : null;
  }

  Future<void> flush() async {
    await _tail;
  }

  Future<void> shutdown() {
    dispose();
    return _closed;
  }

  @override
  void dispose() {
    if (_disposed) return;
    final loggedOut = owner == null;
    _disposed = true;
    if (_started) session.removeListener(_changed);
    _timer?.cancel();
    _closed = _tail.then((_) async {
      // Keep scheduled reminders across normal process termination.
      if (loggedOut) await gateway.cancelAll();
      await store.close();
    });
    super.dispose();
  }
}
