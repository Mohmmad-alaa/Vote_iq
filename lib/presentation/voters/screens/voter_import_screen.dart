import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/voters_cubit.dart';
import '../cubit/voters_state.dart';

class VoterImportScreen extends StatefulWidget {
  const VoterImportScreen({super.key});

  @override
  State<VoterImportScreen> createState() => _VoterImportScreenState();
}

class _VoterImportScreenState extends State<VoterImportScreen> {
  String? _filePath;
  bool _isPicking = false;

  Future<void> _pickFile() async {
    print('DEBUG: _pickFile called. Sets _isPicking to true.');
    setState(() => _isPicking = true);
    try {
      print('DEBUG: Calling FilePicker.platform.pickFiles...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      print('DEBUG: FilePicker returned. Result is null? \${result == null}');

      if (result != null && result.files.single.path != null) {
        print('DEBUG: File selected: \${result.files.single.path}');
        setState(() => _filePath = result.files.single.path);
      } else {
        print('DEBUG: User canceled file picking.');
      }
    } catch (e) {
      print('DEBUG: FilePicker EXCEPTION: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الملف: $e')),
        );
      }
    } finally {
      print('DEBUG: _pickFile finally block. Sets _isPicking to false.');
      setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VotersCubit, VotersState>(
      listenWhen: (previous, current) {
        // Prevents the screen from closing automatically just because the cubit is already in VotersLoaded state.
        return previous is VotersLoading && (current is VotersLoaded || current is VotersError);
      },
      listener: (context, state) {
        if (state is VotersLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استيراد البيانات بنجاح')),
          );
          Navigator.pop(context);
        } else if (state is VotersError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('استيراد ناخبين (Excel)')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.upload_file, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'قم باختيار ملف Excel يحتوي على بيانات الناخبين.\n\nتأكد من وجود الأعمدة التالية باللغة العربية:\n(رمز العائلة، الاسم الأول، اسم الأب، اسم الجد، العائلة، الفرع، المركز)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 48),
              OutlinedButton.icon(
                onPressed: _isPicking ? null : _pickFile,
                icon: const Icon(Icons.file_open),
                label: Text(_filePath ?? 'اختر ملف Excel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _filePath == null
                    ? null
                    : () => context.read<VotersCubit>().importVoters(_filePath!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('بدء الاستيراد', style: TextStyle(fontSize: 18)),
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
