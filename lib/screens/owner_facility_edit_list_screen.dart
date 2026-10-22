import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_facilities.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'facilities_screen.dart';
import 'finance_screen.dart';
import 'owner_management_widgets.dart';

class OwnerFacilityEditListScreen extends StatefulWidget {
  const OwnerFacilityEditListScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<OwnerFacilityEditListScreen> createState() => _EditListState();
}

class _EditListState extends State<OwnerFacilityEditListScreen> {
  String _query = '';
  String _error = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPrimary();
    });
  }

  Future<void> _loadPrimary() async {
    final s = widget.session, actor = widget.session.user?.identifier;
    if (s.role != DemoRole.owner || actor != '__owner__') return;
    try {
      final data = await rootBundle.load('assets/figma/c0697.png');
      if (!mounted || s.user?.identifier != actor || s.role != DemoRole.owner) {
        return;
      }
      s.ensurePrimaryFacilityProfile(
        encodeProof(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
      if (!await s.flush() && mounted) {
        setState(
          () => _error =
              'Chưa lưu được hồ sơ sân chính. Thử lưu lại trước khi sửa.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hồ sơ sân chính.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final allowed = s.role == DemoRole.owner && s.user != null;
      final facilities = allowed ? s.ownerEditableFacilities : <DemoFacility>[];
      final visible = facilities
          .where(
            (f) => venueSearchText(
              '${f.draft.name} ${f.draft.address} ${f.draft.district}',
            ).contains(venueSearchText(_query)),
          )
          .toList();
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: OwnerBar(
          title: 'Chỉnh sửa sân',
          subtitle: '${facilities.length} cơ sở',
          large: ownerLarge(context),
        ),
        bottomNavigationBar: allowed ? const OwnerNavigation() : null,
        body: !allowed
            ? const Center(child: Text('Chưa có quyền truy cập.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FinanceSaveNotice(session: s),
                  if (_error.isNotEmpty)
                    Text(_error, style: const TextStyle(color: Colors.red)),
                  TextField(
                    key: const Key('owner-edit-search'),
                    decoration: const InputDecoration(
                      hintText: 'Tên hoặc địa chỉ sân',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Chưa có sân phù hợp.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (facilities.isEmpty)
                    ownerButton(
                      'Thêm sân',
                      () => ownerOpen(context, FacilityFormScreen(session: s)),
                      filled: true,
                    ),
                  for (final f in visible)
                    OwnerCard(
                      key: Key('owner-edit-card-${f.id}'),
                      padding: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (f.draft.photo.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: AspectRatio(
                                aspectRatio: 2.2,
                                child: Image.memory(
                                  decodeProof(f.draft.photo),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        f.draft.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: OwnerBadge(
                                        s.isPrimaryFacility(f)
                                            ? 'Sân chính · ${f.label}'
                                            : f.label,
                                        warning:
                                            f.state != 'approved' ||
                                            f.suspended,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${f.draft.address}, ${f.draft.district}, ${f.draft.city}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${f.draft.courtCount} sân · ${f.draft.sport} · ${f.draft.openHour.toString().padLeft(2, '0')}:00–${f.draft.closeHour.toString().padLeft(2, '0')}:00',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      '${bookingMoney(f.draft.baseRate)}/giờ',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.green,
                                      ),
                                    ),
                                    ownerButton(
                                      'Chỉnh sửa',
                                      () => ownerOpen(
                                        context,
                                        FacilityFormScreen(
                                          session: s,
                                          facility: f,
                                          editProfile: true,
                                        ),
                                      ),
                                      key: Key('owner-edit-facility-${f.id}'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );
    },
  );
}
