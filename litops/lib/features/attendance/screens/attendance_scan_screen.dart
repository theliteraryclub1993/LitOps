import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class AttendanceScanScreen extends ConsumerStatefulWidget {
  const AttendanceScanScreen({super.key});
  @override
  ConsumerState<AttendanceScanScreen> createState() => _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends ConsumerState<AttendanceScanScreen> {
  Event? _selectedEvent;
  List<Event> _events = [];
  bool _scanEnabled = true;
  int _attendanceCount = 0;
  int _totalRegistrations = 0;
  bool _hasPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _hasPermissionGranted = status.isGranted);
  }

  Future<void> _loadEvents() async {
    final data = await SupabaseConfig.client.from(SupabaseTables.events).select()
        .inFilter('status', ['ongoing', 'registration_open', 'registration_closed']).order('title');
    setState(() => _events = (data as List).map((e) => Event.fromJson(e)).toList());
  }

  Future<void> _loadCount(String eventId) async {
    final regs = await SupabaseConfig.client.from(SupabaseTables.registrations).select('id').eq('event_id', eventId).eq('is_cancelled', false);
    final att = await SupabaseConfig.client.from(SupabaseTables.attendance).select('id').eq('event_id', eventId);
    setState(() { _totalRegistrations = (regs as List).length; _attendanceCount = (att as List).length; });
  }

  Future<void> _markAttendance(String usn) async {
    if (_selectedEvent == null) return;
    try {
      final student = await SupabaseConfig.client.from(SupabaseTables.studentMaster)
          .select().ilike('usn', usn.trim()).eq('status', 'active').maybeSingle();
      if (student == null) { _showResult('Student not found', LitColors.coral); return; }

      final reg = await SupabaseConfig.client.from(SupabaseTables.registrations)
          .select().eq('event_id', _selectedEvent!.id).eq('student_id', student['id']).eq('is_cancelled', false).maybeSingle();
      if (reg == null) { _showResult('${student['name']} not registered', LitColors.amber); return; }

      final existing = await SupabaseConfig.client.from(SupabaseTables.attendance)
          .select('id').eq('event_id', _selectedEvent!.id).eq('registration_id', reg['id']).maybeSingle();
      if (existing != null) { _showResult('${student['name']} already marked present', LitColors.amber); return; }

      final profile = ref.read(currentProfileProvider);
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none);

      if (isOffline) {
        final box = Hive.box('offline_attendance');
        await box.add({
          'event_id': _selectedEvent!.id,
          'registration_id': reg['id'],
          'student_id': student['id'],
          'marked_by': profile!.id,
          'method': 'barcode',
          'is_offline': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _showResult('Offline: ${student['name']} queued', LitColors.amber);
      } else {
        await SupabaseConfig.client.from(SupabaseTables.attendance).insert({
          'event_id': _selectedEvent!.id,
          'registration_id': reg['id'],
          'student_id': student['id'],
          'marked_by': profile!.id,
          'method': 'barcode',
        });
        _showResult('${student['name']} - Present!', LitColors.moss);
      }
      _loadCount(_selectedEvent!.id);
    } catch (e) {
      _showResult('Error: $e', LitColors.coral);
    }
    setState(() => _scanEnabled = true);
  }

  String _getErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera permission denied. Please enable it in settings.';
      case MobileScannerErrorCode.unsupported:
        return 'Scanning is not supported on this device.';
      default:
        return 'An unexpected error occurred: ${error.errorDetails?.message ?? 'Unknown'}';
    }
  }

  void _showResult(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _totalRegistrations - _attendanceCount;

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LitColors.bone),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Attendance Scanner',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
        ),
      ),
      body: ListView(
        padding: context.r.pageInsets,
        children: [
          // Select Event Card
          ClayCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Event',
                  style: GoogleFonts.fredoka(fontSize: 13.5, fontWeight: FontWeight.bold, color: LitColors.bone),
                ),
                const SizedBox(height: 10),
                ClayInsetCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<Event>(
                    value: _selectedEvent,
                    dropdownColor: LitColors.clay,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: _events.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 13)))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedEvent = v);
                      if (v != null) _loadCount(v.id);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedEvent != null) ...[
            // Side-by-side stats boxes (Marked / Pending)
            Row(
              children: [
                Expanded(
                  child: ClayInsetCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_attendanceCount',
                          style: GoogleFonts.fredoka(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: LitColors.bone,
                          ),
                        ),
                        Text(
                          'MARKED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            color: LitColors.ash,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClayInsetCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pendingCount < 0 ? 0 : pendingCount}',
                          style: GoogleFonts.fredoka(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: LitColors.bone,
                          ),
                        ),
                        Text(
                          'PENDING',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            color: LitColors.ash,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Camera Scanner Card
            ClayCard(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _hasPermissionGranted ? Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        onDetect: (capture) {
                          if (!_scanEnabled) return;
                          final barcode = capture.barcodes.first;
                          if (barcode.rawValue != null) {
                            setState(() => _scanEnabled = false);
                            _markAttendance(barcode.rawValue!);
                          }
                        },
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  'Scanner Error',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    _getErrorMessage(error),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ClayButton(
                                  width: 120,
                                  height: 40,
                                  onPressed: () => setState(() {}),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Dotted target frame overlay
                      Container(
                        width: 220,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: LitColors.ember.withOpacity(0.55),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: LitColors.ember, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              'Align barcode in frame',
                              style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ) : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 60, color: LitColors.ash),
                        const SizedBox(height: 12),
                        Text(
                          'Camera Permission Required',
                          style: GoogleFonts.fredoka(color: LitColors.bone, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ClayButton(
                          onPressed: _requestCameraPermission,
                          child: const Text('Grant Permission'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
