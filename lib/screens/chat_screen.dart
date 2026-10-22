import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show Uint8List;

import 'dart:ui' as ui;

import '../auth/demo_session.dart';
import '../chat/demo_chat.dart';
import '../chat/demo_voice.dart';
import '../chat/voice_devices.dart';
import 'voice_record_dialog.dart';
import '../demo/demo_finance.dart' show encodeProof, decodeProof;
import 'finance_screen.dart' show ProofPicker;
import '../widgets/design.dart';

Future<void> _chatNotice(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar(this.contact, {this.size = 48});
  final DemoChatContact contact;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Positioned.fill(
          child: CircleAvatar(
            backgroundColor: contact.sport == 'Bóng đá'
                ? const Color(0xFFE2ECFA)
                : const Color(0xFFE4F2EC),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                child: Text(
                  contact.initials,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _search = TextEditingController();
  late final String? _owner;
  String? _sport;
  bool _unreadOnly = false;
  @override
  void initState() {
    super.initState();
    _owner = widget.session.user?.identifier;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _markAll() {
    widget.session.markAllChatsRead();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã đánh dấu tất cả đã đọc.')));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      if (_owner == null || widget.session.user?.identifier != _owner) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tin nhắn')),
          body: const Center(
            child: Text('Vui lòng đăng nhập để xem tin nhắn.'),
          ),
        );
      }
      final large = MediaQuery.textScalerOf(context).scale(14) > 20;
      final conversations = filterConversations(
        widget.session.conversations,
        query: _search.text,
        sport: _sport,
        unreadOnly: _unreadOnly,
      );
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: const Text(
            'Tin nhắn',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (!large)
              IconButton(
                tooltip: 'Đánh dấu tất cả đã đọc',
                onPressed: _markAll,
                icon: const Icon(Icons.check_circle_outline),
              ),
            PopupMenuButton<String>(
              tooltip: 'Thông báo tin nhắn',
              icon: Icon(
                _unreadOnly
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
              ),
              onSelected: (value) {
                if (value == 'read') {
                  _markAll();
                  return;
                }
                if (value == 'demo') {
                  _chatNotice(
                    context,
                    'Tin nhắn demo',
                    'Các liên hệ và tin nhắn có sẵn là dữ liệu mẫu. Tin mới chỉ lưu trên thiết bị theo tài khoản, không gửi đến người khác.',
                  );
                  return;
                }
                setState(() => _unreadOnly = !_unreadOnly);
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'unread',
                  checked: _unreadOnly,
                  child: const Text('Chỉ tin chưa đọc'),
                ),
                const PopupMenuItem(
                  value: 'read',
                  child: Text('Đánh dấu tất cả đã đọc'),
                ),
                const PopupMenuItem(
                  value: 'demo',
                  child: Text('Thông tin bản demo'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('chat-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm bạn chơi hoặc câu lạc bộ...',
                      hintStyle: const TextStyle(
                        color: AppColors.faint,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.faint,
                        size: 22,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa tìm kiếm',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final sport in [null, 'Cầu lông', 'Bóng đá'])
                        ChoiceChip(
                          key: Key('chat-sport-${sport ?? 'all'}'),
                          label: Text(
                            sport ?? 'Tất cả',
                            style: TextStyle(
                              fontSize: 12,
                              color: _sport == sport
                                  ? Colors.white
                                  : AppColors.muted,
                            ),
                          ),
                          avatar: sport == null
                              ? null
                              : Icon(
                                  sport == 'Bóng đá'
                                      ? Icons.sports_soccer
                                      : Icons.sports_tennis,
                                  size: 14,
                                  color: _sport == sport
                                      ? Colors.white
                                      : AppColors.muted,
                                ),
                          selected: _sport == sport,
                          showCheckmark: false,
                          selectedColor: AppColors.green,
                          backgroundColor: AppColors.background,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onSelected: (_) => setState(() => _sport = sport),
                        ),
                    ],
                  ),
                  const Text(
                    'Demo · Lưu trên thiết bị',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Không có cuộc trò chuyện phù hợp.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: const Key('chat-conversations'),
                      padding: const EdgeInsets.all(12),
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final chat = conversations[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            key: Key('chat-${chat.contactId}'),
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ChatDetailScreen(
                                  session: widget.session,
                                  contactId: chat.contactId,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  _ChatAvatar(chat.contact),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!large)
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  chat.contact.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              _time(chat),
                                            ],
                                          )
                                        else ...[
                                          Text(
                                            chat.contact.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          _time(chat),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                chat.messages.last.preview,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ),
                                            if (chat.unread > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                key: Key(
                                                  'unread-${chat.contactId}',
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2,
                                                    ),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFF4040),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '${chat.unread}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: InkWell(
                      key: Key('chat-nav-$i'),
                      onTap: () => Navigator.pop(context, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FigmaIcon(
                              ['70656', 'ae34c', '8c511', '96aba', 'd96ab'][i],
                              size: 20,
                              color: i == 0 ? AppColors.green : AppColors.faint,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                'Trang chủ',
                                'Bản đồ',
                                'Khám phá',
                                'Nổi bật',
                                'Tài khoản',
                              ][i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: i == 0
                                    ? AppColors.green
                                    : AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _time(DemoConversation chat) => Text(
    chatRelativeTime(chat.messages.last.created, widget.session.now),
    style: TextStyle(
      fontSize: 10,
      color: chat.unread > 0 ? AppColors.green : AppColors.faint,
    ),
  );
}

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.session,
    required this.contactId,
    this.pickImage,
    this.createVoiceRecorder,
    this.createVoicePlayer,
  });
  final DemoSession session;
  final String contactId;
  final Future<Uint8List?> Function()? pickImage;
  final DemoVoiceRecorder Function()? createVoiceRecorder;
  final DemoVoicePlayer Function()? createVoicePlayer;
  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  late final String? _owner;
  bool _saving = false;
  bool _pendingSave = false;
  bool _picking = false;
  String? _photo;
  Uint8List? _voice;
  late final DemoVoicePlayer _player;
  StreamSubscription<void>? _completed;
  String? _playing;
  bool _audioBusy = false;
  bool _voiceOpening = false;
  int _audioGeneration = 0;

  Future<void> _stopPlayback() async {
    _audioGeneration++;
    await _player.stop();
    if (mounted) setState(() => _playing = null);
  }

  void _accountChanged() {
    if (widget.session.user?.identifier != _owner) {
      _voice = null;
      unawaited(_stopPlayback().catchError((_) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_stopPlayback().catchError((_) {}));
    }
  }

  Future<void> _recordVoice() async {
    if (_saving ||
        _pendingSave ||
        _picking ||
        _voiceOpening ||
        _photo != null ||
        _owner == null ||
        widget.session.user?.identifier != _owner) {
      return;
    }
    _voiceOpening = true;
    try {
      try {
        await _stopPlayback();
      } catch (_) {}
      if (!mounted || widget.session.user?.identifier != _owner) return;
      final recorder =
          (widget.createVoiceRecorder ?? NativeVoiceRecorder.new)();
      final player = (widget.createVoicePlayer ?? NativeVoicePlayer.new)();
      final bytes = await showDialog<Uint8List>(
        context: context,
        builder: (_) => VoiceRecordDialog(
          session: widget.session,
          actor: _owner,
          recorder: recorder,
          player: player,
        ),
      );
      if (mounted &&
          bytes != null &&
          widget.session.user?.identifier == _owner) {
        setState(() => _voice = bytes);
      }
    } finally {
      _voiceOpening = false;
    }
  }

  Future<void> _playVoice(String id, Uint8List bytes) async {
    if (_audioBusy || widget.session.user?.identifier != _owner) return;
    final previous = _playing;
    setState(() => _audioBusy = true);
    try {
      await _stopPlayback();
      final generation = _audioGeneration;
      if (previous != id &&
          mounted &&
          widget.session.user?.identifier == _owner) {
        await _player.play(bytes);
        if (mounted &&
            generation == _audioGeneration &&
            widget.session.user?.identifier == _owner) {
          setState(() => _playing = id);
        } else {
          await _player.stop();
        }
      }
    } catch (_) {
      if (mounted && widget.session.user?.identifier == _owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể phát bản ghi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Widget _voiceControl(String id, Uint8List bytes, {Color? color}) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton(
        key: Key('chat-voice-play-$id'),
        tooltip: _playing == id ? 'Dừng phát' : 'Phát tin nhắn thoại',
        onPressed: _audioBusy ? null : () => _playVoice(id, bytes),
        icon: Icon(
          _playing == id ? Icons.stop : Icons.play_arrow,
          color: color,
        ),
      ),
      Text(
        voiceClock(voiceDurationMillis(bytes)),
        style: TextStyle(color: color),
      ),
    ],
  );

  Future<void> _pickPhoto() async {
    if (_saving ||
        _pendingSave ||
        _picking ||
        _voice != null ||
        _owner == null ||
        widget.session.user?.identifier != _owner) {
      return;
    }
    setState(() => _picking = true);
    try {
      final bytes = await (widget.pickImage ?? ProofPicker.pick)();
      if (bytes == null ||
          !mounted ||
          widget.session.user?.identifier != _owner) {
        return;
      }
      final encoded = encodeProof(bytes);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width > 4096 ||
              descriptor.height > 4096 ||
              descriptor.width * descriptor.height > 12000000) {
            throw const FormatException(
              'Ảnh quá lớn. Chọn ảnh tối đa 4096px và 12 megapixel.',
            );
          }
          final codec = await descriptor.instantiateCodec(targetWidth: 512);
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
      if (mounted && widget.session.user?.identifier == _owner) {
        setState(() => _photo = encoded);
      }
    } catch (error) {
      if (mounted && widget.session.user?.identifier == _owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Không thể mở ảnh. Hãy chọn lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _openPhoto(String encoded) {
    if (widget.session.user?.identifier != _owner) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Ảnh trong hội thoại')),
            body: widget.session.user?.identifier != _owner
                ? const Center(child: Text('Cuộc trò chuyện không khả dụng.'))
                : InteractiveViewer(
                    key: const Key('chat-image-viewer'),
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.memory(
                        decodeProof(encoded),
                        fit: BoxFit.contain,
                        cacheWidth: 2048,
                        errorBuilder: (_, _, _) =>
                            const Text('Không thể mở ảnh.'),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _owner = widget.session.user?.identifier;
    _player = (widget.createVoicePlayer ?? NativeVoicePlayer.new)();
    _completed = _player.completed.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    widget.session.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _owner != null &&
          widget.session.user?.identifier == _owner &&
          widget.session.conversations.any(
            (c) => c.contactId == widget.contactId,
          )) {
        widget.session.markChatRead(widget.contactId);
        _toLatest();
      }
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    widget.session.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _audioGeneration++;
    unawaited(_completed?.cancel());
    unawaited(_player.dispose().catchError((_) {}));
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toLatest() async {
    // Lazy message layout can revise the scroll extent after the first jump.
    for (var frame = 0; frame < 3; frame++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<void> _send() async {
    if (_saving ||
        _picking ||
        _owner == null ||
        widget.session.user?.identifier != _owner) {
      return;
    }
    final text = _draft.text;
    if (!_pendingSave &&
        text.trim().isEmpty &&
        _photo == null &&
        _voice == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _stopPlayback();
      if (widget.session.user?.identifier != _owner) {
        throw StateError('Tài khoản đã thay đổi. Mở lại hội thoại.');
      }
      if (_pendingSave) {
        await widget.session.retrySave();
      } else {
        widget.session.sendChatMessage(
          widget.contactId,
          text,
          image: _photo == null ? null : decodeProof(_photo!),
          voice: _voice,
        );
        _pendingSave = true;
        _toLatest();
      }
      final saved = await widget.session.flush();
      if (mounted && saved) {
        _draft.clear();
        _photo = null;
        _voice = null;
        _pendingSave = false;
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _contextInfo(DemoChatContact contact) => _chatNotice(
    context,
    'Lịch giao lưu demo',
    '${contact.sport} · ${contact.sport == 'Bóng đá' ? 'Sân Chu Văn An' : 'Sân Kỳ Hòa'}\n'
        'Sân số 3 · 18:00 - 20:00\n\nĐây là thông tin mẫu trong hội thoại, không phải xác nhận đặt sân thực tế.',
  );
  Future<void> _emoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final emoji in [
                  '😀',
                  '😊',
                  '👍',
                  '❤️',
                  '🎉',
                  '🏸',
                  '⚽',
                  '💪',
                  '🙏',
                  '👌',
                  '🔥',
                  '😂',
                ])
                  IconButton(
                    tooltip: emoji,
                    onPressed: () => Navigator.pop(context, emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || emoji == null || _pendingSave) return;
    final selection = _draft.selection;
    final start = selection.isValid ? selection.start : _draft.text.length;
    final end = selection.isValid ? selection.end : start;
    final next = _draft.text.replaceRange(start, end, emoji);
    if (next.length > 2000) return;
    _draft.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    setState(() {});
  }

  void _attachments(DemoChatContact contact) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Thông tin lịch giao lưu'),
              onTap: () {
                Navigator.pop(sheetContext);
                _contextInfo(contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Ảnh'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Tin nhắn thoại'),
              onTap: () {
                Navigator.pop(sheetContext);
                _recordVoice();
              },
            ),
          ],
        ),
      ),
    ),
  );
  void _unsupported(String title) => _chatNotice(
    context,
    title,
    'Bản demo hỗ trợ văn bản, ảnh và ghi âm lưu trên thiết bị. Chức năng này chưa kết nối dịch vụ thật.',
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      if (_owner == null ||
          widget.session.user?.identifier != _owner ||
          !widget.session.conversations.any(
            (c) => c.contactId == widget.contactId,
          )) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tin nhắn')),
          body: const Center(child: Text('Cuộc trò chuyện không khả dụng.')),
        );
      }
      final chat = widget.session.conversation(widget.contactId);
      final compact =
          MediaQuery.sizeOf(context).width < 360 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      final football = chat.contact.sport == 'Bóng đá';
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          leadingWidth: 40,
          titleSpacing: 0,
          title: Row(
            children: [
              _ChatAvatar(chat.contact, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Trò chuyện demo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (compact)
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn cuộc gọi',
                onSelected: _unsupported,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Gọi điện', child: Text('Gọi điện')),
                  PopupMenuItem(value: 'Gọi video', child: Text('Gọi video')),
                ],
              )
            else ...[
              IconButton(
                tooltip: 'Gọi điện',
                onPressed: () => _unsupported('Gọi điện'),
                icon: const Icon(Icons.phone_outlined, size: 22),
              ),
              IconButton(
                tooltip: 'Gọi video',
                onPressed: () => _unsupported('Gọi video'),
                icon: const Icon(Icons.videocam_outlined, size: 24),
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            Material(
              color: const Color(0xFFE6F6EF),
              child: InkWell(
                onTap: () => _contextInfo(chat.contact),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF8EDAB5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.green,
                        child: Icon(
                          football ? Icons.sports_soccer : Icons.sports_tennis,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giao lưu ${chat.contact.sport} · ${football ? 'Sân Chu Văn An' : 'Sân Kỳ Hòa'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${compact ? '' : 'Demo · '}Sân số 3 | 18:00 - 20:00',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                            if (compact)
                              const Text(
                                'Đã chốt · Demo',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.darkGreen,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Đã chốt',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => ListView.separated(
                  key: const Key('chat-messages'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: chat.messages.length,
                  separatorBuilder: (_, index) {
                    final previous = chat.messages[index].created;
                    final next = chat.messages[index + 1].created;
                    if (previous.year == next.year &&
                        previous.month == next.month &&
                        previous.day == next.day) {
                      return const SizedBox(height: 16);
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '${next.day}/${next.month}/${next.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final message = chat.messages[index];
                    return Align(
                      alignment: message.outgoing
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * .65,
                        ),
                        child: Container(
                          key: Key('message-${message.id}'),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          decoration: BoxDecoration(
                            color: message.outgoing
                                ? AppColors.green
                                : const Color(0xFFE4E7EB),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(
                                message.outgoing ? 18 : 4,
                              ),
                              bottomRight: Radius.circular(
                                message.outgoing ? 4 : 18,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: message.outgoing
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.image.isNotEmpty)
                                Semantics(
                                  button: true,
                                  label: 'Xem ảnh trong hội thoại',
                                  child: InkWell(
                                    key: Key('chat-image-${message.id}'),
                                    onTap: () => _openPhoto(message.image),
                                    child: SizedBox(
                                      width: 180,
                                      height: 140,
                                      child: Image.memory(
                                        decodeProof(message.image),
                                        fit: BoxFit.contain,
                                        cacheWidth: 512,
                                        errorBuilder: (_, _, _) => const Center(
                                          child: Text('Không thể mở ảnh.'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (message.text.isNotEmpty)
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    color: message.outgoing
                                        ? Colors.white
                                        : AppColors.ink,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (message.voice.isNotEmpty)
                                _voiceControl(
                                  message.id,
                                  decodeVoice(message.voice),
                                  color: message.outgoing
                                      ? Colors.white
                                      : AppColors.ink,
                                ),
                              Text(
                                '${chatClock(message.created)}${message.id.startsWith('local-') ? ' · Cục bộ' : ''}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: message.outgoing
                                      ? const Color(0xB3FFFFFF)
                                      : AppColors.faint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_voice != null)
                        Row(
                          key: const Key('chat-voice-preview'),
                          children: [
                            Expanded(child: _voiceControl('draft', _voice!)),
                            IconButton(
                              key: const Key('chat-voice-remove'),
                              tooltip: 'Bỏ bản ghi',
                              onPressed: _saving || _pendingSave
                                  ? null
                                  : () {
                                      unawaited(
                                        _stopPlayback().catchError((_) {}),
                                      );
                                      setState(() => _voice = null);
                                    },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      if (_picking)
                        const LinearProgressIndicator(
                          key: Key('chat-image-loading'),
                        ),
                      if (_photo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Image.memory(
                                decodeProof(_photo!),
                                key: const Key('chat-image-preview'),
                                width: 72,
                                height: 64,
                                fit: BoxFit.contain,
                                cacheWidth: 256,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Ảnh đã chọn')),
                              IconButton(
                                key: const Key('chat-image-remove'),
                                tooltip: 'Bỏ ảnh',
                                onPressed: _saving || _pendingSave
                                    ? null
                                    : () => setState(() => _photo = null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      if (_pendingSave && !_saving)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Chưa lưu được tin nhắn.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _send,
                                child: const Text('Thử lưu'),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Thêm nội dung',
                            onPressed: _saving || _pendingSave || _picking
                                ? null
                                : () => _attachments(chat.contact),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.green,
                              size: 22,
                            ),
                          ),
                          if (!compact) ...[
                            IconButton(
                              tooltip: 'Gửi ảnh',
                              key: const Key('chat-pick-image'),
                              onPressed:
                                  _saving ||
                                      _pendingSave ||
                                      _picking ||
                                      _voice != null
                                  ? null
                                  : _pickPhoto,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.faint,
                                size: 22,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 48,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              tooltip: 'Tin nhắn thoại',
                              key: const Key('chat-record-voice'),
                              onPressed:
                                  _saving ||
                                      _pendingSave ||
                                      _picking ||
                                      _photo != null
                                  ? null
                                  : _recordVoice,
                              icon: const Icon(
                                Icons.mic_none,
                                color: AppColors.faint,
                                size: 22,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 48,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                          Expanded(
                            child: TextField(
                              key: const Key('chat-draft'),
                              controller: _draft,
                              enabled: !_saving && !_pendingSave && !_picking,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 2000,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.newline,
                              onChanged: (_) => setState(() {}),
                              onTap: _toLatest,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Nhập tin nhắn...',
                                counterText: '',
                                filled: true,
                                fillColor: AppColors.background,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Biểu tượng cảm xúc',
                                  onPressed: _saving || _pendingSave
                                      ? null
                                      : _emoji,
                                  icon: const Icon(
                                    Icons.sentiment_satisfied_alt,
                                    size: 20,
                                    color: AppColors.faint,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            key: const Key('chat-send'),
                            tooltip: 'Gửi tin nhắn demo',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                _saving ||
                                    _picking ||
                                    _pendingSave ||
                                    (_draft.text.trim().isEmpty &&
                                        _photo == null &&
                                        _voice == null)
                                ? null
                                : _send,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined, size: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
