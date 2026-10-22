import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_facilities.dart';
import '../demo/demo_finance.dart';
import '../widgets/design.dart';
import 'owner_management_widgets.dart';
import 'facilities_screen.dart';
import 'finance_screen.dart';
import 'demo_account_screens.dart';
import 'facility_document_screen.dart';

String _submittedAt(DateTime time) =>
    '${bookingDate(time)} · ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class OwnerPendingFacilitiesScreen extends StatelessWidget {
  const OwnerPendingFacilitiesScreen({super.key, required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final allowed = session.role == DemoRole.owner && session.user != null;
      final pending = allowed
          ? session.ownerEditableFacilities
                .where((f) => f.state == 'pending')
                .toList()
          : <DemoFacility>[];
      if (pending.length == 1) {
        return FacilityPendingScreen(
          session: session,
          facility: pending.single,
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: OwnerBar(
          title: 'Chờ duyệt',
          subtitle: 'Hồ sơ cơ sở',
          large: ownerLarge(context),
        ),
        bottomNavigationBar: allowed ? const OwnerNavigation() : null,
        body: !allowed
            ? const Center(child: Text('Chưa có quyền truy cập.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FinanceSaveNotice(session: session),
                  if (pending.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Chưa có hồ sơ sân đang chờ duyệt.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ownerButton(
                      'Về Sân của tôi',
                      () => ownerOpen(
                        context,
                        FacilitiesScreen(session: session),
                      ),
                      filled: true,
                    ),
                  ],
                  for (final f in pending)
                    OwnerCard(
                      child: ListTile(
                        key: Key('owner-pending-facility-${f.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(f.draft.name),
                        subtitle: Text(
                          '${f.id} · ${f.draft.courtCount} sân\n${_submittedAt(f.updated)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => ownerOpen(
                          context,
                          FacilityPendingScreen(session: session, facility: f),
                        ),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

class FacilityPendingScreen extends StatelessWidget {
  const FacilityPendingScreen({
    super.key,
    required this.session,
    required this.facility,
  });
  final DemoSession session;
  final DemoFacility facility;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final f = facility;
      if (session.role != DemoRole.owner || !session.canManageFacility(f)) {
        return Scaffold(
          appBar: OwnerBar(
            title: 'Hồ sơ sân',
            subtitle: '',
            large: ownerLarge(context),
          ),
          body: const Center(child: Text('Chưa có quyền truy cập.')),
        );
      }
      if (f.state != 'pending') {
        return FacilityDetailScreen(session: session, facility: f);
      }
      final p = f.draft;
      void edit() =>
          ownerOpen(context, FacilityFormScreen(session: session, facility: f));
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: OwnerBar(
          title: 'Chờ duyệt',
          subtitle: 'Hồ sơ cơ sở · ${f.id}',
          large: ownerLarge(context),
          icon: Icons.description_outlined,
          onAction: () => ownerOpen(
            context,
            FacilityDocumentScreen(
              session: session,
              encoded: p.legalProof,
              actor: session.user!.identifier,
              facility: f,
            ),
          ),
        ),
        bottomNavigationBar: const OwnerNavigation(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: session),
            const SizedBox(height: 2),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF5E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFF94610E),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hồ sơ sân đang chờ duyệt',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'SportMatch đã nhận yêu cầu của bạn. Theo dõi kết quả tại mục Chờ duyệt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            const Center(child: OwnerBadge('CHỜ DUYỆT', warning: true)),
            const SizedBox(height: 12),
            OwnerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (p.photo.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 2.35,
                        child: Image.memory(
                          decodeProof(p.photo),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${p.address}, ${p.district}, ${p.city}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  ownerLine('Số sân', '${p.courtCount} sân · ${p.sport}'),
                  ownerLine('Đã gửi', _submittedAt(f.updated)),
                ],
              ),
            ),
            OwnerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tiến trình duyệt',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _step(
                    Icons.check_circle_outline,
                    'Đã gửi hồ sơ',
                    _submittedAt(f.updated),
                    AppColors.green,
                  ),
                  const SizedBox(height: 12),
                  _step(
                    Icons.schedule,
                    'Chờ kiểm tra thông tin',
                    'Thông tin bổ sung sẽ được gửi lại để kiểm tra.',
                    const Color(0xFF94610E),
                  ),
                  const SizedBox(height: 12),
                  _step(
                    Icons.radio_button_unchecked,
                    'Hiển thị trên SportMatch',
                    'Sau khi hồ sơ được phê duyệt',
                    AppColors.faint,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 17,
                    color: Color(0xFF94610E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.published == null && !session.isPrimaryFacility(f)
                          ? 'Cơ sở chưa hiển thị với người chơi và chưa nhận lịch đặt trong thời gian chờ duyệt.'
                          : 'Thông tin đang hoạt động được giữ nguyên trong thời gian duyệt thay đổi.',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94610E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ownerButton(
              'Về Sân của tôi',
              () => Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FacilitiesScreen(session: session),
                ),
              ),
              key: const Key('facility-pending-my-facilities'),
              filled: true,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('facility-edit'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: edit,
              child: const Text(
                'Chỉnh sửa hồ sơ đã gửi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ownerOpen(context, SupportScreen(session: session)),
              child: const Text(
                'Cần hỗ trợ? Liên hệ SportMatch',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _step(IconData icon, String title, String subtitle, Color color) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      );
}
