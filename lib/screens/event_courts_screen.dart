import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_events.dart';
import 'finance_screen.dart';

class EventCourtsScreen extends StatefulWidget {
  const EventCourtsScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  @override
  State<EventCourtsScreen> createState() => _EventCourtsScreenState();
}

class _EventCourtsScreenState extends State<EventCourtsScreen> {
  final _courts = <int>{};
  late final String? _actor;
  late List<String> _ids;
  bool _busy = false, _committed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _actor = widget.session.user?.identifier;
    final blocks = widget.session.eventCourts(widget.event.id, widget.start);
    _ids = blocks.map((b) => b.id).toList();
    _courts.addAll(blocks.map((b) => b.court));
  }

  Future<void> _save() async {
    final s = widget.session;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (s.user?.identifier != _actor || s.role == DemoRole.player) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      if (!_committed) {
        s.allocateEventCourts(
          widget.event.id,
          widget.start,
          _courts.toList()..sort(),
          expectedBlockIds: _ids,
        );
        _ids = s
            .eventCourts(widget.event.id, widget.start)
            .map((b) => b.id)
            .toList();
        _committed = true;
      } else {
        final current = s
            .eventCourts(widget.event.id, widget.start)
            .map((b) => b.id)
            .toSet();
        if (current.length != _ids.length || !_ids.every(current.contains)) {
          throw StateError('Phân sân đã thay đổi; mở lại hồ sơ.');
        }
        await s.retrySave();
      }
      if (!await s.flush()) throw StateError('Chưa lưu được. Hãy thử lưu lại.');
      if (mounted &&
          s.user?.identifier == _actor &&
          s.role != DemoRole.player) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final allowed =
          s.user != null &&
          s.user?.identifier == _actor &&
          s.role != DemoRole.player;
      return Scaffold(
        appBar: financeBar('Phân sân hoạt động'),
        body: !allowed
            ? const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FinanceSaveNotice(session: s),
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${DemoBooking.venue}\n${bookingDate(widget.start)} · ${bookingTime(widget.start)}–${bookingTime(widget.event.end(widget.start))}',
                  ),
                  const SizedBox(height: 16),
                  for (var court = 1; court <= 3; court++)
                    CheckboxListTile(
                      key: Key('event-court-$court'),
                      contentPadding: EdgeInsets.zero,
                      title: Text('Sân $court'),
                      value: _courts.contains(court),
                      onChanged: _busy || _committed
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                _courts.add(court);
                              } else {
                                _courts.remove(court);
                              }
                            }),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      key: const Key('event-courts-error'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('event-courts-save'),
                    icon: const Icon(Icons.save_outlined),
                    onPressed: _busy ? null : _save,
                    label: Text(_committed ? 'Thử lưu lại' : 'Lưu phân sân'),
                  ),
                ],
              ),
      );
    },
  );
}
