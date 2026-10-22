import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'demo_voice.dart';

abstract interface class DemoVoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> cancel();
  Future<void> dispose();
}

abstract interface class DemoVoicePlayer {
  Stream<void> get completed;
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  Future<void> dispose();
}

class NativeVoiceRecorder implements DemoVoiceRecorder {
  AudioRecorder? _recorder;
  File? _file;
  AudioRecorder get _device => _recorder ??= AudioRecorder();
  @override
  Future<bool> hasPermission() async {
    if (kIsWeb) throw StateError('Ghi âm hiện hỗ trợ bản app trên thiết bị.');
    return _device.hasPermission();
  }

  @override
  Future<void> start() async {
    final temp = await getTemporaryDirectory();
    _file = File(
      '${temp.path}/nvh-voice-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await _device.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _file!.path,
    );
  }

  Future<void> _clean() async {
    final file = _file;
    _file = null;
    if (file != null && await file.exists()) await file.delete();
  }

  @override
  Future<Uint8List> stop() async {
    try {
      await _device.stop();
      final file = _file;
      if (file == null ||
          !await file.exists() ||
          await file.length() > maxChatVoiceBytes) {
        throw StateError('Không thể đọc bản ghi hoặc bản ghi quá lớn.');
      }
      final bytes = await file.readAsBytes();
      voiceDurationMillis(bytes);
      return bytes;
    } finally {
      await _clean();
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder?.cancel();
    } finally {
      await _clean();
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await cancel();
    } finally {
      await _recorder?.dispose();
    }
  }
}

class NativeVoicePlayer implements DemoVoicePlayer {
  AudioPlayer? _player;
  StreamSubscription<void>? _subscription;
  final _completed = StreamController<void>.broadcast();
  @override
  Stream<void> get completed => _completed.stream;
  @override
  Future<void> play(Uint8List bytes) async {
    voiceDurationMillis(bytes);
    final player = _player ??= AudioPlayer();
    _subscription ??= player.onPlayerComplete.listen(
      (_) => _completed.add(null),
    );
    await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() async => _player?.stop();
  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _player?.dispose();
    await _completed.close();
  }
}
