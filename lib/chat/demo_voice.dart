import 'dart:convert';
import 'dart:typed_data';

const maxChatVoiceBytes = 700000;
const maxChatVoicesPerAccount = 20;

// Read RIFF chunks rather than assuming every WAV has a 44-byte header.
int voiceDurationMillis(Uint8List bytes) {
  if (bytes.length < 44 || bytes.length > maxChatVoiceBytes) {
    throw const FormatException('Bản ghi cần nhỏ hơn 700KB.');
  }
  final data = ByteData.sublistView(bytes);
  bool tag(int offset, String value) => value.codeUnits.asMap().entries.every(
    (e) => bytes[offset + e.key] == e.value,
  );
  if (!tag(0, 'RIFF') ||
      !tag(8, 'WAVE') ||
      data.getUint32(4, Endian.little) + 8 != bytes.length) {
    throw const FormatException('Bản ghi WAV không hợp lệ.');
  }
  int? rate, payload;
  var position = 12, chunks = 0;
  while (position < bytes.length) {
    if (position + 8 > bytes.length || ++chunks > 32) {
      throw const FormatException('Bản ghi WAV không hợp lệ.');
    }
    final length = data.getUint32(position + 4, Endian.little);
    final start = position + 8, end = start + length;
    if (end > bytes.length) {
      throw const FormatException('Bản ghi bị thiếu dữ liệu.');
    }
    if (tag(position, 'fmt ')) {
      if (rate != null ||
          length < 16 ||
          data.getUint16(start, Endian.little) != 1 ||
          data.getUint16(start + 2, Endian.little) != 1 ||
          data.getUint16(start + 12, Endian.little) != 2 ||
          data.getUint16(start + 14, Endian.little) != 16) {
        throw const FormatException('Chỉ hỗ trợ WAV mono PCM 16-bit.');
      }
      rate = data.getUint32(start + 4, Endian.little);
      if (rate < 8000 ||
          rate > 48000 ||
          data.getUint32(start + 8, Endian.little) != rate * 2) {
        throw const FormatException('Tần số bản ghi không hợp lệ.');
      }
    } else if (tag(position, 'data')) {
      if (payload != null || length.isOdd) {
        throw const FormatException('Dữ liệu âm thanh không hợp lệ.');
      }
      payload = length;
    }
    position = end + (length.isOdd ? 1 : 0);
  }
  if (position != bytes.length || rate == null || payload == null) {
    throw const FormatException('Bản ghi bị thiếu dữ liệu.');
  }
  final milliseconds = payload * 1000 ~/ (rate * 2);
  // One second of tolerance allows the native recorder to flush its final buffer.
  if (milliseconds < 500 || milliseconds > 21000) {
    throw const FormatException('Bản ghi cần dài từ nửa giây đến 20 giây.');
  }
  return milliseconds;
}

String encodeVoice(Uint8List bytes) {
  voiceDurationMillis(bytes);
  return base64Encode(bytes);
}

Uint8List decodeVoice(String encoded) {
  if (encoded.length > maxChatVoiceBytes * 4 ~/ 3 + 8) {
    throw const FormatException('Bản ghi quá lớn.');
  }
  final bytes = base64Decode(encoded);
  voiceDurationMillis(bytes);
  return bytes;
}

String voiceClock(int milliseconds) {
  final seconds = (milliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
