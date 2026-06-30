import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});
  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  Event? _selectedEvent;
  List<Event> _events = [];
  List<Certificate> _certs = [];
  List<Map<String, dynamic>> _rawCertsData = [];
  bool _loading = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final data = await SupabaseConfig.client
        .from(SupabaseTables.events)
        .select()
        .inFilter('status', ['completed', 'results_published'])
        .order('title');
    setState(() => _events = (data as List).map((e) => Event.fromJson(e)).toList());
  }

  Future<void> _loadCerts(String eventId) async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseTables.certificates)
          .select('*, student_master(*), events(*)')
          .eq('event_id', eventId);
      setState(() {
        _certs = (data as List).map((c) => Certificate.fromJson(c)).toList();
        _rawCertsData = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _generateCertificates() async {
    if (_selectedEvent == null) return;
    setState(() => _generating = true);
    final profile = ref.read(currentProfileProvider);
    try {
      final regs = await SupabaseConfig.client
          .from(SupabaseTables.registrations)
          .select('id, student_id')
          .eq('event_id', _selectedEvent!.id)
          .eq('is_cancelled', false);
      final results = await SupabaseConfig.client
          .from(SupabaseTables.results)
          .select('registration_id,position')
          .eq('event_id', _selectedEvent!.id);

      for (final reg in (regs as List)) {
        final resultEntry = (results as List).where((r) => r['registration_id'] == reg['id'] as String).firstOrNull;
        CertificateType type = CertificateType.participation;
        if (resultEntry != null) {
          type = CertificateType.fromString(resultEntry['position']);
        }
        await SupabaseConfig.client.from(SupabaseTables.certificates).insert({
          'event_id': _selectedEvent!.id,
          'student_id': reg['student_id'],
          'certificate_type': type.value,
          'issued_by': profile!.id,
        });
      }
      _loadCerts(_selectedEvent!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${regs.length} certificates'),
            backgroundColor: LitColors.moss,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: LitColors.coral,
          ),
        );
      }
    }
    setState(() => _generating = false);
  }

  Future<void> _generateCertificatePdf(Map<String, dynamic> rawCert) async {
    final pdf = pw.Document();
    final student = rawCert['student_master'] ?? {};
    final event = rawCert['events'] ?? {};
    final certType = rawCert['certificate_type'] ?? 'participation';
    final qrCodeStr = rawCert['qr_code'] ?? '';

    String titleText = 'CERTIFICATE OF PARTICIPATION';
    String detailsText = 'for actively participating in the event';
    if (certType == 'winner') {
      titleText = 'CERTIFICATE OF MERIT';
      detailsText = 'for securing FIRST PLACE in the event';
    } else if (certType == 'runner_up') {
      titleText = 'CERTIFICATE OF MERIT';
      detailsText = 'for securing SECOND PLACE in the event';
    } else if (certType == 'second_runner_up') {
      titleText = 'CERTIFICATE OF MERIT';
      detailsText = 'for securing THIRD PLACE in the event';
    } else if (certType == 'volunteer') {
      titleText = 'CERTIFICATE OF APPRECIATION';
      detailsText = 'for outstanding volunteer service in organizing the event';
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber, width: 4),
            ),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.amber, width: 1),
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'THE LITERARY CLUB (LIT)',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Malnad College of Engineering, Hassan',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        height: 2,
                        width: 400,
                        color: PdfColors.amber,
                      ),
                    ],
                  ),
                  pw.Text(
                    titleText,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.amber800,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'This is to certify that',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        student['name']?.toString().toUpperCase() ?? 'PARTICIPANT',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'of USN ${student['usn'] ?? 'N/A'} (Branch: ${student['branch'] ?? 'N/A'})',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        detailsText,
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '"${event['name'] ?? 'EVENT'}"',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'conducted during Malnad Fest 2026.',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(width: 120, height: 1, color: PdfColors.grey700),
                          pw.SizedBox(height: 4),
                          pw.Text('Staff Adviser', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('The Literary Club (LIT)', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.SizedBox(
                            width: 60,
                            height: 60,
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: 'https://litops.litclub.com/verify/$qrCodeStr',
                              drawText: false,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('Scan to Verify', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(width: 120, height: 1, color: PdfColors.grey700),
                          pw.SizedBox(height: 4),
                          pw.Text('Student President', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('The Literary Club (LIT)', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: LitLifeAppBar(
        title: 'Certificates',
        actions: [
          if (_selectedEvent != null)
            IconButton(
              icon: _generating
                  ? SizedBox(
                      width: r.w(18),
                      height: r.w(18),
                      child: const CircularProgressIndicator(color: LitColors.ember, strokeWidth: 2),
                    )
                  : Icon(Icons.auto_awesome, color: LitColors.bone, size: r.icon(20)),
              onPressed: _generating ? null : _generateCertificates,
              tooltip: 'Generate All',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(r.w(16)),
            child: ClayInsetCard(
              borderRadius: r.radius(14),
              padding: EdgeInsets.symmetric(horizontal: r.w(12)),
              child: DropdownButtonFormField<Event>(
                initialValue: _selectedEvent,
                dropdownColor: LitColors.clay,
                hint: Text(
                  'Select Event',
                  style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(13)),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                items: _events.map((e) {
                  return DropdownMenuItem<Event>(
                    value: e,
                    child: Text(
                      e.name,
                      style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: r.sp(13)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => _selectedEvent = v);
                  if (v != null) _loadCerts(v.id);
                },
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _certs.isEmpty
                    ? const EmptyView(
                        icon: Icons.workspace_premium_outlined,
                        title: 'No certificates yet',
                        subtitle: 'Select an event to view or generate certificates.',
                      )
                    : ListView.builder(
                        itemCount: _certs.length,
                        padding: EdgeInsets.only(bottom: r.h(130)),
                        itemBuilder: (ctx, i) {
                          final c = _certs[i];
                          return ClayCard(
                            margin: EdgeInsets.only(bottom: r.h(12), left: r.w(16), right: r.w(16)),
                            padding: EdgeInsets.all(r.w(14)),
                            child: Row(
                              children: [
                                Container(
                                  width: r.w(40),
                                  height: r.w(40),
                                  decoration: BoxDecoration(
                                    color: LitColors.clay2,
                                    borderRadius: BorderRadius.circular(r.radius(10)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.workspace_premium,
                                    color: LitColors.amber,
                                    size: r.icon(20),
                                  ),
                                ),
                                SizedBox(width: r.w(14)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.certificateType.label,
                                        style: GoogleFonts.fredoka(
                                          color: LitColors.bone,
                                          fontWeight: FontWeight.bold,
                                          fontSize: r.sp(14),
                                        ),
                                      ),
                                      SizedBox(height: r.h(4)),
                                      Text(
                                        'Issued: ${AppUtils.formatDate(c.issuedAt)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: LitColors.ash,
                                          fontSize: r.sp(11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: r.w(8)),
                                IconButton(
                                  icon: Icon(Icons.download, color: LitColors.ember, size: r.icon(20)),
                                  onPressed: () {
                                    final rawCert = _rawCertsData.firstWhere((r) => r['id'] == c.id);
                                    _generateCertificatePdf(rawCert);
                                  },
                                  tooltip: 'Download PDF',
                                ),
                                IconButton(
                                  icon: Icon(Icons.qr_code, color: LitColors.bone, size: r.icon(20)),
                                  onPressed: () => _showQR(c),
                                  tooltip: 'Show QR Code',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showQR(Certificate cert) {
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LitColors.clay,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.radius(20)),
          side: const BorderSide(color: LitColors.border, width: 1.3),
        ),
        title: Text(
          cert.certificateType.label,
          style: GoogleFonts.fredoka(
            color: LitColors.bone,
            fontWeight: FontWeight.bold,
            fontSize: r.sp(18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(r.w(12)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.radius(16)),
              ),
              child: QrImageView(
                data: cert.qrCode,
                version: QrVersions.auto,
                size: r.w(180),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0A0A0A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0A0A0A),
                ),
              ),
            ),
            SizedBox(height: r.h(14)),
            Text(
              'QR: ${cert.qrCode}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: r.sp(11),
                color: LitColors.ash,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Padding(
              padding: r.pageInsets,
              child: Text(
                'Close',
                style: GoogleFonts.plusJakartaSans(
                  color: LitColors.ash,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ClayButton(
            width: r.w(100),
            onPressed: () {
              Share.share('Verify: ${cert.qrCode}');
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}
