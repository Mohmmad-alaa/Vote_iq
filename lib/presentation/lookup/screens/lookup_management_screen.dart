import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../../core/utils/pdf_print_service.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/repositories/voter_repository.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/electoral_list.dart';
import '../../../domain/entities/family.dart';
import '../../../domain/entities/sub_clan.dart';
import '../../../domain/entities/voting_center.dart';
import '../cubit/lookup_cubit.dart';
import '../cubit/lookup_state.dart';

class LookupManagementScreen extends StatefulWidget {
  const LookupManagementScreen({super.key});

  @override
  State<LookupManagementScreen> createState() => _LookupManagementScreenState();
}

class _LookupManagementScreenState extends State<LookupManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<LookupCubit>()..loadAll(),
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة البيانات المرجعية'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(child: Text('العائلات',style: TextStyle(color: Colors.white),), ),
                Tab(child: Text('الفروع',style: TextStyle(color: Colors.white),), ),
                Tab(child: Text('المراكز',style: TextStyle(color: Colors.white),), ),
                Tab(child: Text('القوائم',style: TextStyle(color: Colors.white),), ),
                Tab(child: Text('المرشحون',style: TextStyle(color: Colors.white),), ),
              ],
            ),
          ),
          body: BlocConsumer<LookupCubit, LookupState>(
            listener: (context, state) {
              if (state is LookupError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is LookupLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is LookupLoaded) {
                return TabBarView(
                  children: [
                    _FamiliesList(families: state.families),
                    _SubClansList(
                      subClans: state.subClans,
                      families: state.families,
                    ),
                    _CentersList(centers: state.centers),
                    _ElectoralListsList(electoralLists: state.electoralLists),
                    _CandidatesList(
                      candidates: state.candidates,
                      electoralLists: state.electoralLists,
                    ),
                  ],
                );
              }

              return const Center(child: Text('حدث خطأ ما'));
            },
          ),
        ),
      ),
    );
  }
}

class _FamiliesList extends StatefulWidget {
  final List<Family> families;

  const _FamiliesList({required this.families});

  @override
  State<_FamiliesList> createState() => _FamiliesListState();
}

class _FamiliesListState extends State<_FamiliesList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.families
        .where((f) => f.familyName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في العائلات...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('إضافة عائلة جديدة'),
                  onTap: () => _showSimpleAddDialog(
                    context,
                    title: 'إضافة عائلة',
                    label: 'اسم العائلة',
                    onSubmit: (name) => context.read<LookupCubit>().addFamily(name),
                  ),
                );
              }

              final family = filteredList[index - 1];
              return ListTile(
                title: Text(family.familyName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.blue),
                      tooltip: 'طباعة كشف ناخبي العائلة',
                      onPressed: () => _printFamilyVoters(context, family),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'حذف العائلة',
                      onPressed: () => _confirmDeleteFamily(context, family),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _printFamilyVoters(BuildContext context, Family family) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch all voters for this family
      final filter = VoterFilter(familyIds: [family.id], pageSize: 100000);
      final result = await sl<VoterRepository>().getVoters(filter);
      
      if (context.mounted) Navigator.pop(context);

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل جلب الناخبين: ${failure.message}')),
            );
          }
        },
        (voters) {
          PdfPrintService.printVotersList('كشف ناخبين - عائلة ${family.familyName}', voters);
        }
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز الطباعة: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteFamily(BuildContext context, Family family) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف عائلة "${family.familyName}"؟\n\nسيؤدي هذا إلى حذف العائلة وجميع الفروع والناخبين المرتبطين بها نهائياً ولن تتمكن من التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<LookupCubit>().deleteFamily(family.id);
    }
  }
}

class _SubClansList extends StatefulWidget {
  final List<SubClan> subClans;
  final List<Family> families;

  const _SubClansList({
    required this.subClans,
    required this.families,
  });

  @override
  State<_SubClansList> createState() => _SubClansListState();
}

class _SubClansListState extends State<_SubClansList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.subClans
        .where((s) => s.subName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                      (s.familyName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في الفروع...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('إضافة فرع جديد'),
                  onTap: () => _showAddSubClanDialog(context, widget.families),
                );
              }

              final subClan = filteredList[index - 1];
              return ListTile(
                title: Text(subClan.subName),
                subtitle: Text(subClan.familyName ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.blue),
                      tooltip: 'طباعة كشف ناخبي الفرع',
                      onPressed: () => _printSubClanVoters(context, subClan),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'حذف الفرع',
                      onPressed: () => _confirmDeleteSubClan(context, subClan),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _printSubClanVoters(BuildContext context, SubClan subClan) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch all voters for this sub-clan
      final filter = VoterFilter(subClanId: subClan.id, pageSize: 100000);
      final result = await sl<VoterRepository>().getVoters(filter);
      
      if (context.mounted) Navigator.pop(context);

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل جلب الناخبين: ${failure.message}')),
            );
          }
        },
        (voters) {
          PdfPrintService.printVotersList('كشف ناخبين - فرع ${subClan.subName}', voters);
        }
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز الطباعة: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteSubClan(BuildContext context, SubClan subClan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الفرع "${subClan.subName}"؟\n\nالناخبون التابعون لهذا الفرع لن يتم حذفهم، بل سيتم إعادتهم إلى العائلة الرئيسية بدون فرع محدد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<LookupCubit>().deleteSubClan(subClan.id);
    }
  }
}

class _CentersList extends StatefulWidget {
  final List<VotingCenter> centers;

  const _CentersList({required this.centers});

  @override
  State<_CentersList> createState() => _CentersListState();
}

class _CentersListState extends State<_CentersList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.centers
        .where((c) => c.centerName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في المراكز...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('إضافة مركز جديد'),
                  onTap: () => _showSimpleAddDialog(
                    context,
                    title: 'إضافة مركز',
                    label: 'اسم المركز',
                    onSubmit: (name) =>
                        context.read<LookupCubit>().addVotingCenter(name),
                  ),
                );
              }

              final center = filteredList[index - 1];
              return ListTile(
                title: Text(center.centerName),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () =>
                      context.read<LookupCubit>().deleteVotingCenter(center.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ElectoralListsList extends StatefulWidget {
  final List<ElectoralList> electoralLists;

  const _ElectoralListsList({required this.electoralLists});

  @override
  State<_ElectoralListsList> createState() => _ElectoralListsListState();
}

class _ElectoralListsListState extends State<_ElectoralListsList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.electoralLists
        .where((e) => e.listName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في القوائم...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('إضافة قائمة انتخابية'),
                  onTap: () => _showSimpleAddDialog(
                    context,
                    title: 'إضافة قائمة انتخابية',
                    label: 'اسم القائمة',
                    onSubmit: (name) =>
                        context.read<LookupCubit>().addElectoralList(name),
                  ),
                );
              }

              final electoralList = filteredList[index - 1];
              return ListTile(
                title: Text(electoralList.listName),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => context
                      .read<LookupCubit>()
                      .deleteElectoralList(electoralList.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CandidatesList extends StatefulWidget {
  final List<Candidate> candidates;
  final List<ElectoralList> electoralLists;

  const _CandidatesList({
    required this.candidates,
    required this.electoralLists,
  });

  @override
  State<_CandidatesList> createState() => _CandidatesListState();
}

class _CandidatesListState extends State<_CandidatesList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.candidates
        .where((c) => c.candidateName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في المرشحين...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredList.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('إضافة مرشح'),
                  onTap: () => _showAddCandidateDialog(context, widget.electoralLists),
                );
              }

              if (index == 1) {
                return ListTile(
                  leading: const Icon(Icons.file_upload, color: Colors.orange),
                  title: const Text('استيراد القوائم والمرشحين من إكسل'),
                  onTap: () => _importListsFromExcel(context),
                );
              }

              final candidate = filteredList[index - 2];
              final listName = candidate.listName ??
                  widget.electoralLists
                      .where((item) => item.id == candidate.listId)
                      .map((item) => item.listName)
                      .cast<String?>()
                      .firstOrNull;

              return ListTile(
                title: Text(candidate.candidateName),
                subtitle: Text(listName ?? 'بدون قائمة محددة'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () =>
                      context.read<LookupCubit>().deleteCandidate(candidate.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _importListsFromExcel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        context.read<LookupCubit>().importListsAndCandidates(result.files.single.path!);
      }
    }
  }
}

void _showSimpleAddDialog(
  BuildContext context, {
  required String title,
  required String label,
  required void Function(String value) onSubmit,
}) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            onSubmit(value);
            Navigator.pop(dialogContext);
          },
          child: const Text('إضافة'),
        ),
      ],
    ),
  );
}

void _showAddSubClanDialog(BuildContext context, List<Family> families) {
  final controller = TextEditingController();
  Family? selectedFamily;
  final cubit = context.read<LookupCubit>();

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('إضافة فرع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownSearch<Family>(
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عائلة...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              items: (filter, loadProps) {
                if (filter.isEmpty) return families;
                return families
                    .where((f) => f.familyName.toLowerCase().contains(filter.toLowerCase()))
                    .toList();
              },
              itemAsString: (Family family) => family.familyName,
              compareFn: (item, selectedItem) => item.id == selectedItem.id,
              onChanged: (value) => setState(() => selectedFamily = value),
              selectedItem: selectedFamily,
              dropdownBuilder: (context, selectedItem) {
                return InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "العائلة",
                    border: OutlineInputBorder(),
                  ),
                  child: Text(selectedItem?.familyName ?? ''),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'اسم الفرع'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty || selectedFamily == null) return;
              cubit.addSubClan(selectedFamily!.id, value);
              Navigator.pop(dialogContext);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    ),
  );
}

void _showAddCandidateDialog(
  BuildContext context,
  List<ElectoralList> electoralLists,
) {
  final controller = TextEditingController();
  ElectoralList? selectedList;
  final cubit = context.read<LookupCubit>();

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('إضافة مرشح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'اسم المرشح'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ElectoralList?>(
              initialValue: selectedList,
              decoration: const InputDecoration(
                labelText: 'القائمة الانتخابية',
              ),
              items: [
                const DropdownMenuItem<ElectoralList?>(
                  value: null,
                  child: Text('بدون قائمة'),
                ),
                ...electoralLists.map(
                  (electoralList) => DropdownMenuItem<ElectoralList?>(
                    value: electoralList,
                    child: Text(electoralList.listName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => selectedList = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              cubit.addCandidate(value, listId: selectedList?.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    ),
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
