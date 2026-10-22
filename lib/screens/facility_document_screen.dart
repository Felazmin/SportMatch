import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../auth/demo_session.dart';
import '../demo/demo_facilities.dart';
import 'finance_screen.dart';

Future<Uint8List?> pickFacilityPdf() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > facilityPdfLimit) {
    throw const FormatException('PDF too large');
  }
  final bytes = await file.readAsBytes();
  encodeFacilityPdf(bytes);
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openData(
    bytes,
    sourceName: file.name,
    passwordProvider: () async => null,
  );
  try {
    if (document.pages.isEmpty || document.pages.length > 50) {
      throw const FormatException('PDF must contain 1 to 50 pages');
    }
  } finally {
    await document.dispose();
  }
  return bytes;
}

class FacilityDocumentScreen extends StatelessWidget {
  const FacilityDocumentScreen({
    super.key,
    required this.session,
    required this.encoded,
    required this.actor,
    this.facility,
  });
  final DemoSession session;
  final String encoded, actor;
  final DemoFacility? facility;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final allowed =
          session.initialized &&
          session.user?.identifier == actor &&
          (facility == null
              ? session.role == DemoRole.owner
              : session.canManageFacility(facility!));
      return Scaffold(
        appBar: financeBar('Tài liệu hồ sơ'),
        body: !allowed
            ? const Center(child: Text('Chưa có quyền truy cập.'))
            : PdfViewer.data(
                decodeFacilityDocument(encoded),
                sourceName:
                    'facility-${facility?.id ?? 'draft'}-${encoded.hashCode}',
                passwordProvider: () async => null,
              ),
      );
    },
  );
}
