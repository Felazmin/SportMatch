import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../booking/demo_booking.dart';
import '../demo/admin_report_data.dart';

class AdminReportFile {
  const AdminReportFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
  final String name, mimeType;
  final Uint8List bytes;
}

Future<AdminReportFile> createAdminReportFile(
  AdminReportData report, {
  required bool pdf,
}) async {
  final suffix =
      '${report.from.year}${report.from.month.toString().padLeft(2, '0')}${report.from.day.toString().padLeft(2, '0')}-${report.to.year}${report.to.month.toString().padLeft(2, '0')}${report.to.day.toString().padLeft(2, '0')}';
  if (!pdf) {
    return AdminReportFile(
      name: 'sportmatch-report-$suffix.csv',
      mimeType: 'text/csv',
      bytes: Uint8List.fromList(utf8.encode(report.csv())),
    );
  }
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter.ttf'));
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      maxPages: 60,
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'Trang ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (_) => [
        pw.Text(
          'SportMatch · Báo cáo hệ thống',
          style: pw.TextStyle(fontSize: 20, color: PdfColor.fromHex('#007D43')),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${bookingDate(report.from)} – ${bookingDate(report.to)} · ${report.scope}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Dữ liệu cục bộ · ${report.generatedAt.toIso8601String()} · Đơn vị tiền: VND',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 14),
        pw.Paragraph(
          text: 'Giao dịch theo ngày thu / hoàn. Đặt sân theo ngày sử dụng, không bao gồm vé sự kiện. Tài khoản và tăng trưởng: toàn hệ thống. Khu vực theo thông tin cơ sở hiện tại. Phí nền tảng thực thu chưa được ghi nhận.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.TableHelper.fromTextArray(
          headers: ['Chỉ tiêu', 'Giá trị / Phân loại', 'Chi tiết'],
          data: [
            for (final row in report.rows().skip(3))
              [
                row[0],
                row.length > 1 ? '${row[1]}' : '',
                row.length > 2 ? '${row[2]}' : '',
              ],
          ],
          headerStyle: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#00A859'),
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.all(7),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
          },
        ),
      ],
    ),
  );
  return AdminReportFile(
    name: 'sportmatch-report-$suffix.pdf',
    mimeType: 'application/pdf',
    bytes: await document.save(),
  );
}
