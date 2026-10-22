import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/facilities_screen.dart';
import 'package:test_do_an/screens/facility_document_screen.dart';

import 'facility_form_drafts_test.dart' show partial;
import 'multi_facility_test.dart' show publishTestFacility;
import 'persistence_test.dart' show TestSessionStore;
import 'home_accessibility_test.dart' show captureHome;

Uint8List samplePdf() {
  final out = StringBuffer('%PDF-1.4\n'), offsets = <int>[0];
  const stream = 'BT /F1 20 Tf 30 100 Td (DEMO DOCUMENT) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 180] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(out.toString()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 8, 10));
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  test('PDF bounds and format checks do not weaken photo validation', () {
    final pdf = encodeFacilityPdf(samplePdf());
    expect(decodeFacilityDocument(pdf), orderedEquals(samplePdf()));
    expect(
      () => encodeFacilityPdf(Uint8List(400 * 1024 + 1)),
      throwsFormatException,
    );
    expect(
      () => decodeFacilityDocument(
        'pdf:${base64Encode(ascii.encode('%PDF-1.4 broken'))}',
      ),
      throwsFormatException,
    );
    expect(() => decodeFacilityDocument('pdf:invalid'), throwsFormatException);
    final s = open(), f = publishTestFacility(open());
    owner(s);
    expect(
      () => FacilityProfile.fromJson({...f.draft.toJson(), 'photo': pdf}),
      throwsFormatException,
    );
    expect(
      () => FacilityProfile.fromJson({...f.draft.toJson(), 'legalProof': pdf}),
      returnsNormally,
    );
  });
  test(
    'Published PDF survives restart but never appears in public profile',
    () async {
      final store = TestSessionStore(), s = open(TestSessionStore());
      await s.initialize();
      final p = publishTestFacility(s).draft;
      final persisted = open(store);
      await persisted.initialize();
      owner(persisted);
      final f = persisted.saveFacility(
        FacilityProfile.fromJson({
          ...p.toJson(),
          'legalProof': encodeFacilityPdf(samplePdf()),
        }),
      );
      persisted.submitFacility(f);
      persisted.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      persisted.reviewFacility(f, approve: true);
      await persisted.flush();
      final restored = open(store);
      await restored.initialize();
      expect(restored.publicFacilities.single.profile.legalProof, isEmpty);
      owner(restored);
      expect(
        isFacilityPdf(restored.managedFacilities.single.draft.legalProof),
        isTrue,
      );
    },
  );
  test('PDF engine renders real document pages', () async {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    await pdfrxFlutterInitialize();
    final doc = await PdfDocument.openData(
      samplePdf(),
      sourceName: 'demo-test.pdf',
    );
    try {
      expect(doc.pages.length, 1);
      final rendered = await doc.pages.single.render();
      expect(rendered, isNotNull);
      expect(rendered!.pixels.any((v) => v < 128), isTrue);
      if (const bool.fromEnvironment('SCREENSHOT')) {
        final image = await rendered.createImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/previews').create(recursive: true);
        await File('build/previews/facility-pdf-page.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      }
      rendered.dispose();
    } finally {
      await doc.dispose();
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Partial form resumes and PDF can be removed at $scale', (
      t,
    ) async {
      final s = open();
      owner(s);
      s.saveFacilityFormDraft(partial(name: 'A'));
      t.view.physicalSize = Size(scale == 1 ? 402 : 320, 879);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final preview = GlobalKey();
      await t.pumpWidget(const MyApp());
      await t.pumpAndSettle();
      final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      await t.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: FacilityFormScreen(
              session: s,
              pickPdf: () async => samplePdf(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('facility-field-name')))
            .controller!
            .text,
        'A',
      );
      Future<void> press(String key) async {
        t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await t.pumpAndSettle();
        final f = find.byKey(Key(key));
        if (f.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            f,
            250,
            maxScrolls: 40,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.tap(f);
        await t.pumpAndSettle();
      }

      await press('facility-legal-pdf');
      expect(find.byKey(const Key('facility-pdf-document')), findsOneWidget);
      await captureHome(preview, 'facility-partial-pdf-$scale', t);
      await press('facility-save-partial');
      expect(isFacilityPdf(s.facilityFormDraft()!.legalProof), isTrue);
      expect(s.managedFacilities, isEmpty);
      await press('facility-legal-remove');
      await press('facility-save-partial');
      expect(s.facilityFormDraft()!.legalProof, isEmpty);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Unauthorized PDF route never creates a renderer', (t) async {
    final s = open();
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpWidget(
      MaterialApp(
        home: FacilityDocumentScreen(
          session: s,
          encoded: encodeFacilityPdf(samplePdf()),
          actor: '__owner__',
        ),
      ),
    );
    expect(find.byType(PdfViewer), findsNothing);
    expect(find.text('Chưa có quyền truy cập.'), findsOneWidget);
  });
}
