import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_events.dart';
import '../demo/demo_matches.dart';
import '../venues/venue_catalog.dart';
import 'finance_screen.dart';
import 'tournament_results_screen.dart';
import 'event_courts_screen.dart';

String _matchTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  bool _busy = false;
  String? _error;
  bool _own = false;
  String _state = 'all';
  String _query = '';
  int _courtFilter = 0;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _change(DemoMatch m, bool cancel, {bool correct = false}) async {
    final s = widget.session;
    final actor = s.user?.identifier;
    String? reason;
    (int, int)? scores;
    if (cancel) {
      reason = await financeText(context, 'Lý do hủy trận');
      if (reason == null || !mounted) return;
    } else {
      if (correct) {
        reason = await financeText(context, 'Lý do sửa kết quả');
        if (reason == null || !mounted) return;
      }
      if (s.user?.identifier != actor) {
        setState(() => _error = 'Tài khoản đã thay đổi. Mở lại hồ sơ.');
        return;
      }
      scores = await showDialog<(int, int)>(
        context: context,
        builder: (_) => _ScoreDialog(
          first: s.tournamentTeam(m.first),
          second: s.tournamentTeam(m.second),
          firstScore: correct ? m.firstScore : null,
          secondScore: correct ? m.secondScore : null,
        ),
      );
      if (scores == null) return;
    }
    if (!mounted ||
        !await financeConfirm(
          context,
          cancel
              ? 'Hủy trận đấu?'
              : correct
              ? 'Xác nhận sửa kết quả?'
              : 'Chốt kết quả trận?',
          cancel ? 'Chỉ hủy lịch trận, không hủy vé hoặc hoàn phí đăng ký.' : 'Chỉ Admin có thể sửa điểm đã chốt, kèm lý do và nhật ký thao tác.',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (s.user?.identifier != actor) {
        throw StateError('Tài khoản đã thay đổi. Mở lại hồ sơ.');
      }
      if (cancel) {
        s.cancelTournamentMatch(m.id, m.revision, reason!);
      } else {
        if (correct) {
          s.correctTournamentResult(
            m.id,
            m.revision,
            scores!.$1,
            scores.$2,
            reason!,
          );
        } else {
          s.finishTournamentMatch(m.id, m.revision, scores!.$1, scores.$2);
        }
      }
      if (!await s.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
    } on StateError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      List<DemoMatch> matches;
      try {
        matches = s.tournamentMatches(widget.event.id, widget.start);
      } on StateError {
        return Scaffold(
          appBar: financeBar('Lịch đấu & kết quả'),
          body: const Center(
            child: Text('Cần tài khoản quản lý hoặc vé của giải này.'),
          ),
        );
      }
      final manager = s.role != DemoRole.player;
      if (!manager && _own) {
        matches = s.ownTournamentMatches(widget.event.id, widget.start);
      }
      matches = matches
          .where(
            (m) =>
                (_state == 'all' || m.state == _state) &&
                (_courtFilter == 0 || m.court == _courtFilter) &&
                venueSearchText(
                  '${m.id} ${s.tournamentTeam(m.first)} ${s.tournamentTeam(m.second)}',
                ).contains(venueSearchText(_query)),
          )
          .toList();
      return Scaffold(
        appBar: financeBar('Lịch đấu & kết quả'),
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
            if (manager && widget.start.isAfter(s.now))
              OutlinedButton.icon(
                key: const Key('tournament-allocate-courts'),
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('Phân sân hoạt động'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventCourtsScreen(
                            session: s,
                            event: widget.event,
                            start: widget.start,
                          ),
                        ),
                      ),
              ),
            if (manager)
              FilledButton.icon(
                key: const Key('match-add'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TournamentMatchFormScreen(
                            session: s,
                            event: widget.event,
                            start: widget.start,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Xếp trận'),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            OutlinedButton.icon(
              key: const Key('tournament-results'),
              icon: const Icon(Icons.leaderboard_outlined),
              label: const Text('Kết quả các đội'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentResultsScreen(
                    session: s,
                    event: widget.event,
                    start: widget.start,
                  ),
                ),
              ),
            ),
            if (!manager)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('matches-all-teams'),
                    label: const Text('Tất cả đội'),
                    selected: !_own,
                    onSelected: (_) => setState(() => _own = false),
                  ),
                  ChoiceChip(
                    key: const Key('matches-own-team'),
                    label: const Text('Đội tôi'),
                    selected: _own,
                    onSelected: (_) => setState(() => _own = true),
                  ),
                ],
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in const {
                  'all': 'Tất cả trận',
                  'scheduled': 'Chưa chốt',
                  'completed': 'Có kết quả',
                  'cancelled': 'Đã hủy',
                }.entries)
                  ChoiceChip(
                    key: Key('matches-state-${e.key}'),
                    label: Text(e.value),
                    selected: _state == e.key,
                    onSelected: (_) => setState(() => _state = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('matches-search'),
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Tìm đội hoặc mã trận',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('matches-search-clear'),
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
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('matches-court'),
              initialValue: _courtFilter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sân thi đấu'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Tất cả sân')),
                for (var c = 1; c <= 3; c++)
                  DropdownMenuItem(value: c, child: Text('Sân $c')),
              ],
              onChanged: (v) => setState(() => _courtFilter = v!),
            ),
            if (matches.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Không có trận phù hợp.'),
              ),
            for (final m in matches) ...[
              const Divider(height: 32),
              Text(
                '${m.id} · ${m.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${_matchTime(m.start)}–${_matchTime(m.end)} · Sân ${m.court}',
              ),
              Text(s.tournamentTeam(m.first)),
              Text(s.tournamentTeam(m.second)),
              if (m.state == 'completed')
                Text(
                  '${m.firstScore} – ${m.secondScore}',
                  key: Key('match-score-${m.id}'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (m.note.isNotEmpty) Text('Lý do: ${m.note}'),
              if (s.role == DemoRole.admin && m.state == 'completed')
                OutlinedButton.icon(
                  key: Key('match-correct-${m.id}'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Sửa điểm'),
                  onPressed: _busy
                      ? null
                      : () => _change(m, false, correct: true),
                ),
              if (manager && m.state == 'scheduled') ...[
                OutlinedButton.icon(
                  key: Key('match-reschedule-${m.id}'),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Đổi lịch'),
                  onPressed: _busy || !m.start.isAfter(s.now)
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TournamentMatchFormScreen(
                              session: s,
                              event: widget.event,
                              start: widget.start,
                              match: m,
                            ),
                          ),
                        ),
                ),
                OutlinedButton.icon(
                  key: Key('match-result-${m.id}'),
                  onPressed: _busy || s.now.isBefore(m.end)
                      ? null
                      : () => _change(m, false),
                  icon: const Icon(Icons.scoreboard_outlined),
                  label: const Text('Ghi kết quả'),
                ),
                TextButton.icon(
                  key: Key('match-cancel-${m.id}'),
                  onPressed: _busy ? null : () => _change(m, true),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Hủy trận'),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

class TournamentMatchFormScreen extends StatefulWidget {
  const TournamentMatchFormScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
    this.match,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  final DemoMatch? match;
  @override
  State<TournamentMatchFormScreen> createState() =>
      _TournamentMatchFormScreenState();
}

class _TournamentMatchFormScreenState extends State<TournamentMatchFormScreen> {
  String? _actor;
  @override
  void initState() {
    super.initState();
    _actor = widget.session.user?.identifier;
  }

  late String? _first = widget.match?.first, _second = widget.match?.second;
  late DateTime? _time = widget.match?.start;
  late int _court = widget.match?.court ?? 1;
  final _reason = TextEditingController();
  bool _busy = false, _committed = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.session.user?.identifier != _actor) {
        throw StateError('Tài khoản đã thay đổi. Mở lại hồ sơ.');
      }
      if (widget.match != null) {
        widget.session.rescheduleTournamentMatch(
          widget.match!.id,
          widget.match!.revision,
          _time ?? widget.start,
          _court,
          _reason.text,
        );
      } else {
        widget.session.scheduleTournamentMatch(
          first: _first ?? '',
          second: _second ?? '',
          start: _time ?? widget.start,
          court: _court,
        );
      }
      _committed = true;
      final saved = await widget.session.flush();
      if (!saved) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
      if (mounted && saved) Navigator.pop(context);
    } on StateError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Xếp trận'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final tickets = s.managedParticipations
          .where(
            (p) =>
                !p.cancelled &&
                p.eventId == widget.event.id &&
                p.start == widget.start,
          )
          .toList();
      final slots = <DateTime>[
        for (
          var t = widget.start;
          !t
              .add(const Duration(minutes: 30))
              .isAfter(widget.event.end(widget.start));
          t = t.add(const Duration(minutes: 30))
        )
          if (t.isAfter(s.now) || t == _time) t,
      ];
      final enabled = !_busy && !_committed;
      return Scaffold(
        appBar: financeBar(widget.match == null ? 'Xếp trận' : 'Đổi lịch trận'),
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
            if (widget.match != null) ...[
              Text(s.tournamentTeam(widget.match!.first)),
              Text(s.tournamentTeam(widget.match!.second)),
              const SizedBox(height: 16),
            ],
            for (final first
                in widget.match == null ? [true, false] : <bool>[]) ...[
              DropdownButtonFormField<String>(
                key: Key(first ? 'match-first' : 'match-second'),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: first ? 'Đội thứ nhất' : 'Đội thứ hai',
                ),
                items: [
                  for (final p in tickets)
                    DropdownMenuItem(value: p.id, child: Text(p.id)),
                ],
                onChanged: enabled
                    ? (v) => setState(() {
                        if (first) {
                          _first = v;
                        } else {
                          _second = v;
                        }
                      })
                    : null,
              ),
              if ((first ? _first : _second) != null)
                Text(s.tournamentTeam((first ? _first : _second)!)),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<DateTime>(
              key: const Key('match-time'),
              initialValue: _time,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Giờ đấu'),
              items: [
                for (final t in slots)
                  DropdownMenuItem(value: t, child: Text(_matchTime(t))),
              ],
              onChanged: enabled ? (v) => setState(() => _time = v) : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _court,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sân'),
              items: [
                for (var c = 1; c <= 3; c++)
                  DropdownMenuItem(value: c, child: Text('Sân $c')),
              ],
              onChanged: enabled ? (v) => setState(() => _court = v!) : null,
            ),
            const SizedBox(height: 24),
            if (widget.match != null)
              TextField(
                key: const Key('match-reschedule-reason'),
                controller: _reason,
                enabled: enabled,
                maxLength: 300,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Lý do đổi lịch'),
              ),
            if (tickets.length < 2)
              const Text('Cần ít nhất hai đội đăng ký còn hiệu lực.'),
            if (slots.isEmpty)
              const Text('Không còn giờ đấu tương lai trong giải này.'),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton.icon(
              key: const Key('match-save'),
              onPressed:
                  enabled &&
                      tickets.length >= 2 &&
                      _time != null &&
                      _first != null &&
                      _second != null
                  ? _save
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu lịch trận'),
            ),
            if (_committed)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Về lịch đấu'),
              ),
          ],
        ),
      );
    },
  );
}

class _ScoreDialog extends StatefulWidget {
  const _ScoreDialog({
    required this.first,
    required this.second,
    this.firstScore,
    this.secondScore,
  });
  final String first, second;
  final int? firstScore, secondScore;
  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  late final _a = TextEditingController(text: widget.firstScore?.toString());
  late final _b = TextEditingController(text: widget.secondScore?.toString());
  String? _error;
  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kết quả trận'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.first),
          const Text('Điểm đội thứ nhất'),
          TextField(
            key: const Key('match-score-first'),
            controller: _a,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Điểm'),
          ),
          const SizedBox(height: 16),
          Text(widget.second),
          const Text('Điểm đội thứ hai'),
          TextField(
            key: const Key('match-score-second'),
            controller: _b,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Điểm'),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        key: const Key('match-score-submit'),
        onPressed: () {
          final a = int.tryParse(_a.text), b = int.tryParse(_b.text);
          if (a == null ||
              b == null ||
              a < 0 ||
              b < 0 ||
              a > 99 ||
              b > 99 ||
              a == b) {
            setState(() => _error = 'Nhập điểm 0–99, không hòa.');
            return;
          }
          Navigator.pop(context, (a, b));
        },
        child: const Text('Tiếp tục'),
      ),
    ],
  );
}
