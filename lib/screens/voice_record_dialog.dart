import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;

import '../auth/demo_session.dart';
import '../chat/demo_voice.dart';
import '../chat/voice_devices.dart';

class VoiceRecordDialog extends StatefulWidget {
  const VoiceRecordDialog({
    super.key,
    required this.session,
    required this.actor,
    required this.recorder,
    required this.player,
  });
  final DemoSession session;
  final String actor;
  final DemoVoiceRecorder recorder;
  final DemoVoicePlayer player;
  @override
  State<VoiceRecordDialog> createState() => _VoiceRecordDialogState();
}

class _VoiceRecordDialogState extends State<VoiceRecordDialog>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _limit;
  bool _captureActive = false;
  final _elapsed = Stopwatch();
  Uint8List? _bytes;
  bool _recording = false, _busy = false, _playing = false;
  String? _error;
  int _generation = 0;
  StreamSubscription<void>? _completed;
  bool get _allowed =>
      mounted && widget.session.user?.identifier == widget.actor;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_account);
    _completed = widget.player.completed.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  void _account() {
    if (!_allowed && mounted) Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_captureActive ||
            _recording ||
            _playing ||
            (_busy && _elapsed.elapsedMilliseconds > 0))) {
      _generation++;
      _timer?.cancel();
      _limit?.cancel();
      _captureActive = false;
      unawaited(widget.recorder.cancel().catchError((_) {}));
      unawaited(widget.player.stop().catchError((_) {}));
      _elapsed.stop();
      if (mounted) {
        setState(() {
          _recording = false;
          _playing = false;
          _bytes = null;
          _error = 'Đã hủy bản ghi khi rời ứng dụng.';
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.session.removeListener(_account);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _limit?.cancel();
    unawaited(_completed?.cancel());
    unawaited(widget.recorder.dispose().catchError((_) {}));
    unawaited(widget.player.dispose().catchError((_) {}));
    super.dispose();
  }

  Future<void> _start() async {
    if (!_allowed || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final generation = ++_generation;
    try {
      if (!await widget.recorder.hasPermission()) {
        throw StateError('Chưa có quyền micro. Cấp quyền rồi thử lại.');
      }
      if (!_allowed) return;
      await widget.player.stop();
      if (!_allowed || generation != _generation) return;
      _captureActive = true;
      await widget.recorder.start();
      if (!_allowed ||
          generation != _generation ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        await widget.recorder.cancel();
        return;
      }
      _elapsed.reset();
      _elapsed.start();
      setState(() {
        _recording = true;
        _bytes = null;
        _playing = false;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!_allowed) return;
        if (_elapsed.elapsedMilliseconds >= 20000) {
          unawaited(_stop());
        } else {
          setState(() {});
        }
      });
      _limit = Timer(const Duration(seconds: 20), () => unawaited(_stop()));
    } catch (e) {
      try {
        await widget.recorder.cancel();
      } catch (_) {}
      _captureActive = false;
      if (_allowed) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Không thể ghi âm. Kiểm tra micro rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (!_recording || _busy || !_allowed) return;
    _timer?.cancel();
    _limit?.cancel();
    _elapsed.stop();
    setState(() {
      _busy = true;
      _recording = false;
    });
    final generation = _generation;
    try {
      final bytes = await widget.recorder.stop();
      voiceDurationMillis(bytes);
      if (_allowed && generation == _generation) setState(() => _bytes = bytes);
    } catch (e) {
      if (_allowed) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Không thể đọc bản ghi. Hãy ghi lại.',
        );
      }
    } finally {
      _captureActive = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listen() async {
    if (!_allowed || _busy || _bytes == null) return;
    setState(() => _busy = true);
    final generation = _generation;
    try {
      if (_playing) {
        await widget.player.stop();
      } else {
        await widget.player.play(_bytes!);
      }
      if (_allowed && generation == _generation) {
        setState(() => _playing = !_playing);
      } else {
        await widget.player.stop();
      }
    } catch (_) {
      if (_allowed) setState(() => _error = 'Không thể phát bản ghi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tin nhắn thoại'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _recording ? Icons.mic : Icons.mic_none,
            color: _recording ? Colors.red : Colors.green,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            _bytes == null
                ? '${voiceClock(_elapsed.elapsedMilliseconds)} / 0:20'
                : voiceClock(voiceDurationMillis(_bytes!)),
            key: const Key('voice-record-duration'),
          ),
          if (_recording) const Text('Đang ghi âm'),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_busy) const LinearProgressIndicator(),
          if (_bytes != null)
            IconButton(
              key: const Key('voice-record-listen'),
              tooltip: _playing ? 'Dừng nghe' : 'Nghe lại',
              onPressed: _busy ? null : _listen,
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
            ),
          FilledButton.icon(
            key: const Key('voice-record-toggle'),
            onPressed: _busy
                ? null
                : _recording
                ? _stop
                : _start,
            icon: Icon(_recording ? Icons.stop : Icons.mic),
            label: Text(
              _recording
                  ? 'Dừng ghi'
                  : _bytes == null
                  ? 'Ghi âm'
                  : 'Ghi lại',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const Key('voice-record-cancel'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Bỏ'),
      ),
      FilledButton(
        key: const Key('voice-record-attach'),
        onPressed: _bytes == null || _busy || !_allowed
            ? null
            : () => Navigator.pop(context, _bytes),
        child: const Text('Đính kèm'),
      ),
    ],
  );
}
