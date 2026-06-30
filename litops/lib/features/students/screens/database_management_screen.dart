import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';

class DatabaseManagementScreen extends ConsumerWidget {
  const DatabaseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final canReset = role.canResetDatabase;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Database Management', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup, color: Colors.green),
              title: const Text('Backup Database'),
              subtitle: const Text('Create a full backup of student database'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _backupDatabase(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore, color: Colors.blue),
              title: const Text('Restore from Backup'),
              subtitle: const Text('Restore student database from a backup'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRestoreDialog(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: const Text('Import History'),
              subtitle: const Text('View past CSV/Excel imports'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showImportHistory(context),
            ),
          ),
          if (canReset) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                title: Text('Reset Student Database', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                subtitle: const Text('This will delete ALL student records. Only Student President can perform this action.'),
                trailing: const Icon(Icons.warning, color: Colors.red),
                onTap: () => _resetDatabase(context, ref),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _backupDatabase(BuildContext context, WidgetRef ref) async {
    try {
      final students = await SupabaseConfig.client.from(SupabaseTables.studentMaster).select();
      final profile = ref.read(currentProfileProvider);
      if (profile == null) return false;
      
      final list = students as List;
      if (list.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database is empty, no backup created.')));
        }
        return true;
      }

      await SupabaseConfig.client.from(SupabaseTables.studentDatabaseBackups).insert({
        'backup_name': 'Backup ${DateTime.now().toIso8601String().substring(0, 16)}',
        'record_count': list.length,
        'backup_data': list,
        'created_by': profile.id,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup created: ${list.length} records')));
      }
      return true;
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red));
      return false;
    }
  }

  Future<void> _showRestoreDialog(BuildContext context, WidgetRef ref) async {
    final backups = await SupabaseConfig.client.from(SupabaseTables.studentDatabaseBackups).select().order('created_at', ascending: false);
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore from Backup'),
          content: SizedBox(
            width: 400, height: 300,
            child: ListView.builder(
              itemCount: (backups as List).length,
              itemBuilder: (_, i) {
                final b = backups[i];
                return ListTile(
                  title: Text(b['backup_name']),
                  subtitle: Text('${b['record_count']} records'),
                  trailing: ElevatedButton(
                    onPressed: () => _restoreBackup(context, ref, b),
                    child: const Text('Restore'),
                  ),
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref, Map<String, dynamic> backup) async {
    try {
      await SupabaseConfig.client.from(SupabaseTables.studentMaster).delete().neq('id', '00000000-0000-0000-0000-000000000000');
      final rawData = backup['backup_data'];
      final List<dynamic> data = rawData is String ? jsonDecode(rawData) : (rawData as List);
      
      for (final record in data) {
        final studentMap = Map<String, dynamic>.from(record as Map);
        studentMap.remove('id');
        studentMap.remove('created_at');
        studentMap.remove('updated_at');
        await SupabaseConfig.client.from(SupabaseTables.studentMaster).insert(studentMap);
      }
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database restored successfully')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showImportHistory(BuildContext context) async {
    final history = await SupabaseConfig.client.from(SupabaseTables.databaseImportHistory).select().order('created_at', ascending: false);
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import History'),
          content: SizedBox(
            width: 400, height: 400,
            child: ListView.builder(
              itemCount: (history as List).length,
              itemBuilder: (_, i) {
                final h = history[i];
                return ListTile(
                  title: Text(h['file_name']),
                  subtitle: Text('Success: ${h['successful_imports']} | Failed: ${h['failed_imports']}'),
                  trailing: Text(h['file_type'].toString().toUpperCase()),
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
  }

  Future<void> _resetDatabase(BuildContext context, WidgetRef ref) async {
    final confirmCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('RESET DATABASE', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This action is IRREVERSIBLE. All student data will be deleted.'),
            const SizedBox(height: 16),
            TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Enter your password')),
            const SizedBox(height: 16),
            const Text('Type "DELETE STUDENT DATABASE" to confirm:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: confirmCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, confirmCtrl.text == 'DELETE STUDENT DATABASE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A0D05),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Backup first
      final backupSuccess = await _backupDatabase(context, ref);
      if (!backupSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database reset aborted: backup failed.'), backgroundColor: Colors.red));
        }
        return;
      }
      // Then delete
      try {
        await SupabaseConfig.client.from(SupabaseTables.studentMaster).delete().neq('id', '00000000-0000-0000-0000-000000000000');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student database has been reset. A backup was created.')));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
