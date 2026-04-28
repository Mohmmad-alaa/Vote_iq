import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/voters_cubit.dart';
import '../cubit/voters_state.dart';

enum ImportMode { full, household, subClan }

class VoterImportScreen extends StatefulWidget {
  const VoterImportScreen({super.key});

  @override
  State<VoterImportScreen> createState() => _VoterImportScreenState();
}

class _VoterImportScreenState extends State<VoterImportScreen> {
  String? _filePath;
  bool _isPicking = false;
  ImportMode _importMode = ImportMode.subClan;
  ImportMode _lastActionWas = ImportMode.subClan;

  Future<void> _pickFile() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _filePath = result.files.single.path);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الملف: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  String _instructionsText() {
    switch (_importMode) {
      case ImportMode.household:
        return 'سيتم تحديث رقم ولي الأمر وصلة القرابة فقط للناخبين الموجودين مسبقًا.\n\n'
            'الأعمدة المطلوبة: (رقم الهوية/الانتخابي، رقم ولي الأمر، صلة القرابة)';
      case ImportMode.subClan:
        return 'سيتم تحديث العائلة والفرع فقط للناخبين الموجودين مسبقًا.\n\n'
            'الأعمدة المطلوبة: (رقم الهوية/الانتخابي، العائلة، الفرع)';
      case ImportMode.full:
        return 'سيتم تنفيذ استيراد كامل للسجلات، وقد يتم تصفير حالة التصويت.\n\n'
            'استخدم هذا الخيار فقط لإدخال بيانات ناخبين جديدة كلياً.';
    }
  }

  void _startImport() {
    if (_filePath == null) {
      return;
    }

    final cubit = context.read<VotersCubit>();
    setState(() => _lastActionWas = _importMode);

    switch (_importMode) {
      case ImportMode.household:
        cubit.importVoterHouseholdData(_filePath!);
        break;
      case ImportMode.subClan:
        cubit.importVoterSubClans(_filePath!);
        break;
      case ImportMode.full:
        cubit.importVoters(_filePath!);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VotersCubit, VotersState>(
      listenWhen: (previous, current) {
        return previous is VotersLoading &&
            (current is VotersLoaded || current is VotersError);
      },
      listener: (context, state) {
        if (state is VotersLoaded) {
          String message = 'تم استيراد البيانات بنجاح';
          if (_lastActionWas == ImportMode.household) {
            message = 'تم تحديث بيانات الأسرة بنجاح';
          } else if (_lastActionWas == ImportMode.subClan) {
            message = 'تم تحديث العائلات والفروع بنجاح';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          Navigator.pop(context);
        } else if (state is VotersError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('استيراد ناخبين من Excel')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _importMode == ImportMode.full
                    ? Icons.upload_file
                    : Icons.shield_outlined,
                size: 60,
                color: _importMode == ImportMode.full
                    ? Colors.blueAccent
                    : Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'نوع الاستيراد:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ImportMode>(
                segments: const [
                  ButtonSegment(
                    value: ImportMode.full,
                    label: Text('كامل'),
                    icon: Icon(Icons.warning_amber),
                  ),
                  ButtonSegment(
                    value: ImportMode.household,
                    label: Text('الأسرة'),
                    icon: Icon(Icons.family_restroom),
                  ),
                  ButtonSegment(
                    value: ImportMode.subClan,
                    label: Text('الفروع'),
                    icon: Icon(Icons.account_tree),
                  ),
                ],
                selected: {_importMode},
                onSelectionChanged: (Set<ImportMode> newSelection) {
                  setState(() {
                    _importMode = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              Text(
                _instructionsText(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 36),
              OutlinedButton.icon(
                onPressed: _isPicking ? null : _pickFile,
                icon: const Icon(Icons.file_open),
                label: Text(_filePath ?? 'اختر ملف Excel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _filePath == null ? null : _startImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _importMode == ImportMode.full ? null : Colors.green,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _importMode == ImportMode.full
                      ? 'بدء الاستيراد الكامل'
                      : 'بدء التحديث الآمن',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              if (context.watch<VotersCubit>().state is VotersLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
