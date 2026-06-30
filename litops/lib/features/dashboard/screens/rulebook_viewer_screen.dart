import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../../core/widgets/common_widgets.dart';
import 'dashboard_screen.dart';

class RulebookViewerScreen extends ConsumerWidget {
  final String fileUrl;

  const RulebookViewerScreen({super.key, required this.fileUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (fileUrl.isNotEmpty) {
      return _buildViewer(context, fileUrl);
    } else {
      final rulebookAsync = ref.watch(rulebookStreamProvider);
      return rulebookAsync.when(
        data: (rulebook) {
          if (rulebook == null) {
            return Scaffold(
              backgroundColor: LitColors.void_,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'Fest Rulebook',
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
                ),
                leading: Navigator.canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    : null,
              ),
              body: Center(
                child: Text(
                  'Rulebook not available.',
                  style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 14),
                ),
              ),
            );
          }
          return _buildViewer(context, rulebook.fileUrl);
        },
        loading: () => Scaffold(
          backgroundColor: LitColors.void_,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Fest Rulebook',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
            ),
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
          ),
          body: const Center(
            child: CircularProgressIndicator(color: LitColors.ember),
          ),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: LitColors.void_,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Fest Rulebook',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
            ),
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
          ),
          body: Center(
            child: Text(
              'Error loading rulebook: $e',
              style: GoogleFonts.plusJakartaSans(color: LitColors.coral),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildViewer(BuildContext context, String url) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Fest Rulebook',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: PdfPreview(
          build: (format) async {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          } else {
            throw Exception('Failed to load PDF: HTTP ${response.statusCode}');
          }
        },
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'Fest_Rulebook.pdf',
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: LitColors.ember),
        ),
      ),
    ),
  );
}
}
