import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../demo/demo_facilities.dart';
import '../demo/demo_cancellation_policy.dart';
import 'finance_screen.dart';

class CancellationPolicyScreen extends StatefulWidget {
  const CancellationPolicyScreen({
    super.key,
    required this.session,
    this.facility,
  });
  final DemoSession session;
  final DemoFacility? facility;
  @override
  State<CancellationPolicyScreen> createState() =>
      _CancellationPolicyScreenState();
}

class _CancellationPolicyScreenState extends State<CancellationPolicyScreen> {
  final _form = GlobalKey<FormState>();
  late final _actor = widget.session.user?.identifier;
  late int _revision;
  @override
  void initState() {
    super.initState();
    _revision =
        widget.facility?.revision ??
        (widget.session.initialized
            ? widget.session.primaryCancellationRevision
            : 0);
  }

  late final _policy =
      widget.facility?.draft.cancellationPolicy ??
      (widget.session.initialized
          ? widget.session.primaryCancellationPolicy
          : const CancellationPolicy.standard());
  late final _fields = <String, TextEditingController>{
    'threshold': TextEditingController(text: '${_policy.thresholdHours}'),
    'early': TextEditingController(text: '${_policy.earlyPercent}'),
    'late': TextEditingController(text: '${_policy.latePercent}'),
    'minimum': TextEditingController(text: '${_policy.minimumHours}'),
    'password': TextEditingController(),
  };
  bool _busy = false, _committed = false;
  String? _error;
  bool get _allowed =>
      widget.session.initialized &&
      widget.session.user?.identifier == _actor &&
      (widget.facility == null
          ? widget.session.role == DemoRole.admin
          : widget.session.role == DemoRole.owner &&
                widget.session.canManageFacility(widget.facility!) &&
                widget.facility!.state != 'pending');
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_allowed || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = widget.session, f = widget.facility;
      if (_committed) {
        if (_revision != (f?.revision ?? s.primaryCancellationRevision)) {
          throw StateError('Hồ sơ đã thay đổi. Mở lại màn hình.');
        }
        await s.retrySave();
      } else {
        final policy = CancellationPolicy(
          thresholdHours: int.parse(_fields['threshold']!.text),
          earlyPercent: int.parse(_fields['early']!.text),
          latePercent: int.parse(_fields['late']!.text),
          minimumHours: int.parse(_fields['minimum']!.text),
        );
        if (f == null) {
          s.setPrimaryCancellationPolicy(
            policy,
            expectedRevision: _revision,
            password: _fields['password']!.text,
          );
        } else {
          s.saveFacility(
            FacilityProfile.fromJson({
              ...f.draft.toJson(),
              'cancellationPolicy': policy.toJson(),
            }),
            facility: f,
            expectedRevision: _revision,
          );
        }
        _revision = f?.revision ?? s.primaryCancellationRevision;
        _committed = true;
      }
      if (!await s.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Thử lại.');
      }
      if (mounted && _allowed) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Mốc giờ cần 1–168; tỷ lệ hoàn muộn không lớn hơn hoàn sớm.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _number(String id, String label, int max, {int min = 0}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextFormField(
          key: Key('policy-$id'),
          controller: _fields[id],
          enabled: !_busy && !_committed,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 3,
          decoration: InputDecoration(hintText: '$min–$max'),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < min || n > max ? '$min–$max' : null;
          },
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => Scaffold(
      appBar: financeBar('Chính sách hủy'),
      body: !_allowed
          ? const Center(child: Text('Chưa có quyền truy cập.'))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  FinanceSaveNotice(session: widget.session),
                  Text(
                    widget.facility?.draft.name ?? 'Sân chính',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _number('threshold', 'Mốc hoàn sớm (giờ)', 168, min: 1),
                  _number('early', 'Hoàn sớm (%)', 100),
                  _number('late', 'Hoàn muộn (%)', 100),
                  _number(
                    'minimum',
                    'Hạn nhận yêu cầu trước giờ chơi (giờ)',
                    168,
                  ),
                  if (widget.facility == null)
                    TextFormField(
                      key: const Key('policy-password'),
                      controller: _fields['password'],
                      obscureText: true,
                      enabled: !_busy && !_committed,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu Admin',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Nhập mật khẩu xác nhận'
                          : null,
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      key: const Key('policy-error'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('policy-save'),
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _committed
                          ? 'Thử lưu lại'
                          : widget.facility == null
                          ? 'Lưu chính sách'
                          : 'Lưu chính sách vào nháp',
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
