import '../booking/demo_booking.dart';

class CourtTariff {
  CourtTariff({
    required this.court,
    required this.weekend,
    required this.fromHour,
    required this.toHour,
    required this.rate,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.surcharge = 0,
  }) {
    if (court < 1 ||
        court > 3 ||
        fromHour < 6 ||
        toHour > 22 ||
        fromHour >= toHour ||
        rate < 10000 ||
        rate > 1000000 ||
        rate % 1000 != 0 ||
        effectiveFrom != bookingDay(effectiveFrom) ||
        surcharge < 0 ||
        surcharge > 100000 ||
        surcharge % 1000 != 0 ||
        rate + surcharge > 1000000 ||
        (effectiveUntil != null &&
            (effectiveUntil != bookingDay(effectiveUntil!) ||
                effectiveUntil!.isBefore(effectiveFrom)))) {
      throw const FormatException('Invalid tariff');
    }
  }
  final int court, fromHour, toHour, rate;
  final bool weekend;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final int surcharge;
  int get quotedRate => rate + surcharge;
  bool applies(int c, DateTime time) =>
      c == court &&
      (time.weekday >= 6) == weekend &&
      !bookingDay(time).isBefore(effectiveFrom) &&
      (effectiveUntil == null || !bookingDay(time).isAfter(effectiveUntil!)) &&
      time.hour >= fromHour &&
      time.hour < toHour;
  Map<String, Object?> toJson() => {
    'court': court,
    'weekend': weekend,
    'fromHour': fromHour,
    'toHour': toHour,
    'rate': rate,
    'effectiveFrom': effectiveFrom.toIso8601String(),
    'effectiveUntil': effectiveUntil?.toIso8601String(),
    'surcharge': surcharge,
  };
  factory CourtTariff.fromJson(Map<String, dynamic> j) => CourtTariff(
    court: j['court'] as int,
    weekend: j['weekend'] as bool,
    fromHour: j['fromHour'] as int,
    toHour: j['toHour'] as int,
    rate: j['rate'] as int,
    effectiveFrom: DateTime.parse(j['effectiveFrom'] as String),
    effectiveUntil: j['effectiveUntil'] == null
        ? null
        : DateTime.parse(j['effectiveUntil'] as String),
    surcharge: (j['surcharge'] ?? 0) as int,
  );
}

class CourtSettings {
  CourtSettings({
    required List<int> rates,
    required List<bool> enabled,
    List<CourtTariff> tariffs = const [],
  }) : rates = List.unmodifiable(rates),
       tariffs = List.unmodifiable(tariffs),
       enabled = List.unmodifiable(enabled) {
    if (rates.length != 3 ||
        enabled.length != 3 ||
        rates.any((r) => r < 10000 || r > 1000000 || r % 1000 != 0)) {
      throw const FormatException('Invalid court settings');
    }
    if (tariffs.length > 36) throw const FormatException('Too many tariffs');
    for (var i = 0; i < tariffs.length; i++) {
      for (var k = i + 1; k < tariffs.length; k++) {
        final a = tariffs[i], b = tariffs[k];
        if (a.court == b.court &&
            a.weekend == b.weekend &&
            (a.effectiveUntil == null ||
                !a.effectiveUntil!.isBefore(b.effectiveFrom)) &&
            (b.effectiveUntil == null ||
                !b.effectiveUntil!.isBefore(a.effectiveFrom)) &&
            a.fromHour < b.toHour &&
            b.fromHour < a.toHour) {
          throw const FormatException('Overlapping tariffs');
        }
      }
    }
  }
  factory CourtSettings.initial() => CourtSettings(
    rates: List.filled(3, DemoBooking.hourlyPrice),
    enabled: List.filled(3, true),
  );
  final List<int> rates;
  final List<bool> enabled;
  final List<CourtTariff> tariffs;
  int rateAt(int court, DateTime time) {
    if (court < 1 || court > 3) throw ArgumentError.value(court);
    for (final t in tariffs) {
      if (t.applies(court, time)) return t.quotedRate;
    }
    return rates[court - 1];
  }

  Map<String, Object?> toJson() => {
    'rates': rates,
    'enabled': enabled,
    'tariffs': tariffs.map((t) => t.toJson()).toList(),
  };
  factory CourtSettings.fromJson(Map<String, dynamic> j) => CourtSettings(
    rates: (j['rates'] as List).cast<int>(),
    enabled: (j['enabled'] as List).cast<bool>(),
    tariffs: ((j['tariffs'] ?? []) as List)
        .map((t) => CourtTariff.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

class DemoEmployee {
  const DemoEmployee({
    required this.id,
    required this.name,
    required this.phone,
    required this.job,
    required this.active,
  });
  final String id, name, phone, job;
  final bool active;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'job': job,
    'active': active,
  };
  factory DemoEmployee.fromJson(Map<String, dynamic> j) {
    final e = DemoEmployee(
      id: j['id'] as String,
      name: j['name'] as String,
      phone: j['phone'] as String,
      job: j['job'] as String,
      active: j['active'] as bool,
    );
    if (!RegExp(r'^NS\d{4,}$').hasMatch(e.id) ||
        e.name.trim().isEmpty ||
        e.name.length > 60 ||
        !RegExp(r'^0[35789]\d{8}$').hasMatch(e.phone) ||
        !['Lễ tân', 'Thu ngân', 'Điều phối'].contains(e.job)) {
      throw const FormatException('Invalid employee');
    }
    return e;
  }
}

class DemoAuditEntry {
  const DemoAuditEntry({
    required this.actor,
    required this.action,
    required this.created,
    this.subject = '',
    this.decision = '',
    this.note = '',
  });
  final String actor, action, subject, decision, note;
  final DateTime created;
  Map<String, Object?> toJson() => {
    'actor': actor,
    'action': action,
    'subject': subject,
    'decision': decision,
    'note': note,
    'created': created.toIso8601String(),
  };
  factory DemoAuditEntry.fromJson(Map<String, dynamic> j) {
    final e = DemoAuditEntry(
      actor: j['actor'] as String,
      action: j['action'] as String,
      subject: (j['subject'] ?? '') as String,
      decision: (j['decision'] ?? '') as String,
      note: (j['note'] ?? '') as String,
      created: DateTime.parse(j['created'] as String),
    );
    if ((!['__owner__', '__admin__', '__system__'].contains(e.actor) &&
            !RegExp(r'^NS\d{4,}$').hasMatch(e.actor) &&
            !RegExp(r'^0[35789]\d{8}$').hasMatch(e.actor) &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e.actor)) ||
        e.action.isEmpty ||
        e.action.length > 400 ||
        e.subject.length > 100 ||
        !['', 'approved', 'supplement', 'rejected'].contains(e.decision) ||
        e.note.length > 300) {
      throw const FormatException('Invalid audit record');
    }
    return e;
  }
}

class DemoOperations {
  DemoOperations();
  bool notifyRequests = true, notifyOverdue = true, weeklyReport = true;
  CourtSettings published = CourtSettings.initial();
  CourtSettings? draft;
  String reviewState = 'none';
  String reviewNote = '';
  int nextEmployee = 1;
  final List<DemoEmployee> employees = [];
  final Set<String> blocked = {};
  final Map<String, DemoAccessDecision> accessDecisions = {};
  final Set<String> hiddenPosts = {};
  final List<DemoAuditEntry> audit = [];
  Map<String, Object?> toJson() => {
    'notifyRequests': notifyRequests,
    'notifyOverdue': notifyOverdue,
    'weeklyReport': weeklyReport,
    'published': published.toJson(),
    'draft': draft?.toJson(),
    'reviewState': reviewState,
    'reviewNote': reviewNote,
    'nextEmployee': nextEmployee,
    'employees': employees.map((e) => e.toJson()).toList(),
    'blocked': blocked.toList(),
    'accessDecisions': {
      for (final e in accessDecisions.entries) e.key: e.value.toJson(),
    },
    'hiddenPosts': hiddenPosts.toList(),
    'audit': audit.map((e) => e.toJson()).toList(),
  };
  factory DemoOperations.fromJson(Map<String, dynamic> j) {
    final o = DemoOperations();
    o.notifyRequests = (j['notifyRequests'] ?? true) as bool;
    o.notifyOverdue = (j['notifyOverdue'] ?? true) as bool;
    o.weeklyReport = (j['weeklyReport'] ?? true) as bool;
    o.published = CourtSettings.fromJson(
      j['published'] as Map<String, dynamic>,
    );
    o.draft = j['draft'] == null
        ? null
        : CourtSettings.fromJson(j['draft'] as Map<String, dynamic>);
    o.reviewState = j['reviewState'] as String;
    o.reviewNote = j['reviewNote'] as String;
    o.nextEmployee = j['nextEmployee'] as int;
    o.employees.addAll(
      (j['employees'] as List).map(
        (e) => DemoEmployee.fromJson(e as Map<String, dynamic>),
      ),
    );
    o.blocked.addAll((j['blocked'] as List).cast<String>());
    for (final e
        in ((j['accessDecisions'] as Map<String, dynamic>?) ??
                <String, dynamic>{})
            .entries) {
      final d = DemoAccessDecision.fromJson(e.value as Map<String, dynamic>);
      if (d.blocked != o.blocked.contains(e.key)) {
        throw const FormatException('Access state mismatch');
      }
      o.accessDecisions[e.key] = d;
    }
    o.hiddenPosts.addAll((j['hiddenPosts'] as List).cast<String>());
    o.audit.addAll(
      (j['audit'] as List).map(
        (e) => DemoAuditEntry.fromJson(e as Map<String, dynamic>),
      ),
    );
    if (!['none', 'pending', 'approved', 'rejected'].contains(o.reviewState) ||
        ((o.reviewState == 'pending' || o.reviewState == 'rejected') !=
            (o.draft != null)) ||
        o.reviewNote.length > 300 ||
        (o.reviewState == 'rejected' && o.reviewNote.trim().length < 5) ||
        o.nextEmployee < 1 ||
        o.employees.length > 100 ||
        o.audit.length > 1000 ||
        o.employees.map((e) => e.id).toSet().length != o.employees.length ||
        o.employees.any(
          (e) => int.parse(e.id.substring(2)) >= o.nextEmployee,
        )) {
      throw const FormatException('Invalid operations snapshot');
    }
    return o;
  }
}

class DemoAccessDecision {
  const DemoAccessDecision({
    required this.blocked,
    required this.reason,
    required this.created,
    this.revision = 1,
  });
  final bool blocked;
  final String reason;
  final DateTime created;
  final int revision;
  Map<String, Object?> toJson() => {
    'blocked': blocked,
    'reason': reason,
    'created': created.toIso8601String(),
    'revision': revision,
  };
  factory DemoAccessDecision.fromJson(Map<String, dynamic> j) {
    final d = DemoAccessDecision(
      blocked: j['blocked'] as bool,
      reason: j['reason'] as String,
      created: DateTime.parse(j['created'] as String).toLocal(),
      revision: (j['revision'] ?? 1) as int,
    );
    if (d.revision < 1 || d.reason.trim().length < 5 || d.reason.length > 300) {
      throw const FormatException('Invalid access reason');
    }
    return d;
  }
}
