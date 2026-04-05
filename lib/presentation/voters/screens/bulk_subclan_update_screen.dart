import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/voter.dart';
import '../../../core/di/injection_container.dart';
import '../../lookup/cubit/lookup_cubit.dart';
import '../../lookup/cubit/lookup_state.dart';
import '../cubit/voters_cubit.dart';
import '../cubit/voters_state.dart';

class BulkSubClanUpdateScreen extends StatefulWidget {
  const BulkSubClanUpdateScreen({super.key});

  @override
  State<BulkSubClanUpdateScreen> createState() => _BulkSubClanUpdateScreenState();
}

class _BulkSubClanUpdateScreenState extends State<BulkSubClanUpdateScreen> {
  final Set<String> _selectedSymbols = {};
  final TextEditingController _familySearchController = TextEditingController();
  int? _selectedFamilyId;
  int? _selectedSubClanId;
  String _familySearchQuery = '';
  String _voterSearchText = '';
  bool _familyDropdownOpen = false;
  bool _isRemoveMode = false;
  bool _subClanDropdownOpen = false;

  void _updateSelection(String symbol, bool selected) {
    setState(() {
      if (selected) {
        _selectedSymbols.add(symbol);
      } else {
        _selectedSymbols.remove(symbol);
      }
    });
  }

  void _selectAll(bool select, List<Voter> voters) {
    setState(() {
      if (select) {
        _selectedSymbols.addAll(voters.map((v) => v.voterSymbol));
      } else {
        _selectedSymbols.clear();
      }
    });
  }

  List<Voter> _getFilteredVoters(VotersState votersState) {
    if (votersState is VotersLoaded) {
      if (_isRemoveMode) {
        return votersState.voters
            .where((v) => v.subClanId != null)
            .where((v) => _voterSearchText.isEmpty || v.fullName.contains(_voterSearchText))
            .toList();
      } else {
        return votersState.voters
            .where((v) => v.subClanId == null)
            .where((v) => _voterSearchText.isEmpty || v.fullName.contains(_voterSearchText))
            .toList();
      }
    }
    return [];
  }

  Future<void> _applyUpdate(BuildContext context, LookupLoaded lookupState, List<Voter> voters) async {
    if (_selectedSymbols.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد ناخبين أولاً'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isRemoveMode) {
      final cubit = context.read<VotersCubit>();
      final messenger = ScaffoldMessenger.of(context);
      int successCount = 0;

      for (final voter in voters) {
        if (_selectedSymbols.contains(voter.voterSymbol)) {
          final updatedVoter = Voter(
            voterSymbol: voter.voterSymbol,
            firstName: voter.firstName,
            fatherName: voter.fatherName,
            grandfatherName: voter.grandfatherName,
            familyId: voter.familyId,
            subClanId: null,
            centerId: voter.centerId,
            status: voter.status,
            refusalReason: voter.refusalReason,
            updatedAt: voter.updatedAt,
            updatedBy: voter.updatedBy,
            familyName: voter.familyName,
            subClanName: null,
            centerName: voter.centerName,
          );
          await cubit.updateVoter(updatedVoter);
          successCount++;
        }
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('تم حذف $successCount ناخب من الفروع بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedSymbols.clear();
      });
      return;
    }

    if (_selectedFamilyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار العائلة أولاً'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedSubClanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الفرع أولاً'), backgroundColor: Colors.orange),
      );
      return;
    }

    final cubit = context.read<VotersCubit>();
    final messenger = ScaffoldMessenger.of(context);
    int successCount = 0;

    for (final voter in voters) {
      if (_selectedSymbols.contains(voter.voterSymbol)) {
        final updatedVoter = Voter(
          voterSymbol: voter.voterSymbol,
          firstName: voter.firstName,
          fatherName: voter.fatherName,
          grandfatherName: voter.grandfatherName,
          familyId: _selectedFamilyId,
          subClanId: _selectedSubClanId,
          centerId: voter.centerId,
          status: voter.status,
          refusalReason: voter.refusalReason,
          updatedAt: voter.updatedAt,
          updatedBy: voter.updatedBy,
          familyName: voter.familyName,
          subClanName: voter.subClanName,
          centerName: voter.centerName,
        );
        await cubit.updateVoter(updatedVoter);
        successCount++;
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('تم تحديث الفرع لـ $successCount ناخب بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {
      _selectedSymbols.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LookupCubit>()..loadAll(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحديث الفروع جماعياً'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: Text(
                  '${_selectedSymbols.length} محدد',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        body: BlocBuilder<VotersCubit, VotersState>(
          builder: (context, votersState) {
            return BlocBuilder<LookupCubit, LookupState>(
              builder: (context, lookupState) {
                if (lookupState is! LookupLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.scaffoldBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text('حذف من الفرع', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Switch(
                                value: _isRemoveMode,
                                onChanged: (val) => setState(() {
                                  _isRemoveMode = val;
                                  _selectedFamilyId = null;
                                  _selectedSubClanId = null;
                                  _selectedSymbols.clear();
                                }),
                                activeColor: Colors.red,
                              ),
                              const Spacer(),
                              if (_isRemoveMode)
                                const Text('وضع الحذف مفعل', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!_isRemoveMode) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildSearchableFamilyDropdown(lookupState),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSubClanDropdown(lookupState),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton.icon(
                            onPressed: () => _applyUpdate(context, lookupState, _getFilteredVoters(votersState)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRemoveMode ? Colors.red : AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(_isRemoveMode ? Icons.remove_circle : Icons.check, color: Colors.white),
                            label: Text(
                              _isRemoveMode
                                  ? 'حذف من الفرع لـ ${_selectedSymbols.length} ناخب'
                                  : 'تطبيق على ${_selectedSymbols.length} ناخب',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.white,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: _isRemoveMode ? 'ابحث عن ناخب في فرع...' : 'ابحث عن ناخب بدون فرع...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _voterSearchText = val;
                          });
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey.shade200,
                      child: Row(
                        children: [
                          Checkbox(
                            value: _getFilteredVoters(votersState).isNotEmpty &&
                                _selectedSymbols.length == _getFilteredVoters(votersState).length,
                            tristate: true,
                            onChanged: (val) => _selectAll(val ?? false, _getFilteredVoters(votersState)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تحديد الكل (${_getFilteredVoters(votersState).length} نتيجة مطابقة)',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _getFilteredVoters(votersState).isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                                  SizedBox(height: 16),
                                  Text(
                                    'لا توجد نتائج مطابقة', 
                                    style: TextStyle(fontSize: 16)
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _getFilteredVoters(votersState).length,
                              itemBuilder: (context, index) {
                                final voter = _getFilteredVoters(votersState)[index];
                                final isSelected = _selectedSymbols.contains(voter.voterSymbol);
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: isSelected,
                                      onChanged: (val) => _updateSelection(voter.voterSymbol, val ?? false),
                                    ),
                                    title: Text(voter.fullName.isNotEmpty ? voter.fullName : 'بدون اسم'),
                                    subtitle: Text(
                                      '${voter.familyName ?? 'غير محدد'} ${voter.subClanName != null ? ' / ${voter.subClanName}' : ''}',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                    trailing: Text(
                                      voter.voterSymbol,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchableFamilyDropdown(LookupLoaded lookupState) {
    final filteredFamilies = _familySearchQuery.isEmpty
        ? lookupState.families
        : lookupState.families
            .where((f) => f.familyName.toLowerCase().contains(_familySearchQuery.toLowerCase()))
            .toList();

    return GestureDetector(
      onTap: () {
        setState(() {
          _familyDropdownOpen = !_familyDropdownOpen;
          if (_familyDropdownOpen) _subClanDropdownOpen = false;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _familyDropdownOpen
                        ? TextField(
                            controller: _familySearchController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'ابحث عن عائلة...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) => setState(() => _familySearchQuery = val),
                          )
                        : Text(
                            _selectedFamilyId != null && lookupState.families.isNotEmpty
                                ? (lookupState.families.any((f) => f.id == _selectedFamilyId)
                                    ? lookupState.families.firstWhere((f) => f.id == _selectedFamilyId).familyName
                                    : lookupState.families.first.familyName)
                                : 'اختر العائلة',
                            style: TextStyle(
                              color: _selectedFamilyId != null
                                  ? AppColors.textPrimary
                                  : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  Icon(
                    _familyDropdownOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            if (_familyDropdownOpen) ...[
              const Divider(height: 1),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredFamilies.length,
                  itemBuilder: (context, index) {
                    final family = filteredFamilies[index];
                    final isSelected = _selectedFamilyId == family.id;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      title: Text(family.familyName),
                      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () {
                        setState(() {
                          _selectedFamilyId = family.id;
                          _selectedSubClanId = null;
                          _familyDropdownOpen = false;
                          _familySearchQuery = '';
                          _familySearchController.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubClanDropdown(LookupLoaded lookupState) {
    List<dynamic> subClansForFamily = [];
    if (_selectedFamilyId != null) {
      subClansForFamily = lookupState.subClans
          .where((s) => s.familyId == _selectedFamilyId)
          .toList();
    }

    return GestureDetector(
      onTap: () {
        if (_selectedFamilyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى اختيار العائلة أولاً'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (subClansForFamily.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد فروع مسجلة لهذه العائلة'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          setState(() {
            _subClanDropdownOpen = !_subClanDropdownOpen;
            if (_subClanDropdownOpen) _familyDropdownOpen = false;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _selectedFamilyId == null ? Colors.grey.shade100 : Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedSubClanId != null && lookupState.subClans.isNotEmpty
                          ? (lookupState.subClans.any((s) => s.id == _selectedSubClanId)
                              ? lookupState.subClans.firstWhere((s) => s.id == _selectedSubClanId).subName
                              : lookupState.subClans.first.subName)
                          : 'اختر الفرع',
                      style: TextStyle(
                        color: _selectedSubClanId != null
                            ? AppColors.textPrimary
                            : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _subClanDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: _selectedFamilyId == null ? Colors.grey.shade400 : Colors.grey,
                  ),
                ],
              ),
            ),
            if (_subClanDropdownOpen && subClansForFamily.isNotEmpty) ...[
              const Divider(height: 1),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: subClansForFamily.length,
                  itemBuilder: (context, index) {
                    final subClan = subClansForFamily[index];
                    final isSelected = _selectedSubClanId == subClan.id;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      title: Text(subClan.subName),
                      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () {
                        setState(() {
                          _selectedSubClanId = subClan.id;
                          _subClanDropdownOpen = false;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _familySearchController.dispose();
    super.dispose();
  }
}
