import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/utils/voter_household_sort.dart';
import '../../../domain/entities/voter.dart';
import '../../../domain/repositories/lookup_repository.dart';
import '../cubit/voters_cubit.dart';

class VoterFormScreen extends StatefulWidget {
  final Voter? voter;

  const VoterFormScreen({super.key, this.voter});

  @override
  State<VoterFormScreen> createState() => _VoterFormScreenState();
}

class _VoterFormScreenState extends State<VoterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _symbolController;
  late TextEditingController _firstNameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _grandFatherNameController;
  late TextEditingController _guardianSymbolController;

  int? _selectedFamilyId;
  int? _selectedSubClanId;
  int? _selectedCenterId;
  String? _selectedHouseholdRole;

  List<dynamic> _families = [];
  List<dynamic> _subClans = [];
  List<dynamic> _centers = [];

  bool _loadingLookups = true;

  bool get _isHouseholdHead => _selectedHouseholdRole == householdRoleHusband;

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(text: widget.voter?.voterSymbol);
    _firstNameController = TextEditingController(text: widget.voter?.firstName);
    _fatherNameController = TextEditingController(text: widget.voter?.fatherName);
    _grandFatherNameController = TextEditingController(
      text: widget.voter?.grandfatherName,
    );
    _guardianSymbolController = TextEditingController(
      text: widget.voter?.householdGroup,
    );

    _selectedFamilyId = widget.voter?.familyId;
    _selectedSubClanId = widget.voter?.subClanId;
    _selectedCenterId = widget.voter?.centerId;
    _selectedHouseholdRole = normalizeHouseholdRole(widget.voter?.householdRole);

    _loadLookups();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _grandFatherNameController.dispose();
    _guardianSymbolController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final repo = sl<LookupRepository>();
    final results = await Future.wait([
      repo.getFamilies(),
      repo.getVotingCenters(),
      if (_selectedFamilyId != null) repo.getSubClans(familyId: _selectedFamilyId),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      (results[0] as dynamic).fold((_) => null, (list) => _families = list);
      (results[1] as dynamic).fold((_) => null, (list) => _centers = list);
      if (results.length > 2) {
        (results[2] as dynamic).fold((_) => null, (list) => _subClans = list);
      }
      _loadingLookups = false;
    });
  }

  Future<void> _loadSubClans(int familyId) async {
    final repo = sl<LookupRepository>();
    final result = await repo.getSubClans(familyId: familyId);
    if (!mounted) {
      return;
    }

    result.fold(
      (_) => setState(() => _subClans = []),
      (list) => setState(() => _subClans = list),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case householdRoleHusband:
        return 'رب المنزل';
      case householdRoleWife:
        return 'زوجة';
      case householdRoleChild:
        return 'ابن/ابنة';
      case householdRoleOther:
        return 'أخرى';
      default:
        return 'غير محدد';
    }
  }

  String? _guardianValidator(String? value) {
    if (_selectedHouseholdRole == null) {
      return null;
    }
    if (_selectedHouseholdRole == householdRoleHusband) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'رقم ولي الأمر مطلوب لهذه الصلة';
    }
    return null;
  }

  String? _resolveHouseholdGroup() {
    final symbol = _symbolController.text.trim();
    final guardian = _guardianSymbolController.text.trim();

    if (_selectedHouseholdRole == null) {
      return guardian.isEmpty ? null : guardian;
    }
    if (_selectedHouseholdRole == householdRoleHusband) {
      return symbol.isEmpty ? null : symbol;
    }
    return guardian.isEmpty ? null : guardian;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.voter == null ? 'إضافة ناخب' : 'تعديل بيانات ناخب'),
      ),
      body: _loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _symbolController,
                      decoration: const InputDecoration(
                        labelText: 'الرقم الانتخابي',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      keyboardType: TextInputType.number,
                      enabled: widget.voter == null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الأول',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fatherNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الأب',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _grandFatherNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedFamilyId,
                      decoration: const InputDecoration(
                        labelText: 'العائلة',
                        border: OutlineInputBorder(),
                      ),
                      items: _families
                          .map(
                            (f) => DropdownMenuItem(
                              value: f.id as int,
                              child: Text(f.familyName),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedFamilyId = val;
                          _selectedSubClanId = null;
                        });
                        if (val != null) {
                          _loadSubClans(val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSubClanId,
                      decoration: const InputDecoration(
                        labelText: 'الفرع',
                        border: OutlineInputBorder(),
                      ),
                      items: _subClans
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id as int,
                              child: Text(s.subName),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedSubClanId = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCenterId,
                      decoration: const InputDecoration(
                        labelText: 'مركز الاقتراع',
                        border: OutlineInputBorder(),
                      ),
                      items: _centers
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id as int,
                              child: Text(c.centerName),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCenterId = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedHouseholdRole,
                      decoration: const InputDecoration(
                        labelText: 'صلة القرابة',
                        border: OutlineInputBorder(),
                      ),
                      items: <String?>[
                        null,
                        householdRoleHusband,
                        householdRoleWife,
                        householdRoleChild,
                        householdRoleOther,
                      ]
                          .map(
                            (role) => DropdownMenuItem<String>(
                              value: role,
                              child: Text(_roleLabel(role)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedHouseholdRole = value;
                          if (value == householdRoleHusband) {
                            _guardianSymbolController.text =
                                _symbolController.text.trim();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _guardianSymbolController,
                      decoration: InputDecoration(
                        labelText: 'رقم ولي الأمر',
                        helperText: _isHouseholdHead
                            ? 'سيتم اعتماد الرقم الانتخابي نفسه لرب المنزل.'
                            : 'أدخل الرقم الانتخابي لرب المنزل أو ولي الأمر.',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !_isHouseholdHead,
                      validator: _guardianValidator,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('حفظ البيانات'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final voter = Voter(
      voterSymbol: _symbolController.text.trim(),
      firstName: _firstNameController.text.trim(),
      fatherName: _fatherNameController.text.trim(),
      grandfatherName: _grandFatherNameController.text.trim(),
      familyId: _selectedFamilyId,
      subClanId: _selectedSubClanId,
      centerId: _selectedCenterId,
      householdGroup: _resolveHouseholdGroup(),
      householdRole: _selectedHouseholdRole,
      status: widget.voter?.status ?? 'لم يصوت',
    );

    final cubit = context.read<VotersCubit>();
    if (widget.voter == null) {
      cubit.createVoter(voter);
    } else {
      cubit.updateVoter(voter);
    }
    Navigator.pop(context);
  }
}
