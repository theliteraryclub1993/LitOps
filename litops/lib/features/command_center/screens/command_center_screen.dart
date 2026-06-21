import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class CommandCenterScreen extends ConsumerStatefulWidget {
  final String eventId;
  const CommandCenterScreen({super.key, required this.eventId});
  @override
  ConsumerState<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends ConsumerState<CommandCenterScreen> {
  Event? _event;
  int _regCount = 0;
  int _attCount = 0;
  int _waitCount = 0;
  List<Announcement> _announcements = [];
  List<Incident> _incidents = [];
  RealtimeChannel? _realtimeSub;

  @override
  void initState() { super.initState(); _loadData(); _setupRealtime(); }

  Future<void> _loadData() async {
    final eventData = await SupabaseConfig.client.from(SupabaseTables.events).select().eq('id', widget.eventId).single();
    final regs = await SupabaseConfig.client.from(SupabaseTables.registrations).select('id').eq('event_id', widget.eventId).eq('is_cancelled', false);
    final att = await SupabaseConfig.client.from(SupabaseTables.attendance).select('id').eq('event_id', widget.eventId);
    final wait = await SupabaseConfig.client.from(SupabaseTables.waitingList).select('id').eq('event_id', widget.eventId).eq('is_promoted', false);
    final annData = await SupabaseConfig.client.from(SupabaseTables.announcements).select().eq('event_id', widget.eventId).order('created_at', ascending: false);
    final incData = await SupabaseConfig.client.from(SupabaseTables.incidents).select().eq('event_id', widget.eventId).order('created_at', ascending: false);

    setState(() {
      _event = Event.fromJson(eventData);
      _regCount = (regs as List).length;
      _attCount = (att as List).length;
      _waitCount = (wait as List).length;
      _announcements = (annData as List).map((a) => Announcement.fromJson(a)).toList();
      _incidents = (incData as List).map((i) => Incident.fromJson(i)).toList();
    });
  }

  void _setupRealtime() {
    _realtimeSub = SupabaseConfig.client.channel('command_center_${widget.eventId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseTables.registrations,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseTables.attendance,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) => _loadData(),
        )

        .subscribe();
  }

  @override
  void dispose() { if (_realtimeSub != null) SupabaseConfig.client.removeChannel(_realtimeSub!); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _event != null ? 'Command Center: ${_event!.name}' : 'Command Center',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: r.sp(16), color: LitColors.bone),
        ),
      ),
      body: _event == null ? const LoadingView() : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: r.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Stats Grid layout
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: r.gridColumns(small: 2, medium: 3, large: 4),
                crossAxisSpacing: r.w(8),
                mainAxisSpacing: r.w(8),
                childAspectRatio: 1.5,
                children: [
                  StatCard(title: 'Registrations', value: '$_regCount', icon: Icons.people),
                  StatCard(title: 'Attendance', value: '$_attCount', icon: Icons.check_circle),
                  StatCard(title: 'Waiting', value: '$_waitCount', icon: Icons.hourglass_empty),
                  StatCard(title: 'Attendance %', value: _regCount > 0 ? '${((_attCount / _regCount) * 100).toStringAsFixed(0)}%' : '0%', icon: Icons.pie_chart),
                  StatCard(title: 'Status', value: _event!.status.label, icon: Icons.info),
                  StatCard(title: 'Incidents', value: '${_incidents.length}', icon: Icons.warning),
                ],
              ),
              SizedBox(height: r.h(20)),

              // Announcements Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Announcements', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: r.sp(15), color: LitColors.bone)),
                  IconButton(
                    icon: Icon(Icons.add, color: LitColors.ember, size: r.icon(20)),
                    onPressed: _addAnnouncement,
                  ),
                ],
              ),
              SizedBox(height: r.h(8)),
              if (_announcements.isEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: r.h(16)),
                  child: Text('No announcements posted yet.', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12))),
                ),
              ..._announcements.map((a) => ClayCard(
                    margin: EdgeInsets.only(bottom: r.h(10)),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: EdgeInsets.all(r.w(8)),
                        decoration: const BoxDecoration(
                          color: LitColors.clay2,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.campaign, color: a.priority >= 3 ? LitColors.coral : LitColors.amber, size: r.icon(20)),
                      ),
                      title: Text(a.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: LitColors.bone, fontSize: r.sp(13.5))),
                      subtitle: Text(
                        '${a.message}\n${AppUtils.formatTimeAgo(a.createdAt)}',
                        style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(11.5)),
                      ),
                    ),
                  )),

              SizedBox(height: r.h(16)),
              // Incidents Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Incidents', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: r.sp(15), color: LitColors.bone)),
                  IconButton(
                    icon: Icon(Icons.add, color: LitColors.coral, size: r.icon(20)),
                    onPressed: _addIncident,
                  ),
                ],
              ),
              SizedBox(height: r.h(8)),
              if (_incidents.isEmpty)
                Text('No incident reports.', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12))),
              ..._incidents.map((i) => ClayCard(
                    margin: EdgeInsets.only(bottom: r.h(10)),
                    borderColor: i.resolved ? LitColors.moss.withValues(alpha: 0.4) : LitColors.coral.withValues(alpha: 0.4),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        i.resolved ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                        color: i.resolved ? LitColors.moss : LitColors.coral,
                        size: r.icon(24),
                      ),
                      title: Text(i.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: LitColors.bone, fontSize: r.sp(13.5))),
                      subtitle: Text(
                        '${i.description}\nSeverity: ${i.severity}/5',
                        style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(11.5)),
                      ),
                      trailing: i.resolved
                          ? const StatusChip(label: 'Resolved')
                          : IconButton(
                              icon: const Icon(Icons.check, color: LitColors.moss),
                              onPressed: () async {
                                await SupabaseConfig.client.from(SupabaseTables.incidents).update({'resolved': true}).eq('id', i.id);
                                _loadData();
                              },
                            ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _addAnnouncement() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LitColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.radius(20)),
          side: const BorderSide(color: LitColors.border, width: 1.3),
        ),
        title: Text('New Announcement', style: GoogleFonts.fredoka(color: LitColors.bone, fontSize: r.sp(16))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClayTextField(controller: titleCtrl, hintText: 'Title'),
            SizedBox(height: r.h(10)),
            ClayTextField(controller: msgCtrl, hintText: 'Message'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: LitColors.ash)),
          ),
          ClayButton(
            width: r.w(80),
            height: r.h(38),
            onPressed: () async {
              if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
              final profile = ref.read(currentProfileProvider);
              await SupabaseConfig.client.from(SupabaseTables.announcements).insert({
                'event_id': widget.eventId, 'title': titleCtrl.text, 'message': msgCtrl.text, 'created_by': profile!.id,
              });
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _addIncident() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int severity = 3;
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: LitColors.clay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.radius(20)),
            side: const BorderSide(color: LitColors.border, width: 1.3),
          ),
          title: Text('Report Incident', style: GoogleFonts.fredoka(color: LitColors.bone, fontSize: r.sp(16))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClayTextField(controller: titleCtrl, hintText: 'Title'),
              SizedBox(height: r.h(10)),
              ClayTextField(controller: descCtrl, hintText: 'Description'),
              SizedBox(height: r.h(12)),
              Row(
                children: [
                  Text('Severity:', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12))),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: Slider(
                      value: severity.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: LitColors.coral,
                      inactiveColor: LitColors.clay3,
                      label: 'Severity: $severity',
                      onChanged: (v) => setS(() => severity = v.round()),
                    ),
                  ),
                  Text('$severity', style: GoogleFonts.fredoka(color: LitColors.bone, fontSize: r.sp(12))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: LitColors.ash)),
            ),
            ClayButton(
              width: r.w(90),
              height: r.h(38),
              isDanger: true,
              onPressed: () async {
                if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
                final profile = ref.read(currentProfileProvider);
                await SupabaseConfig.client.from(SupabaseTables.incidents).insert({
                  'event_id': widget.eventId, 'title': titleCtrl.text, 'description': descCtrl.text, 'severity': severity, 'reported_by': profile!.id,
                });
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }
}
