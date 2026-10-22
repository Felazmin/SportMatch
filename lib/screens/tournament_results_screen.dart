import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_events.dart';
import '../demo/demo_matches.dart';
import '../venues/venue_catalog.dart';
import 'finance_screen.dart';

class TournamentResultsScreen extends StatefulWidget {
  const TournamentResultsScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  @override
  State<TournamentResultsScreen> createState() =>
      _TournamentResultsScreenState();
}

class _TournamentResultsScreenState extends State<TournamentResultsScreen> {
  String _sort = 'name';
  String _query = '';
  bool _activeOnly = false;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      List<DemoTeamResults> results;
      try {
        results = s.tournamentResults(widget.event.id, widget.start).toList();
      } on StateError {
        return Scaffold(
          appBar: financeBar('Kết quả các đội'),
          body: const Center(
            child: Text('Cần tài khoản quản lý hoặc vé của giải này.'),
          ),
        );
      }
      if (_sort == 'wins') {
        results.sort((a, b) {
          final wins = b.wins.compareTo(a.wins);
          return wins != 0 ? wins : a.ticketId.compareTo(b.ticketId);
        });
      }
      final total = results.length;
      results = results
          .where(
            (r) =>
                (!_activeOnly || !r.cancelled) &&
                venueSearchText('${r.team} ${r.ticketId}')
                    .contains(venueSearchText(_query)),
          )
          .toList();
      return Scaffold(
        appBar: financeBar('Kết quả các đội'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              widget.event.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(bookingDate(widget.start)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('results-search'),
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Tìm tên đội hoặc mã vé',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('results-search-clear'),
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            SwitchListTile.adaptive(
              key: const Key('results-active-only'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Chỉ đội còn vé'),
              value: _activeOnly,
              onChanged: (v) => setState(() => _activeOnly = v),
            ),
            DropdownButtonFormField<String>(
              initialValue: _sort,
              isExpanded: true,
              key: const Key('results-sort'),
              decoration: const InputDecoration(labelText: 'Sắp xếp'),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Tên đội')),
                DropdownMenuItem(value: 'wins', child: Text('Số trận thắng')),
              ],
              onChanged: (v) => setState(() => _sort = v!),
            ),
            const SizedBox(height: 24),
            if (results.isEmpty)
              Text(
                total == 0 ? 'Chưa có đội đăng ký.' : 'Không có đội phù hợp.',
              ),
            for (final r in results) ...[
              Text(
                r.team,
                key: Key('result-team-${r.ticketId}'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('${r.ticketId}${r.cancelled ? ' · Đã hủy vé' : ''}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Đã đấu: ${r.played}'),
                  Text('Thắng: ${r.wins}'),
                  Text('Thua: ${r.losses}'),
                  Text('Điểm ghi: ${r.scored}'),
                  Text('Điểm nhận: ${r.conceded}'),
                  Text(
                    'Hiệu số: ${r.difference > 0 ? '+' : ''}${r.difference}',
                  ),
                ],
              ),
              const Divider(height: 32),
            ],
          ],
        ),
      );
    },
  );
}
