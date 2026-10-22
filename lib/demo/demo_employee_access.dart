const employeePermissions = {'schedule', 'attendance', 'onsite'};
const employeePermissionLabels = {
  'schedule': 'Xem lịch',
  'attendance': 'Điểm danh',
  'onsite': 'Thu tại sân',
};

class DemoEmployeeAccess {
  DemoEmployeeAccess({
    required this.password,
    required Set<String> permissions,
    required this.revision,
    Set<String> facilityIds = const {'*'},
  }) : permissions = Set.unmodifiable(permissions),
       facilityIds = Set.unmodifiable(facilityIds);
  final String password;
  final Set<String> permissions;
  final Set<String> facilityIds;
  final int revision;
  Map<String, Object?> toJson() => {
    'password': password,
    'permissions': permissions.toList(),
    'revision': revision,
    'facilityIds': facilityIds.toList(),
  };
  factory DemoEmployeeAccess.fromJson(Map<String, dynamic> j) {
    final a = DemoEmployeeAccess(
      password: j['password'] as String,
      permissions: (j['permissions'] as List).cast<String>().toSet(),
      revision: j['revision'] as int,
      facilityIds: (j['facilityIds'] as List? ?? ['*']).cast<String>().toSet(),
    );
    if (a.password.length < 8 ||
        a.facilityIds.isEmpty ||
        a.facilityIds.length > 21 ||
        (a.facilityIds.contains('*') && a.facilityIds.length != 1) ||
        a.facilityIds.any(
          (id) =>
              !['*', ''].contains(id) && !RegExp(r'^CS\d{4,}$').hasMatch(id),
        ) ||
        a.password.length > 128 ||
        a.revision < 1 ||
        a.permissions.any((p) => !employeePermissions.contains(p)) ||
        (a.permissions.any((p) => p != 'schedule') &&
            !a.permissions.contains('schedule'))) {
      throw const FormatException('Invalid employee access');
    }
    return a;
  }
}
