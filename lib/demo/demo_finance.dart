import 'dart:convert';
import 'dart:typed_data';

enum DemoRole { player, owner, admin }

enum DemoPaymentState { awaitingProof, pending, rejected, approved }

enum DemoCancellationState { none, requested, rejected, accepted }

enum DemoRefundState { none, pending, recorded }

enum DemoAttendance { pending, checkedIn, absent, completed }

enum DemoDisputeDecision { refund, uphold }

class DemoRefundDestination {
  const DemoRefundDestination.bank({
    required this.bank,
    required this.account,
    required this.holder,
  }) : qr = '';
  const DemoRefundDestination.qr(this.qr)
    : bank = '',
      account = '',
      holder = '';
  final String bank, account, holder, qr;
  void validate() {
    if (qr.isNotEmpty) {
      if (bank.isNotEmpty || account.isNotEmpty || holder.isNotEmpty) {
        throw const FormatException('Chỉ chọn một cách nhận hoàn tiền.');
      }
      decodeProof(qr);
    } else if (bank.trim().length < 2 ||
        bank.length > 60 ||
        !RegExp(r'^\d{6,19}$').hasMatch(account) ||
        holder.trim().length < 2 ||
        holder.length > 80) {
      throw const FormatException(
        'Kiểm tra ngân hàng, số tài khoản và tên chủ tài khoản.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'bank': bank,
    'account': account,
    'holder': holder,
    'qr': qr,
  };
  factory DemoRefundDestination.fromJson(Map<String, dynamic> data) {
    final destination = (data['qr'] as String).isNotEmpty
        ? DemoRefundDestination.qr(data['qr'] as String)
        : DemoRefundDestination.bank(
            bank: data['bank'] as String,
            account: data['account'] as String,
            holder: data['holder'] as String,
          );
    if (destination.qr.isNotEmpty &&
        ((data['bank'] as String).isNotEmpty ||
            (data['account'] as String).isNotEmpty ||
            (data['holder'] as String).isNotEmpty)) {
      throw const FormatException('Invalid refund destination');
    }
    destination.validate();
    return destination;
  }
}

class DemoBookingMessage {
  const DemoBookingMessage(this.text, this.created);
  final String text;
  final DateTime created;
  Map<String, Object?> toJson() => {
    'text': text,
    'created': created.toIso8601String(),
  };
  factory DemoBookingMessage.fromJson(Map<String, dynamic> data) {
    final message = DemoBookingMessage(
      data['text'] as String,
      DateTime.parse(data['created'] as String).toLocal(),
    );
    if (message.text.trim().length < 5 ||
        message.text.length > 500 ||
        message.created.year < 2020 ||
        message.created.year > 2100) {
      throw const FormatException('Invalid booking message');
    }
    return message;
  }
}

class DemoPayment {
  DemoPayment({required this.bookingId, required this.deadline});
  final String bookingId;
  final DateTime deadline;
  DemoPaymentState state = DemoPaymentState.awaitingProof;
  String proof = '';
  String draft = '';
  bool checkout = false;
  String studentDraft = '';
  String studentProof = '';
  String customerNote = '';
  String reference = '';
  String reviewNote = '';
  DemoCancellationState cancellation = DemoCancellationState.none;
  String cancellationReason = '';
  String cancellationNote = '';
  DemoRefundDestination? refundDestination;
  int? cancellationEstimate;
  List<DemoBookingMessage> customerMessages = const [];
  DemoRefundState refund = DemoRefundState.none;
  int? refundAmount;
  String refundReference = '';
  String refundProof = '';
  DateTime? cancellationRequestedAt;
  DateTime? refundRecordedAt;
  DateTime? receivedAt;
  bool atVenue = false;
  bool simulatedGateway = false;
  String gatewayMethod = '';
  bool expired(DateTime now) =>
      (state == DemoPaymentState.awaitingProof ||
          state == DemoPaymentState.rejected) &&
      !now.isBefore(deadline);
  String label(DateTime now) => expired(now)
      ? 'Hết hạn gửi minh chứng'
      : switch (state) {
          DemoPaymentState.awaitingProof => 'Chờ minh chứng',
          DemoPaymentState.pending => 'Chờ Chủ sân duyệt',
          DemoPaymentState.rejected => 'Cần gửi lại minh chứng',
          DemoPaymentState.approved => 'Đã xác nhận demo',
        };
  String get cancellationLabel => switch (cancellation) {
    DemoCancellationState.none => 'Chưa yêu cầu hủy',
    DemoCancellationState.requested => 'Chờ duyệt hủy',
    DemoCancellationState.rejected => 'Yêu cầu hủy bị từ chối',
    DemoCancellationState.accepted => 'Đã duyệt hủy',
  };
  String get refundLabel => switch (refund) {
    DemoRefundState.none => 'Không có khoản hoàn',
    DemoRefundState.pending => 'Chờ ghi nhận hoàn tiền demo',
    DemoRefundState.recorded => 'Đã ghi nhận hoàn tiền demo',
  };
  Map<String, Object?> toJson() => {
    'bookingId': bookingId,
    'deadline': deadline.toIso8601String(),
    'state': state.name,
    'proof': proof,
    'draft': draft,
    'checkout': checkout,
    'studentDraft': studentDraft,
    'studentProof': studentProof,
    'customerNote': customerNote,
    'reference': reference,
    'reviewNote': reviewNote,
    'cancellation': cancellation.name,
    'cancellationReason': cancellationReason,
    'cancellationNote': cancellationNote,
    'refundDestination': refundDestination?.toJson(),
    'cancellationEstimate': cancellationEstimate,
    'customerMessages': [
      for (final message in customerMessages) message.toJson(),
    ],
    'refund': refund.name,
    'refundAmount': refundAmount,
    'refundReference': refundReference,
    'refundProof': refundProof,
    'cancellationRequestedAt': cancellationRequestedAt?.toIso8601String(),
    'refundRecordedAt': refundRecordedAt?.toIso8601String(),
    'atVenue': atVenue,
    'simulatedGateway': simulatedGateway,
    'gatewayMethod': gatewayMethod,
    'receivedAt': receivedAt?.toIso8601String(),
  };
  factory DemoPayment.fromJson(Map<String, dynamic> data) {
    final p =
        DemoPayment(
            bookingId: data['bookingId'] as String,
            deadline: DateTime.parse(data['deadline'] as String).toLocal(),
          )
          ..state = DemoPaymentState.values.byName(data['state'] as String)
          ..proof = data['proof'] as String
          ..draft = data['draft'] as String
          ..checkout = (data['checkout'] ?? false) as bool
          ..studentDraft = (data['studentDraft'] ?? '') as String
          ..studentProof = (data['studentProof'] ?? '') as String
          ..customerNote = (data['customerNote'] ?? '') as String
          ..reference = data['reference'] as String
          ..reviewNote = data['reviewNote'] as String
          ..cancellation = DemoCancellationState.values.byName(
            data['cancellation'] as String,
          )
          ..cancellationReason = data['cancellationReason'] as String
          ..cancellationNote = data['cancellationNote'] as String
          ..refundDestination = data['refundDestination'] == null
              ? null
              : DemoRefundDestination.fromJson(
                  data['refundDestination'] as Map<String, dynamic>,
                )
          ..cancellationEstimate = data['cancellationEstimate'] as int?
          ..customerMessages = List.unmodifiable(
            (data['customerMessages'] as List<dynamic>? ?? []).map(
              (raw) => DemoBookingMessage.fromJson(raw as Map<String, dynamic>),
            ),
          )
          ..refund = DemoRefundState.values.byName(data['refund'] as String)
          ..refundAmount = data['refundAmount'] as int?
          ..refundReference = (data['refundReference'] ?? '') as String
          ..refundProof = (data['refundProof'] ?? '') as String
          ..cancellationRequestedAt = data['cancellationRequestedAt'] == null
              ? null
              : DateTime.parse(data['cancellationRequestedAt'] as String)
                    .toLocal()
          ..atVenue = (data['atVenue'] ?? false) as bool
          ..simulatedGateway = (data['simulatedGateway'] ?? false) as bool
          ..gatewayMethod = (data['gatewayMethod'] ?? '') as String
          ..receivedAt = data['receivedAt'] == null
              ? null
              : DateTime.parse(data['receivedAt'] as String).toLocal()
          ..refundRecordedAt = data['refundRecordedAt'] == null
              ? null
              : DateTime.parse(data['refundRecordedAt'] as String).toLocal();
    if ((p.simulatedGateway &&
            (!p.bookingId.startsWith('VE') ||
                p.state != DemoPaymentState.approved ||
                p.atVenue ||
                p.checkout ||
                p.proof.isNotEmpty ||
                p.draft.isNotEmpty ||
                p.receivedAt == null ||
                !['qr', 'wallet', 'bank'].contains(p.gatewayMethod) ||
                p.reference != 'DEMO-${p.bookingId}')) ||
        (!p.simulatedGateway && p.gatewayMethod.isNotEmpty) ||
        p.customerMessages.length > 20 ||
        (p.cancellationEstimate != null &&
            (p.cancellationEstimate! < 0 ||
                p.cancellation == DemoCancellationState.none)) ||
        (p.refundDestination != null &&
            p.cancellation == DemoCancellationState.none) ||
        p.customerNote.length > 300 ||
        (p.checkout &&
            p.state != DemoPaymentState.awaitingProof &&
            p.studentProof.isEmpty) ||
        !RegExp(r'^(NVH|VE)\d{4,}$').hasMatch(p.bookingId) ||
        (p.receivedAt != null &&
            (p.state != DemoPaymentState.approved ||
                p.receivedAt!.year < 2020 ||
                p.receivedAt!.year > 2100)) ||
        (p.refundAmount != null &&
            (p.refundAmount! < 0 || p.refund == DemoRefundState.none)) ||
        p.refundReference.length > 80 ||
        (p.refundProof.isNotEmpty && p.refundReference.trim().length < 3) ||
        (p.refundRecordedAt != null && p.refund != DemoRefundState.recorded) ||
        (p.cancellationRequestedAt != null &&
            p.cancellation == DemoCancellationState.none) ||
        (p.refundProof.isNotEmpty && p.refund != DemoRefundState.recorded) ||
        p.reference.length > 80 ||
        p.reviewNote.length > 300 ||
        p.cancellationReason.length > 300 ||
        p.cancellationNote.length > 300 ||
        (p.atVenue &&
            (p.state != DemoPaymentState.approved ||
                p.proof.isNotEmpty ||
                p.draft.isNotEmpty ||
                !p.bookingId.startsWith('NVH'))) ||
        (p.atVenue && p.reference.trim().length < 3) ||
        (!p.atVenue &&
            !p.simulatedGateway &&
            p.state != DemoPaymentState.awaitingProof &&
            (p.proof.isEmpty || p.reference.trim().length < 3)) ||
        (p.state == DemoPaymentState.rejected &&
            p.reviewNote.trim().length < 5) ||
        (p.cancellation != DemoCancellationState.none &&
            p.cancellationReason.trim().length < 5) ||
        (p.cancellation == DemoCancellationState.rejected &&
            p.cancellationNote.trim().length < 5) ||
        (p.refund != DemoRefundState.none &&
            (p.state != DemoPaymentState.approved ||
                p.cancellation != DemoCancellationState.accepted))) {
      throw const FormatException('Invalid payment');
    }
    for (final image in [
      p.proof,
      p.draft,
      p.studentDraft,
      p.studentProof,
      p.refundProof,
    ].where((s) => s.isNotEmpty)) {
      decodeProof(image);
    }
    return p;
  }
}

const maxProofBytes = 400000;
String encodeProof(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > maxProofBytes) {
    throw const FormatException('Ảnh cần nhỏ hơn 400KB.');
  }
  final png =
      bytes.length >= 8 &&
      [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((e) => bytes[e.key] == e.value);
  final jpeg =
      bytes.length >= 4 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  if (!png && !jpeg) throw const FormatException('Chọn ảnh PNG hoặc JPEG.');
  return base64Encode(bytes);
}

Uint8List decodeProof(String value) {
  if (value.length > (maxProofBytes * 4 ~/ 3 + 8)) {
    throw const FormatException('Proof too large');
  }
  final bytes = base64Decode(value);
  encodeProof(bytes);
  return bytes;
}

class DemoDispute {
  DemoDispute({
    required this.id,
    required this.owner,
    required this.bookingId,
    required this.subject,
    required this.message,
    required this.created,
  });
  final String id;
  final String owner;
  final String bookingId;
  final String subject;
  final String message;
  final DateTime created;
  String response = '';
  String resolution = '';
  DemoDisputeDecision? decision;
  DateTime? closedAt;
  String evidence = '';
  String get label => closedAt != null
      ? 'Đã thực hiện · Đã đóng'
      : resolution.isNotEmpty
      ? 'Đã có kết quả Admin'
      : response.isNotEmpty
      ? 'Chủ sân đã phản hồi'
      : 'Chờ phản hồi';
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'bookingId': bookingId,
    'subject': subject,
    'message': message,
    'created': created.toIso8601String(),
    'response': response,
    'resolution': resolution,
    'decision': decision?.name,
    'closedAt': closedAt?.toIso8601String(),
    'evidence': evidence,
  };
  factory DemoDispute.fromJson(Map<String, dynamic> data) {
    final d =
        DemoDispute(
            id: data['id'] as String,
            owner: data['owner'] as String,
            bookingId: data['bookingId'] as String,
            subject: data['subject'] as String,
            message: data['message'] as String,
            created: DateTime.parse(data['created'] as String).toLocal(),
          )
          ..response = data['response'] as String
          ..resolution = data['resolution'] as String
          ..decision = data['decision'] == null
              ? null
              : DemoDisputeDecision.values.byName(data['decision'] as String)
          ..evidence = (data['evidence'] ?? '') as String
          ..closedAt = data['closedAt'] == null
              ? null
              : DateTime.parse(data['closedAt'] as String).toLocal();
    if (!RegExp(r'^KN\d{4,}$').hasMatch(d.id) ||
        (d.decision != null && d.resolution.isEmpty) ||
        (d.closedAt != null &&
            (d.decision == null || d.closedAt!.isBefore(d.created))) ||
        d.subject.trim().isEmpty ||
        d.subject.length > 80 ||
        d.message.trim().length < 10 ||
        d.message.length > 1000 ||
        [d.response, d.resolution].any(
          (s) => s.isNotEmpty && (s.trim().length < 10 || s.length > 1000),
        )) {
      throw const FormatException('Invalid dispute');
    }
    if (d.evidence.isNotEmpty) decodeProof(d.evidence);
    return d;
  }
}
