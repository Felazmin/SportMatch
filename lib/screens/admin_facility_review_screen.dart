import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_facilities.dart';
import '../demo/demo_finance.dart';
import '../widgets/design.dart';
import 'admin_account_screen.dart';
import 'admin_review_widgets.dart';
import 'facilities_screen.dart';
import 'finance_screen.dart';
import 'owner_verification_screen.dart';

class AdminFacilityReviewScreen extends StatefulWidget {
  const AdminFacilityReviewScreen({
    super.key,
    required this.session,
    required this.facility,
  });
  final DemoSession session;
  final DemoFacility facility;
  @override
  State<AdminFacilityReviewScreen> createState() =>
      _AdminFacilityReviewScreenState();
}

class _AdminFacilityReviewScreenState extends State<AdminFacilityReviewScreen> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  bool get _allowed =>
      widget.session.user != null &&
      widget.session.role == DemoRole.admin &&
      widget.session.canManageFacility(widget.facility);
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    if (_busy || !_allowed) return;
    final s = widget.session, f = widget.facility;
    final actor = s.user!.identifier,
        revision = f.revision,
        reason = _reason.text.trim();
    if (reason.length > 300 || decision != 'approved' && reason.length < 5) {
      setState(
        () => _error =
            'Nhập lý do từ 5 đến 300 ký tự khi yêu cầu bổ sung hoặc từ chối.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await financeConfirm(
        context,
        '${adminDecision(decision)}?',
        '${f.draft.name} · ${f.id}\n${f.draft.courtCount} sân · Phiên bản $revision\nNgười xử lý: $actor\n${reason.isEmpty ? 'Không kèm lý do.' : 'Lý do: $reason'}\n${decision == 'approved' ? 'Công bố hồ sơ cơ sở này.' : 'Không công bố bản hồ sơ đang chờ duyệt.'}',
      );
      if (!mounted || !confirmed) return;
      if (!_allowed || s.user?.identifier != actor) {
        throw StateError('Phiên quản trị đã thay đổi. Mở lại hồ sơ.');
      }
      s.reviewFacility(
        f,
        approve: decision == 'approved',
        reject: decision == 'rejected',
        note: reason,
        expectedRevision: revision,
      );
      final saved = await s.flush();
      if (mounted && _allowed) {
        setState(
          () => _error = saved ? null : 'Quyết định chưa lưu được. Thử lưu lại trước khi đóng ứng dụng.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${adminDecision(decision)} · ${f.id}')),
        );
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa xử lý được hồ sơ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5)),
  );

  Widget _photo(String encoded) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: AspectRatio(
      aspectRatio: 1.8,
      child: encoded.isEmpty
          ? const ColoredBox(
              color: AppColors.background,
              child: Center(
                child: Icon(Icons.image_outlined, color: AppColors.faint),
              ),
            )
          : Image.memory(
              decodeProof(encoded),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session, f = widget.facility;
      if (!_allowed) {
        return Scaffold(
          appBar: financeBar('Duyệt sân mới'),
          body: const Center(child: Text('Chỉ Admin được truy cập hồ sơ này.')),
        );
      }
      final p = f.draft, verification = s.ownerVerification;
      final audit = s.operationAudit
          .where(
            (e) =>
                e.subject == f.id ||
                e.subject.isEmpty &&
                    RegExp(
                      '(?:^|[^A-Za-z0-9])${RegExp.escape(f.id)}(?:\$|[^A-Za-z0-9])',
                    ).hasMatch(e.action),
          )
          .toList();
      final overdue =
          f.state == 'pending' && s.now.difference(f.updated).inHours >= 48;
      String hour(int h) => '${h.toString().padLeft(2, '0')}:00';
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: adminReviewBar(
          context,
          'Duyệt sân mới',
          'Quản trị viên · ${f.id}',
          onNotifications: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminAccountScreen(session: s),
            ),
          ),
        ),
        bottomNavigationBar: const AdminReviewNavigation(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            AdminReviewNote(
              '${f.label}${overdue ? ' · Quá hạn' : ''}\nCập nhật ${adminTime(f.updated)}. ${f.state == 'pending' ? 'Bản hồ sơ đang chờ duyệt chưa được công bố. ${f.published == null ? 'Chưa nhận đặt lịch.' : 'Thông tin đã duyệt trước đó được giữ nguyên.'}' : 'Hồ sơ đã được xử lý.'}',
              warning: f.state != 'approved',
            ),
            AdminReviewCard(
              children: [
                _photo(p.photo),
                const SizedBox(height: 14),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${f.id} · ${f.label}',
                    key: const Key('facility-status'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF855200),
                    ),
                  ),
                ),
                _line('${p.address}, ${p.district}, ${p.city}'),
                if (p.description.isNotEmpty) _line(p.description),
                _line('Liên hệ: ${p.phone}'),
                _line('Môn thể thao: ${p.sport}'),
                _line(
                  'Giờ hoạt động: ${hour(p.openHour)} – ${hour(p.closeHour)} · Hằng ngày',
                ),
              ],
            ),
            AdminReviewCard(
              title: p.ownerName,
              children: [
                _line('Người gửi: ${f.owner}'),
                Text(
                  verification?.label ?? 'Chưa có hồ sơ xác minh chủ sân',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.darkGreen,
                  ),
                ),
                _line(
                  '${s.managedFacilities.where((v) => v.owner == f.owner).length} cơ sở đã đăng ký · ${s.managedFacilities.where((v) => v.owner == f.owner && v.published != null && !v.suspended).length} cơ sở đang công bố',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => OwnerVerificationScreen(session: s),
                      ),
                    ),
                    child: const Text('Xem hồ sơ người gửi →'),
                  ),
                ),
              ],
            ),
            AdminReviewCard(
              title: 'Thông số & sân con',
              children: [
                _line('Số sân: ${p.courtCount} sân'),
                if (f.sourceVenueId.isNotEmpty)
                  _line('Địa điểm OSM liên kết: ${f.sourceVenueId}'),
                if (p.receivingAccount case final account?)
                  _line(
                    'Nhận tiền mô phỏng: ${account.bank} · ${account.holder} · ${account.masked}. Không chuyển tiền thật.',
                  ),
                _line(
                  'Loại sân: ${p.courtTypeId.isEmpty ? p.sport : s.courtTypeName(p.courtTypeId)}',
                ),
                _line(
                  'Kích thước, mặt sân, chiếu sáng: Chưa có thông số riêng trong hồ sơ.',
                ),
                const Text(
                  'Số sân và giá thuê lấy từ hồ sơ chủ sân gửi. Không tạo loại sân mới khi phê duyệt cơ sở.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
            AdminReviewCard(
              title: 'Bảng giá đề xuất',
              children: [
                Text(
                  '${bookingMoney(p.baseRate)} / giờ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _line(
                  '${hour(p.openHour)} – ${hour(p.closeHour)} · Giá cơ bản trong hồ sơ',
                ),
                _line(
                  p.cancelPolicy.isEmpty
                      ? 'Chưa có mô tả chính sách hủy lịch.'
                      : p.cancelPolicy,
                ),
              ],
            ),
            AdminReviewCard(
              title: 'Hình ảnh & tiện ích',
              children: [
                _photo(p.photo),
                const SizedBox(height: 10),
                const Text(
                  'Ảnh cơ sở do chủ sân gửi',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in p.amenities)
                      Chip(
                        label: Text(a, style: const TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
                if (p.amenities.isEmpty)
                  const Text('Chưa có tiện ích được khai báo.'),
              ],
            ),
            AdminReviewCard(
              title: 'Giấy tờ & checklist',
              children: [
                facilityLegalDocument(s, f),
                const SizedBox(height: 12),
                for (final check in <(bool, String)>[
                  (
                    verification?.state == 'verified',
                    'Chủ sân đã được xác minh',
                  ),
                  (p.address.isNotEmpty, 'Đã khai báo địa chỉ cơ sở'),
                  (p.photo.isNotEmpty, 'Đã gửi ảnh cơ sở'),
                  (p.legalProof.isNotEmpty, 'Đã gửi giấy tờ'),
                  (
                    p.cancelPolicy.isNotEmpty,
                    'Đã khai báo chính sách hủy lịch',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          check.$1
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: 15,
                          color: check.$1 ? AppColors.green : AppColors.faint,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            check.$2,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'Danh sách chỉ phản ánh dữ liệu đã gửi, không thay thế việc đối chiếu giấy tờ. Bản demo không xác minh pháp lý thực tế.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
            AdminReviewCard(
              title: 'Lịch sử xử lý',
              children: [
                if (audit.isEmpty) const Text('Chưa có nhật ký xử lý.'),
                for (final e in audit) ...[
                  _line('${e.actor} · ${e.action}\n${adminTime(e.created)}'),
                  if (e.note.isNotEmpty) _line('Lý do: ${e.note}'),
                ],
              ],
            ),
            AdminReviewCard(
              title: 'Quyết định kiểm duyệt',
              children: [
                if (f.state == 'pending') ...[
                  const Text(
                    'Lý do xử lý *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('facility-review-reason'),
                    controller: _reason,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      hintText: 'Nhập lý do từ chối hoặc nội dung cần bổ sung…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  _line(
                    'Bắt buộc khi từ chối hoặc yêu cầu bổ sung. Không được sửa thông tin do người gửi cung cấp.',
                  ),
                  _line('Người xử lý: ${s.user!.name} · ${s.user!.identifier}'),
                  const AdminReviewNote(
                    'Bạn sẽ xem lại quyết định trước khi xác nhận. Kết quả và lý do được lưu vào nhật ký và hiển thị trong hồ sơ chủ sân.',
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      key: const Key('facility-error'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  FilledButton(
                    key: const Key('facility-approve'),
                    onPressed: _busy ? null : () => _decide('approved'),
                    child: Text('Phê duyệt cơ sở & ${p.courtCount} sân'),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actions = [
                        OutlinedButton(
                          key: const Key('facility-reject'),
                          onPressed: _busy ? null : () => _decide('supplement'),
                          child: const Text('Yêu cầu bổ sung'),
                        ),
                        TextButton(
                          key: const Key('facility-decline'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: const Color(0xFFFFEEEE),
                          ),
                          onPressed: _busy ? null : () => _decide('rejected'),
                          child: const Text('Từ chối'),
                        ),
                      ];
                      return MediaQuery.textScalerOf(context).scale(1) > 1.4
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: actions,
                            )
                          : Row(
                              children: [
                                Expanded(child: actions.first),
                                const SizedBox(width: 8),
                                Expanded(child: actions.last),
                              ],
                            );
                    },
                  ),
                ] else ...[
                  Text(
                    f.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (f.note.isNotEmpty) _line(f.note),
                  if (_error != null)
                    Text(
                      _error!,
                      key: const Key('facility-error'),
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );
}
