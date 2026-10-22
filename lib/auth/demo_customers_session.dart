part of 'demo_session.dart';

typedef DemoCustomer = ({
  String id,
  String name,
  String phone,
  int count,
  int paid,
  int cancelled,
});

extension DemoCustomersSession on DemoSession {
  List<DemoCustomer> get venueCustomers {
    _requireManager();
    final ids = managedAttendance.map((r) => r.owner).toSet();
    final result = <DemoCustomer>[];
    for (final id in ids) {
      final records = managedAttendance.where((r) => r.owner == id).toList();
      final latest = records.last;
      final b = _bookings.where((b) => b.id == latest.id).firstOrNull;
      final p = _participations.where((p) => p.id == latest.id).firstOrNull;
      final paid = records
          .where((r) => _payments[r.id]?.state == DemoPaymentState.approved)
          .fold<int>(0, (sum, r) => sum + r.total);
      result.add((
        id: id,
        name: b?.contact ?? p!.contact,
        phone: b?.phone ?? p!.phone,
        count: records.length,
        paid: paid,
        cancelled: records.where((r) => r.cancelled).length,
      ));
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(result);
  }

  List<DemoWorkflowRecord> customerRecords(String id) {
    _requireManager();
    if (!venueCustomers.any((c) => c.id == id)) {
      throw StateError('Không có khách hàng tại sân demo.');
    }
    return List.unmodifiable(
      managedAttendance.where((r) => r.owner == id).toList().reversed,
    );
  }
}
