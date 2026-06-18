import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});
  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usnCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _branch = 'CSE';
  int _year = 1;
  String _section = 'A';
  bool _saving = false;

  @override
  void dispose() {
    _usnCtrl.dispose(); _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SupabaseConfig.client.from(SupabaseTables.studentMaster).insert({
        'usn': _usnCtrl.text.trim().toUpperCase(),
        'name': _nameCtrl.text.trim(),
        'branch': _branch,
        'year': _year,
        'section': _section,
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'status': 'active',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student added')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Add Student', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _usnCtrl, decoration: const InputDecoration(labelText: 'USN *'), textCapitalization: TextCapitalization.characters, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(initialValue: _branch, decoration: const InputDecoration(labelText: 'Branch'), items: AppUtils.branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(), onChanged: (v) => setState(() => _branch = v!)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(initialValue: _year, decoration: const InputDecoration(labelText: 'Year'), items: AppUtils.years.map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(), onChanged: (v) => setState(() => _year = v!)),
            const SizedBox(height: 16),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _section,
              decoration: const InputDecoration(labelText: 'Section'),
              onChanged: (v) => _section = v,
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator() : const Text('Add Student'))),
          ],
        ),
      ),
    );
  }
}
