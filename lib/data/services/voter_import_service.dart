import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import '../models/voter_model.dart';

class VoterImportService {
  /// Parses an Excel file and returns a list of VoterModels.
  /// Expects columns in a specific order or with specific headers.
  Future<List<VoterModel>> parseVotersExcel(String filePath) async {
    // استخدام compute لنقل عملية التحليل الثقيلة إلى معالج خلفي (Isolate)
    // حتى لا تتجمد واجهة المستخدم أثناء قراءة الملفات الضخمة
    return await compute(_parseExcelIsolate, filePath);
  }

  /// الدالة المنفصلة التي يتم تشغيلها في الخلفية
  static List<VoterModel> _parseExcelIsolate(String filePath) {
    try {
      print('DEBUG: VoterImportService: Reading bytes from $filePath');
      final bytes = File(filePath).readAsBytesSync();
      print('DEBUG: VoterImportService: Decoding Excel bytes...');
      final excel = Excel.decodeBytes(bytes);

      final List<VoterModel> voters = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        print('DEBUG: VoterImportService: Processing sheet $table with \${sheet.maxRows} rows.');
        if (sheet.maxRows < 2) continue; // Skip empty sheets

        // Find header indices
        final headers = sheet.rows.first;
        int? symbolIdx, firstIdx, fatherIdx, grandIdx, familyIdx, subClanIdx, centerIdx;

        for (var i = 0; i < headers.length; i++) {
          final val = headers[i]?.value?.toString().toLowerCase().trim() ?? '';
          if (val.contains('رمز') || val.contains('رقم') || val.contains('symbol')) {
            symbolIdx = i;
          } else if (val.contains('الأول') || val.contains('الاول') || val.contains('first')) {
            firstIdx = i;
          } else if (val.contains('الأب') || val.contains('الاب') || val.contains('father')) {
            fatherIdx = i;
          } else if (val.contains('الجد') || val.contains('grand')) {
            grandIdx = i;
          } else if (val.contains('عائلة') || val.contains('family')) {
            familyIdx = i;
          } else if (val.contains('فرع') || val.contains('sub')) {
            subClanIdx = i;
          } else if (val.contains('مركز') || val.contains('center')) {
            centerIdx = i;
          }
        }

        print('DEBUG: VoterImportService: Header indices found -> symbol: $symbolIdx, first: $firstIdx, father: $fatherIdx, grand: $grandIdx, family: $familyIdx, sub: $subClanIdx, center: $centerIdx');

        // Default indices if headers not found (fallback to fixed order)
        symbolIdx ??= 0;
        firstIdx ??= 1;
        fatherIdx ??= 2;
        grandIdx ??= 3;

        for (var i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final symbolData = row.length > symbolIdx ? row[symbolIdx] : null;
          final symbol = symbolData?.value?.toString().trim();
          if (symbol == null || symbol.isEmpty) continue;

          String? getVal(int? idx) {
            if (idx == null || idx < 0 || idx >= row.length) return null;
            return row[idx]?.value?.toString().trim();
          }

          voters.add(VoterModel(
            voterSymbol: symbol,
            firstName: getVal(firstIdx),
            fatherName: getVal(fatherIdx),
            grandfatherName: getVal(grandIdx),
            familyName: getVal(familyIdx),
            subClanName: getVal(subClanIdx),
            centerName: getVal(centerIdx),
            status: 'لم يصوت',
          ));
        }
      }

      print('DEBUG: VoterImportService: Finished parsing. Total voters found: \${voters.length}');
      return voters;
    } catch (e, stack) {
      print('DEBUG: VoterImportService: EXCEPTION during Excel parse: $e');
      print('DEBUG: VoterImportService: StackTrace: $stack');
      rethrow;
    }
  }
}
