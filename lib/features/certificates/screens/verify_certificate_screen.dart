import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/common_widgets.dart';

class VerifyCertificateScreen extends ConsumerStatefulWidget {
  final String qrCode;
  const VerifyCertificateScreen({super.key, required this.qrCode});
  @override
  ConsumerState<VerifyCertificateScreen> createState() => _VerifyCertificateScreenState();
}

class _VerifyCertificateScreenState extends ConsumerState<VerifyCertificateScreen> {
  Map<String, dynamic>? _cert;
  bool _loading = true;
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseTables.certificates)
          .select('*,events(title),student_master(name,usn)')
          .eq('qr_code', widget.qrCode)
          .maybeSingle();
      setState(() {
        _cert = data;
        _valid = data != null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: LitLifeAppBar(
        title: 'Certificate Verification',
        showBack: Navigator.canPop(context),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _loading
              ? const LoadingView(message: 'Verifying Certificate...')
              : _valid
                  ? ClayCard(
                      borderColor: LitColors.moss.withOpacity(0.3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 64, color: LitColors.moss),
                          const SizedBox(height: 16),
                          Text(
                            'VALID CERTIFICATE',
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: LitColors.moss,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _infoRow('Name', _cert?['student_master']?['name'] ?? 'N/A'),
                          _infoRow('USN', _cert?['student_master']?['usn'] ?? 'N/A'),
                          _infoRow('Event', (_cert?['events']?['title'] ?? _cert?['events']?['name'] ?? 'N/A') as String),
                          _infoRow('Type', _cert?['certificate_type']?.toString().toUpperCase() ?? 'N/A'),
                          _infoRow(
                            'Issued',
                            _cert?['issued_at'] != null
                                ? AppUtils.formatDate(DateTime.parse(_cert!['issued_at']))
                                : 'N/A',
                          ),
                        ],
                      ),
                    )
                  : ClayCard(
                      borderColor: LitColors.coral.withOpacity(0.3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: LitColors.coral),
                          const SizedBox(height: 16),
                          Text(
                            'INVALID CERTIFICATE',
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: LitColors.coral,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This QR code does not match any certificate in our records.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: LitColors.ash,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: LitColors.ash,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.bone,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

