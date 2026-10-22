import 'package:diacritic/diacritic.dart';

import '../demo/demo_finance.dart' show decodeProof;
import 'demo_voice.dart';

const maxChatImagesPerAccount = 20;

class DemoChatContact {
  const DemoChatContact(this.id, this.name, this.initials, this.sport);
  final String id;
  final String name;
  final String initials;
  final String sport;
}

const demoChatContacts = [
  DemoChatContact('minh-phat', 'Minh Phát', 'MP', 'Cầu lông'),
  DemoChatContact('hoang-nam', 'Hoàng Nam (CLB Cầu Lông)', 'HN', 'Cầu lông'),
  DemoChatContact('van-duc', 'Văn Đức FC', 'VĐ', 'Bóng đá'),
  DemoChatContact('thuy-trang', 'Thùy Trang', 'TT', 'Cầu lông'),
  DemoChatContact('anh-tien', 'Anh Tiến Thể Thao', 'AT', 'Cầu lông'),
];

class DemoChatMessage {
  const DemoChatMessage({
    required this.id,
    required this.text,
    required this.created,
    required this.outgoing,
    this.image = '',
    this.voice = '',
    this.voiceMillis = 0,
  });
  final String id;
  final String text;
  final DateTime created;
  final bool outgoing;
  final String image;
  final String voice;
  final int voiceMillis;
  String get preview => voice.isNotEmpty
      ? 'Tin nhắn thoại · ${voiceClock(voiceMillis)}'
      : image.isEmpty
      ? text
      : (text.isEmpty ? 'Ảnh' : 'Ảnh · $text');
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'created': created.toIso8601String(),
    'outgoing': outgoing,
    'image': image,
    'voice': voice,
    'voiceMillis': voiceMillis,
  };
  factory DemoChatMessage.fromJson(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final text = data['text'] as String;
    final created = DateTime.parse(data['created'] as String);
    final outgoing = data['outgoing'] as bool;
    final image = (data['image'] ?? '') as String;
    final voice = (data['voice'] ?? '') as String;
    final voiceMillis = (data['voiceMillis'] ?? 0) as int;
    if (id.isEmpty ||
        id.length > 80 ||
        (text.trim().isEmpty && image.isEmpty && voice.isEmpty) ||
        (image.isNotEmpty && voice.isNotEmpty) ||
        (voice.isEmpty && voiceMillis != 0) ||
        text.length > 2000) {
      throw const FormatException('Invalid chat message');
    }
    if (image.isNotEmpty) decodeProof(image);
    if (voice.isNotEmpty &&
        voiceDurationMillis(decodeVoice(voice)) != voiceMillis) {
      throw const FormatException('Invalid voice duration');
    }
    return DemoChatMessage(
      id: id,
      text: text,
      created: created,
      outgoing: outgoing,
      image: image,
      voice: voice,
      voiceMillis: voiceMillis,
    );
  }
}

class DemoConversation {
  DemoConversation({
    required this.contactId,
    required List<DemoChatMessage> messages,
    this.unread = 0,
  }) : messages = List.unmodifiable(messages);
  final String contactId;
  final List<DemoChatMessage> messages;
  final int unread;
  DemoChatContact get contact =>
      demoChatContacts.singleWhere((c) => c.id == contactId);
  DemoConversation copy({List<DemoChatMessage>? messages, int? unread}) =>
      DemoConversation(
        contactId: contactId,
        messages: messages ?? this.messages,
        unread: unread ?? this.unread,
      );
  Map<String, dynamic> toJson() => {
    'contactId': contactId,
    'unread': unread,
    'messages': [for (final message in messages) message.toJson()],
  };
  factory DemoConversation.fromJson(Map<String, dynamic> data) {
    final id = data['contactId'] as String;
    final unread = data['unread'] as int;
    final messages = (data['messages'] as List<dynamic>)
        .map((raw) => DemoChatMessage.fromJson(raw as Map<String, dynamic>))
        .toList();
    if (!demoChatContacts.any((c) => c.id == id) ||
        messages.isEmpty ||
        unread < 0 ||
        unread > messages.where((m) => !m.outgoing).length ||
        messages.map((m) => m.id).toSet().length != messages.length) {
      throw const FormatException('Invalid conversation');
    }
    return DemoConversation(contactId: id, messages: messages, unread: unread);
  }
}

List<DemoConversation> seedConversations(DateTime now) {
  const conversation = [
    'Chào bạn, tối nay nhóm mình còn slot chơi cầu lông ở sân Công Thương không?',
    'Bên mình còn trống 2 slot từ 18h đến 20h nhé. Sân số 3.',
    'Hehe Chi phí chia thế nào đây',
    'Bên mình share đều tiền sân với nước, tầm 50k-60k một người thôi nè.',
    'Ok đăng ký cho mình 1 slot nha. Tối mình xách vợt qua!',
    'Ok chốt slot cho Phát nhé! Gặp bạn lúc 18h tối nay.',
  ];
  const previews = [
    'Sân số 4 nha anh em ơi, có biển CLB ở cửa sân nhé.',
    'Tối nay sân cỏ nhân tạo Chu Văn An còn chỗ nha.',
    'Dạ em nhận vợt rồi ạ, tối em mang qua.',
    'Hóa đơn đặt sân bên Quận 10 em gửi anh nhé.',
  ];
  const minutes = [10, 60, 120, 1440];
  return [
    DemoConversation(
      contactId: 'minh-phat',
      messages: [
        for (var i = 0; i < conversation.length; i++)
          DemoChatMessage(
            id: 'seed-$i',
            text: conversation[i],
            created: now.subtract(Duration(minutes: [7, 5, 4, 2, 1, 0][i])),
            outgoing: i.isOdd,
          ),
      ],
    ),
    for (var i = 0; i < previews.length; i++)
      DemoConversation(
        contactId: demoChatContacts[i + 1].id,
        unread: i == 0
            ? 2
            : i == 1
            ? 1
            : 0,
        messages: [
          if (i == 0)
            DemoChatMessage(
              id: 'seed-intro',
              text: 'Nhóm mình có lịch chơi mới nhé.',
              created: now.subtract(const Duration(minutes: 11)),
              outgoing: false,
            ),
          DemoChatMessage(
            id: 'seed-0',
            text: previews[i],
            created: now.subtract(Duration(minutes: minutes[i])),
            outgoing: false,
          ),
        ],
      ),
  ];
}

List<DemoConversation> filterConversations(
  List<DemoConversation> conversations, {
  String query = '',
  String? sport,
  bool unreadOnly = false,
}) {
  String normalize(String value) => removeDiacritics(value).toLowerCase();
  final tokens = normalize(query)
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty);
  return conversations
      .where(
        (c) =>
            (sport == null || c.contact.sport == sport) &&
            (!unreadOnly || c.unread > 0) &&
            tokens.every(
              (token) =>
                  normalize('${c.contact.name} ${c.contact.sport}')
                      .contains(token),
            ),
      )
      .toList();
}

String chatRelativeTime(DateTime time, DateTime now) {
  final minutes = now.difference(time).inMinutes;
  if (minutes < 1) return 'Vừa xong';
  if (minutes < 60) return '$minutes phút trước';
  if (minutes < 1440) return '${minutes ~/ 60} giờ trước';
  if (minutes < 2880) return 'Hôm qua';
  return '${time.day}/${time.month}';
}

String chatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
