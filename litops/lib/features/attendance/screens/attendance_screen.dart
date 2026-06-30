import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';

// Stream triggers for realtime updates
final _attendanceRegistrationsStream = StreamProvider.family((ref, String eventId) => 
  SupabaseConfig.client.from(SupabaseTables.registrations).stream(primaryKey: ['id']).eq('event_id', eventId)
);
final _attendanceStream = StreamProvider.family((ref, String eventId) => 
  SupabaseConfig.client.from(SupabaseTables.attendance).stream(primaryKey: ['id']).eq('event_id', eventId)
);

final eventAttendanceProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, eventId) async {
  // Watch the streams to trigger re-fetch
  ref.watch(_attendanceRegistrationsStream(eventId));
  ref.watch(_attendanceStream(eventId));
  
  final regs = await SupabaseConfig.client.from(SupabaseTables.registrations).select('id,student_id,student_master(name,usn,branch)').eq('event_id', eventId).eq('is_cancelled', false);
  final att = await SupabaseConfig.client.from(SupabaseTables.attendance).select('registration_id').eq('event_id', eventId);
  final attIds = (att as List).map((a) => a['registration_id']).toSet();
  return {'registrations': regs, 'attended': attIds, 'total': (regs as List).length, 'attendedCount': attIds.length};
});

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Attendance',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
        ),
      ),
      body: role.canMarkAttendance
          ? FutureBuilder(
              future: SupabaseConfig.client.from(SupabaseTables.events).select().inFilter('status', ['ongoing', 'registration_open', 'registration_closed']).order('title'),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                if (!snap.hasData) return const LoadingView();
                final events = (snap.data as List).map((e) => Event.fromJson(e)).toList();
                if (events.isEmpty) return const EmptyView(icon: Icons.event_busy, title: 'No events available');
                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 130),
                  itemCount: events.length,
                  itemBuilder: (ctx, i) {
                    final e = events[i];
                    return ClayCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      onTap: () => context.push('/attendance/scan'),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          e.name,
                          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: LitColors.bone, fontSize: 14),
                        ),
                        subtitle: Text(
                          e.venue ?? 'TBA',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11.5),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: LitColors.ash),
                      ),
                    );
                  },
                );
              },
            )
          : const Center(
              child: Text(
                'You do not have permission to mark attendance',
                style: TextStyle(color: LitColors.ash),
              ),
            ),
      floatingActionButton: role.canMarkAttendance
          ? Padding(
              padding: const EdgeInsets.only(bottom: 120, right: 8),
              child: ClayButton(
                width: 100,
                height: 48,
                borderRadius: 24,
                onPressed: () => context.push('/attendance/scan'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 16),
                    SizedBox(width: 6),
                    Text('Scan'),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
