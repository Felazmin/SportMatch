import 'dart:ui' as ui;

import 'demo_finance.dart';

// A conspicuous sample, never a fabricated bank receipt or identity document.
Future<String> createDemoSeedProof() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 24, height: 1.5))
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xffb42318)))
        ..addText(
          'DEMO - TEST DOCUMENT\n\nNOT A PAYMENT RECEIPT\nNOT A LEGAL / ID DOCUMENT\n\nLocal UI testing only.\nNo real payment has been made.',
        );
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 550));
  canvas.drawParagraph(paragraph, const ui.Offset(24, 20));
  final picture = recorder.endRecording();
  final image = await picture.toImage(600, 380);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return encodeProof(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}
