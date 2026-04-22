import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';

class ListCandidateImportResult {
  final String listName;
  final String candidateName;

  ListCandidateImportResult({required this.listName, required this.candidateName});
}

class ListCandidateImportService {
  /// Parses an Excel file and returns a list of lists and candidates.
  Future<List<ListCandidateImportResult>> parseExcel(String filePath) async {
    return await compute(_parseExcelIsolate, filePath);
  }

  static List<ListCandidateImportResult> _parseExcelIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final List<ListCandidateImportResult> results = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        if (sheet.maxRows < 2) continue; // Skip empty sheets

        bool isTabular = false;
        int? tabularListColIdx;
        int? tabularCandidateColIdx;
        int? tabularOrderColIdx;
        int startRowIdx = -1;

        // 1. Try to find Tabular Format (Both list and candidate columns in the same row)
        for (int r = 0; r < sheet.maxRows && r < 10; r++) {
          final row = sheet.rows[r];
          int? tempListIdx;
          int? tempCandidateIdx;
          int? tempOrderIdx;

          for (int c = 0; c < row.length; c++) {
            final val = row[c]?.value?.toString().toLowerCase().trim() ?? '';
            if (val == 'القائمة' || val == 'اسم القائمة' || val == 'اسم القائمه' || val.contains('قائمة') || val.contains('list')) {
              tempListIdx = c;
            } else if (val == 'المرشح' || val == 'اسم المرشح' || val.contains('مرشح') || val.contains('candidate')) {
              tempCandidateIdx = c;
            } else if (val == 'الترتيب' || val == 'التسلسل' || val == 'رقم المرشح' || val == 'رقم' || val.contains('ترتيب') || val.contains('تسلسل')) {
              tempOrderIdx = c;
            }
          }

          if (tempListIdx != null && tempCandidateIdx != null && tempListIdx != tempCandidateIdx) {
            isTabular = true;
            tabularListColIdx = tempListIdx;
            tabularCandidateColIdx = tempCandidateIdx;
            tabularOrderColIdx = tempOrderIdx;
            startRowIdx = r + 1;
            break;
          }
        }

        if (isTabular) {
          for (int r = startRowIdx; r < sheet.maxRows; r++) {
            final row = sheet.rows[r];
            if (row.isEmpty) continue;

            String? getVal(int? idx) {
              if (idx == null || idx < 0 || idx >= row.length) return null;
              return row[idx]?.value?.toString().trim();
            }

            final listName = getVal(tabularListColIdx);
            String? candidateName = getVal(tabularCandidateColIdx);
            final orderStr = getVal(tabularOrderColIdx);

            if (candidateName != null && candidateName.isNotEmpty && orderStr != null && orderStr.isNotEmpty) {
               // Only prepend if the user hasn't already hardcoded it.
               if (!candidateName.startsWith(orderStr) && !candidateName.startsWith('$orderStr-')) {
                 // Format: 1- Candidate Name
                 // Clean up float representation from Excel like "1.0"
                 String cleanedOrder = orderStr;
                 if (cleanedOrder.endsWith('.0')) {
                   cleanedOrder = cleanedOrder.substring(0, cleanedOrder.length - 2);
                 }
                 candidateName = '$cleanedOrder- $candidateName';
               }
            }

            if (listName != null && listName.isNotEmpty && candidateName != null && candidateName.isNotEmpty) {
              results.add(ListCandidateImportResult(
                listName: listName,
                candidateName: candidateName,
              ));
            }
          }
        } else {
          // 2. Try to find Single-List Format
          String? extractedListName;
          int? candidateColIdx;
          int singleStartRowIdx = -1;

          for (int r = 0; r < sheet.maxRows && r < 10; r++) {
            final row = sheet.rows[r];
            for (int c = 0; c < row.length; c++) {
              final val = row[c]?.value?.toString().trim() ?? '';
              
              if (val.contains('اسم القائمة') || val.contains('اسم القائمه')) {
                String tempName = val
                    .replaceAll('اسم القائمة', '')
                    .replaceAll('اسم القائمه', '')
                    .replaceAll(':', '')
                    .trim();
                
                if (tempName.isEmpty) {
                  if (c + 1 < row.length && row[c + 1]?.value != null) {
                    tempName = row[c + 1]?.value?.toString().trim() ?? '';
                  } else if (c + 2 < row.length && row[c + 2]?.value != null) {
                    tempName = row[c + 2]?.value?.toString().trim() ?? '';
                  }
                }
                if (tempName.isNotEmpty) {
                  extractedListName = tempName;
                }
              }

              if (val == 'اسم المرشح' || val.contains('اسم المرشح') || val == 'المرشح') {
                candidateColIdx = c;
                singleStartRowIdx = r + 1;
              }
            }
          }

          // Fallback to sheet name if we have a candidate column but no list name
          if ((extractedListName == null || extractedListName.isEmpty) && candidateColIdx != null && singleStartRowIdx != -1) {
            extractedListName = table;
          }

          if (extractedListName != null && extractedListName.isNotEmpty && candidateColIdx != null && singleStartRowIdx != -1) {
            for (int r = singleStartRowIdx; r < sheet.maxRows; r++) {
              final row = sheet.rows[r];
              if (candidateColIdx < row.length) {
                final candidateName = row[candidateColIdx]?.value?.toString().trim();
                if (candidateName != null && candidateName.isNotEmpty) {
                  results.add(ListCandidateImportResult(
                    listName: extractedListName,
                    candidateName: candidateName,
                  ));
                }
              }
            }
          }
        }
      }

      return results;
    } catch (e) {
      rethrow;
    }
  }
}
