import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/voter_household_sort.dart';
import '../models/voter_model.dart';

class VoterImportService {
  /// Parses an Excel file and returns a list of VoterModels.
  /// Expects columns in a specific order or with specific headers.
  Future<List<VoterModel>> parseVotersExcel(String filePath) async {
    return compute(_parseExcelIsolate, filePath);
  }

  /// Background isolate parser.
  static List<VoterModel> _parseExcelIsolate(String filePath) {
    try {
      print('DEBUG: VoterImportService: Reading bytes from $filePath');
      final bytes = File(filePath).readAsBytesSync();
      print('DEBUG: VoterImportService: Decoding Excel bytes...');
      final excel = Excel.decodeBytes(bytes);

      final List<VoterModel> voters = [];

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        print(
          'DEBUG: VoterImportService: Processing sheet $table with ${sheet.maxRows} rows.',
        );
        if (sheet.maxRows < 2) {
          continue;
        }

        final headers = sheet.rows.first;
        int? symbolIdx;
        int? firstIdx;
        int? fatherIdx;
        int? grandIdx;
        int? familyIdx;
        int? subClanIdx;
        int? centerIdx;
        int? householdGroupIdx;
        int? householdRoleIdx;

        for (var i = 0; i < headers.length; i++) {
          final value = headers[i]?.value?.toString().toLowerCase().trim() ?? '';
          // ── Check household-specific headers FIRST ──
          // These must be checked before 'رقم' to avoid false matches
          // (e.g. 'رقم ولي الأمر' contains 'رقم')
          if (value.contains('رقم ولي') ||
              value.contains('ولي الأمر') ||
              value.contains('ولي الامر') ||
              value.contains('guardian') ||
              value.contains('parent number') ||
              value.contains('parent no') ||
              value.contains('رب المنزل') ||
              value.contains('head symbol') ||
              value.contains('household group') ||
              value.contains('household_group') ||
              (value.contains('household') && !value.contains('role'))) {
            householdGroupIdx = i;
          } else if (value.contains('relationship') ||
              value.contains('role') ||
              value.contains('صلة') ||
              value.contains('قرابة') ||
              value.contains('household_role') ||
              value.contains('household role')) {
            householdRoleIdx = i;
          } else if (value.contains('symbol') ||
              value.contains('رقم') ||
              value.contains('رمز') ||
              value.contains('هوية') ||
              value.contains('الهوية')) {
            symbolIdx = i;
          } else if (value.contains('first') ||
              value.contains('الاول') ||
              value.contains('الأول')) {
            firstIdx = i;
          } else if (value.contains('father') ||
              value.contains('الاب') ||
              value.contains('الأب')) {
            fatherIdx = i;
          } else if (value.contains('grand') || value.contains('الجد')) {
            grandIdx = i;
          } else if (value.contains('family') || value.contains('عائلة')) {
            familyIdx = i;
          } else if (value.contains('sub') || value.contains('فرع')) {
            subClanIdx = i;
          } else if (value.contains('center') || value.contains('مركز')) {
            centerIdx = i;
          }
        }

        print(
          'DEBUG: VoterImportService: Header indices found -> '
          'symbol: $symbolIdx, first: $firstIdx, father: $fatherIdx, '
          'grand: $grandIdx, family: $familyIdx, sub: $subClanIdx, '
          'center: $centerIdx, householdGroup: $householdGroupIdx, '
          'householdRole: $householdRoleIdx',
        );

        symbolIdx ??= 0;
        firstIdx ??= 1;
        fatherIdx ??= 2;
        grandIdx ??= 3;

        for (var i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) {
            continue;
          }

          final symbolData = row.length > symbolIdx ? row[symbolIdx] : null;
          final symbol = symbolData?.value?.toString().trim();
          if (symbol == null || symbol.isEmpty) {
            continue;
          }

          String? getVal(int? idx) {
            if (idx == null || idx < 0 || idx >= row.length) {
              return null;
            }
            return row[idx]?.value?.toString().trim();
          }

          final importedHouseholdGroup = normalizeHouseholdGroup(
            getVal(householdGroupIdx),
          );
          final explicitHouseholdRole = normalizeHouseholdRole(
            getVal(householdRoleIdx),
          );

          // Only assign household roles when the file actually has
          // household data columns. Otherwise leave null so the import
          // does NOT clobber existing voter data with wrong defaults.
          final bool hasHouseholdColumns =
              householdGroupIdx != null || householdRoleIdx != null;

          final String? resolvedHouseholdRole;
          final String? householdGroup;

          if (!hasHouseholdColumns) {
            // No household columns in file — keep both null
            resolvedHouseholdRole = null;
            householdGroup = null;
          } else {
            resolvedHouseholdRole =
                explicitHouseholdRole ??
                (importedHouseholdGroup == null
                    ? householdRoleHusband
                    : householdRoleChild);

            householdGroup = resolvedHouseholdRole == householdRoleHusband
                ? importedHouseholdGroup ?? symbol
                : importedHouseholdGroup;
          }

          voters.add(
            VoterModel(
              voterSymbol: symbol,
              firstName: getVal(firstIdx),
              fatherName: getVal(fatherIdx),
              grandfatherName: getVal(grandIdx),
              familyName: getVal(familyIdx),
              subClanName: getVal(subClanIdx),
              centerName: getVal(centerIdx),
              householdGroup: householdGroup,
              householdRole: resolvedHouseholdRole,
              status: 'لم يصوت',
            ),
          );
        }
      }

      print(
        'DEBUG: VoterImportService: Finished parsing. Total voters found: ${voters.length}',
      );
      return voters;
    } catch (e, stack) {
      print('DEBUG: VoterImportService: EXCEPTION during Excel parse: $e');
      print('DEBUG: VoterImportService: StackTrace: $stack');
      rethrow;
    }
  }
}
