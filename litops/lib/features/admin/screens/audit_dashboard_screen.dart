import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/admin_providers.dart';

class AuditDashboardScreen extends ConsumerStatefulWidget {
  const AuditDashboardScreen({super.key});

  @override
  ConsumerState<AuditDashboardScreen> createState() => _AuditDashboardScreenState();
}

class _AuditDashboardScreenState extends ConsumerState<AuditDashboardScreen> {
  String _searchQuery = '';
  String _actionFilter = 'All';
  String _entityFilter = 'All';

  final List<String> _actions = ['All', 'CREATE', 'UPDATE', 'DELETE'];
  final List<String> _entities = [
    'All',
    'member_assignments',
    'event_points',
    'event_schedules',
    'yearly_archives',
    'yearly_imports',
    'profiles',
    'sarvottam_points'
  ];

  @override
  Widget build(BuildContext context) {
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Governance Audit Logs'),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          // Filter section
          _buildFilters(),

          // List of Audit logs
          Expanded(
            child: auditLogsAsync.when(
              data: (logs) {
                final filtered = logs.where((log) {
                  // Email match
                  final emailMatches = log.userEmail?.toLowerCase().contains(_searchQuery) ?? true;
                  final actionMatches = _actionFilter == 'All' || log.action.toUpperCase() == _actionFilter;
                  final entityMatches = _entityFilter == 'All' || log.entityType.toLowerCase() == _entityFilter;
                  return emailMatches && actionMatches && entityMatches;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyView(
                    icon: Icons.history_rounded,
                    title: 'No audit records found',
                    subtitle: 'Try adjusting the search query or category filters.',
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return _buildAuditCard(log);
                  },
                );
              },
              loading: () => const LoadingView(message: 'Loading secure logs...'),
              error: (e, _) => ErrorView(
                message: 'Failed to retrieve logs: $e',
                onRetry: () => ref.invalidate(auditLogsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          // Search input
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by operator email...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),

          // Dropdown filters row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _actionFilter,
                      dropdownColor: const Color(0xFF131324),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      onChanged: (val) {
                        if (val != null) setState(() => _actionFilter = val);
                      },
                      items: _actions.map((act) {
                        return DropdownMenuItem(value: act, child: Text(act));
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _entityFilter,
                      dropdownColor: const Color(0xFF131324),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      isExpanded: true,
                      onChanged: (val) {
                        if (val != null) setState(() => _entityFilter = val);
                      },
                      items: _entities.map((ent) {
                        return DropdownMenuItem(
                          value: ent,
                          child: Text(
                            ent == 'All' ? 'All Tables' : ent,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(AuditExtended log) {
    final dateStr = DateFormat('MMM d, h:mm:ss a').format(log.createdAt);

    IconData actionIcon;
    Color iconColor;
    switch (log.action.toUpperCase()) {
      case 'CREATE':
        actionIcon = Icons.add_circle_outline_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case 'UPDATE':
        actionIcon = Icons.edit_note_rounded;
        iconColor = const Color(0xFF3B82F6);
        break;
      case 'DELETE':
        actionIcon = Icons.remove_circle_outline_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
      default:
        actionIcon = Icons.history_rounded;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAuditDetails(log),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(actionIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${log.action} ${log.entityType.toUpperCase()}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Operator: ${log.userEmail ?? "System Trigger"}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF6366F1),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Entity ID: ${log.entityId ?? "N/A"}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAuditDetails(AuditExtended log) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Audit Log Metadata',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildMetadataRow('Operation', log.action),
                _buildMetadataRow('Entity Type', log.entityType),
                _buildMetadataRow('Timestamp', DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt)),
                _buildMetadataRow('Operator Email', log.userEmail ?? 'System / Anonymous'),
                if (log.ipAddress != null) _buildMetadataRow('IP Address', log.ipAddress!),
                if (log.deviceInfo != null) _buildMetadataRow('Device Info', log.deviceInfo!),
                const SizedBox(height: 16),
                
                // Diff Values
                if (log.previousValue != null) ...[
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  const Text(
                    'Previous State',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _buildJsonBlock(log.previousValue!),
                ],
                if (log.newValue != null) ...[
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  const Text(
                    'New State',
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  _buildJsonBlock(log.newValue!),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetadataRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$key:',
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonBlock(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    final formatted = encoder.convert(data);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        formatted,
        style: GoogleFonts.firaCode(
          color: Colors.white70,
          fontSize: 10,
        ),
      ),
    );
  }
}
