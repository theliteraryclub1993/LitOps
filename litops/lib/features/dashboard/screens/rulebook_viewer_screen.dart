import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/common_widgets.dart';
import 'dashboard_screen.dart';

class RulebookViewerScreen extends ConsumerStatefulWidget {
  final String fileUrl;

  const RulebookViewerScreen({super.key, required this.fileUrl});

  @override
  ConsumerState<RulebookViewerScreen> createState() => _RulebookViewerScreenState();
}

class _RulebookViewerScreenState extends ConsumerState<RulebookViewerScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  String? _downloadedUrl;
  http.Client? _httpClient;

  @override
  void initState() {
    super.initState();
    if (widget.fileUrl.isNotEmpty) {
      _startDownload(widget.fileUrl);
    }
  }

  @override
  void dispose() {
    _httpClient?.close();
    super.dispose();
  }

  void _startDownload(String url) async {
    if (_downloadedUrl == url && _pdfBytes != null) return;

    _httpClient?.close();
    _httpClient = http.Client();

    setState(() {
      _isLoading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
      _downloadedUrl = url;
    });

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        final contentLength = response.contentLength;
        final List<int> bytes = [];
        int downloaded = 0;

        await for (final chunk in response.stream) {
          if (!mounted) return;
          bytes.addAll(chunk);
          downloaded += chunk.length;
          if (contentLength != null && contentLength > 0) {
            setState(() {
              _downloadProgress = downloaded / contentLength;
            });
          }
        }

        if (!mounted) return;
        setState(() {
          _pdfBytes = Uint8List.fromList(bytes);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load PDF (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _printPdf() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _pdfBytes!,
        name: 'Fest_Rulebook.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LitColors.coral,
            content: Text(
              'Error printing: $e',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Fest_Rulebook.pdf');
      await file.writeAsBytes(_pdfBytes!);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Fest Rulebook',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LitColors.coral,
            content: Text(
              'Error sharing: $e',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, {required bool showActions}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'Fest Rulebook',
        style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 18, color: LitColors.bone),
      ),
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      actions: showActions && _pdfBytes != null
          ? [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh',
                onPressed: () {
                  if (widget.fileUrl.isNotEmpty) {
                    _startDownload(widget.fileUrl);
                  } else {
                    final rulebook = ref.read(rulebookStreamProvider).value;
                    if (rulebook != null) {
                      _startDownload(rulebook.fileUrl);
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                tooltip: 'Print',
                onPressed: _printPdf,
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                tooltip: 'Share',
                onPressed: _sharePdf,
              ),
              const SizedBox(width: 8),
            ]
          : null,
    );
  }

  Widget _buildLoadingScaffold(BuildContext context, double? progress) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: _buildAppBar(context, showActions: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ClayCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LitColors.ember.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: LitColors.ember,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Downloading Rulebook',
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: LitColors.bone,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress != null && progress > 0
                      ? 'Loading pages... ${(progress * 100).toStringAsFixed(0)}%'
                      : 'Connecting to server...',
                  style: GoogleFonts.plusJakartaSans(
                    color: LitColors.ash,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 8,
                    width: double.infinity,
                    color: LitColors.clay3,
                    child: progress != null && progress > 0
                        ? FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [LitColors.ember, LitColors.amber],
                                ),
                              ),
                            ),
                          )
                        : const LinearProgressIndicator(
                            backgroundColor: LitColors.clay3,
                            color: LitColors.ember,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: _buildAppBar(context, showActions: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: ClayCard(
            borderRadius: 24,
            borderColor: LitColors.coral.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LitColors.coral.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: LitColors.coral,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Failed to Load Rulebook',
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: LitColors.bone,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: LitColors.ash,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ClayButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    if (widget.fileUrl.isNotEmpty) {
                      _startDownload(widget.fileUrl);
                    } else {
                      final rulebook = ref.read(rulebookStreamProvider).value;
                      if (rulebook != null) {
                        _startDownload(rulebook.fileUrl);
                      }
                    }
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: _buildAppBar(context, showActions: true),
      body: PdfPreview(
        build: (format) async => _pdfBytes!,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'Fest_Rulebook.pdf',
        scrollViewDecoration: const BoxDecoration(color: LitColors.void_),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: LitColors.ember),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorScaffold(context, _errorMessage!);
    }

    if (_isLoading || _pdfBytes == null) {
      if (widget.fileUrl.isEmpty) {
        final rulebookAsync = ref.watch(rulebookStreamProvider);
        return rulebookAsync.when(
          data: (rulebook) {
            if (rulebook == null) {
              return _buildErrorScaffold(context, 'Rulebook not available.');
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startDownload(rulebook.fileUrl);
              }
            });
            return _buildLoadingScaffold(context, _downloadProgress);
          },
          loading: () => _buildLoadingScaffold(context, null),
          error: (e, _) => _buildErrorScaffold(context, 'Error loading rulebook link: $e'),
        );
      }
      return _buildLoadingScaffold(context, _downloadProgress);
    }

    return _buildViewer(context);
  }
}
