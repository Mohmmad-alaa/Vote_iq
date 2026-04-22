import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/voter.dart';

class PdfPrintService {
  /// Fonts cache to avoid refetching during the same session.
  static pw.Font? _arabicFontRegular;
  static pw.Font? _arabicFontBold;

  /// Private method to load the Arabic fonts securely.
  static Future<void> _loadFonts() async {
    if (_arabicFontRegular == null || _arabicFontBold == null) {
      try {
        _arabicFontRegular = await PdfGoogleFonts.notoKufiArabicRegular();
        _arabicFontBold = await PdfGoogleFonts.notoKufiArabicBold();
      } catch (e) {
        debugPrint('[PdfPrintService] Error loading fonts: $e');
        _arabicFontRegular = pw.Font.helvetica();
        _arabicFontBold = pw.Font.helveticaBold();
      }
    }
  }

  /// Prints a list of voters for a specific family or sub-clan.
  static Future<void> printVotersList(String reportTitle, List<Voter> voters) async {
    await _loadFonts();
    final doc = pw.Document();

    // Sort voters by first name
    final sortedVoters = List<Voter>.from(voters)
      ..sort((a, b) => (a.firstName ?? '').compareTo(b.firstName ?? ''));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: _arabicFontRegular,
          bold: _arabicFontBold,
        ),
        header: (context) => _buildHeader(reportTitle, sortedVoters.length),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 16),
          _buildVotersTable(sortedVoters),
        ],
      ),
    );

    final encodedFileName = reportTitle.replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${encodedFileName}_${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildHeader(String title, int totalCount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'Vote IQ - نظام تعقب الناخبين',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'تاريخ الاستخراج: ${intl.DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Text(
              'إجمالي الناخبين: $totalCount',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.5, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'الصفحة ${context.pageNumber} من ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildVotersTable(List<Voter> voters) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headers: ['#', 'رقم الناخب', 'الاسم الثلاثي', 'العائلة/الفرع', 'المركز', 'الحالة'],
      data: voters.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final voter = entry.value;

        return [
          idx.toString(),
          voter.voterSymbol,
          [voter.firstName, voter.fatherName, voter.grandfatherName]
              .where((s) => s != null && s.isNotEmpty)
              .join(' '),
          [voter.familyName, voter.subClanName]
              .where((s) => s != null && s.isNotEmpty)
              .join(' - '),
          voter.centerName ?? '-',
          voter.status,
        ];
      }).toList(),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FixedColumnWidth(60),
      },
    );
  }
}
