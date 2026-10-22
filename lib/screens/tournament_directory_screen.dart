import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../venues/venue_catalog.dart';
import 'finance_screen.dart';
import 'tournament_screen.dart';

class TournamentDirectoryScreen extends StatefulWidget {
  const TournamentDirectoryScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<TournamentDirectoryScreen> createState() =>
      _TournamentDirectoryScreenState();
}

class _TournamentDirectoryScreenState extends State<TournamentDirectoryScreen> {
  String _query = '', _period = 'current';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Quản lý giải đấu'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final entries = s.managedTournaments
          .where(
            (e) =>
                venueSearchText(
                  '${e.event.title} ${e.event.id} ${bookingDate(e.start)}',
                ).contains(venueSearchText(_query)) &&
                (_period == 'all' ||
                    (_period == 'ended') ==
                        !e.event.end(e.start).isAfter(s.now)),
          )
          .toList();
      if (_period == 'ended') {
        entries.sort((a, b) => b.start.compareTo(a.start));
      }
      return Scaffold(
        appBar: financeBar('Quản lý giải đấu'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            TextField(
              key: const Key('tournaments-search'),
              decoration: const InputDecoration(
                labelText: 'Tìm giải đấu',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in const {
                'current': 'Chưa kết thúc',
                  'ended': 'Đã kết thúc',
                  'all': 'Tất cả',
                }.entries)
                  ChoiceChip(
                    key: Key('tournaments-period-${e.key}'),
                    label: Text(e.value),
                    selected: _period == e.key,
                    onSelected: (_) => setState(() => _period = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty) const Text('Không có giải đấu phù hợp.'),
            for (final e in entries)
              ListTile(
                key: Key(
                  'tournament-${e.event.id}-${e.start.toIso8601String()}',
                ),
                contentPadding: EdgeInsets.zero,
                title: Text(e.event.title),
                subtitle: Text(
                  '${e.event.id} · ${bookingDate(e.start)} · ${bookingTime(e.start)}\n'
                  '${e.teams} đội · ${e.matches} trận · ${e.completed} kết quả',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TournamentScreen(
                      session: s,
                      event: e.event,
                      start: e.start,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
