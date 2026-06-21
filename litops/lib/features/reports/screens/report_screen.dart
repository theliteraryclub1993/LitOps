import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/responsive.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String eventId;
  const ReportScreen({super.key, required this.eventId});
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadReport(); }

  Future<void> _loadReport() async {
    try {
      final event = await SupabaseConfig.client.from(SupabaseTables.events).select().eq('id', widget.eventId).single();
      final regs = await SupabaseConfig.client.from(SupabaseTables.registrations).select('id').eq('event_id', widget.eventId).eq('is_cancelled', false);
      final att = await SupabaseConfig.client.from(SupabaseTables.attendance).select('id').eq('event_id', widget.eventId);
      final results = await SupabaseConfig.client.from(SupabaseTables.results).select('*,registrations(student_id,student_master(name,usn))').eq('event_id', widget.eventId);
      final feedback = await SupabaseConfig.client.from(SupabaseTables.feedback).select().eq('event_id', widget.eventId);
      setState(() {
        _data = {
          'event': event, 'regCount': (regs as List).length, 'attCount': (att as List).length,
          'results': results, 'feedbackCount': (feedback as List).length,
        };
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  Future<void> _generateReportPdf() async {
    if (_data == null) return;

    final pdf = pw.Document();
    final event = _data!['event'] ?? {};
    final regCount = _data!['regCount'] ?? 0;
    final attCount = _data!['attCount'] ?? 0;
    final feedbackCount = _data!['feedbackCount'] ?? 0;
    final results = _data!['results'] as List? ?? [];
    
    final attPercentage = regCount > 0 ? (attCount / regCount * 100).toStringAsFixed(0) : '0';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'THE LITERARY CLUB (LIT)',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text(
                        'Malnad College of Engineering, Hassan',
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'OFFICIAL EVENT SUMMARY REPORT',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800, letterSpacing: 1.5),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Container(height: 2, color: PdfColors.amber),
                      pw.SizedBox(height: 24),
                    ],
                  ),
                ),
                pw.Text('Event Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow('Event Name', event['name'] ?? 'N/A'),
                    _pdfTableRow('Category', event['category']?.toString().toUpperCase() ?? 'N/A'),
                    _pdfTableRow('Venue', event['venue'] ?? 'N/A'),
                    _pdfTableRow('Date', event['event_date'] ?? 'N/A'),
                    _pdfTableRow('Time', event['event_time'] ?? 'N/A'),
                    _pdfTableRow('Capacity Limit', event['capacity']?.toString() ?? 'Unlimited'),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Text('Participation & Attendance Stats', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow('Total Registrations', '$regCount'),
                    _pdfTableRow('Total Attendance', '$attCount'),
                    _pdfTableRow('Attendance Percentage', '$attPercentage%'),
                    _pdfTableRow('Feedback Submissions', '$feedbackCount'),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Text('Results & Standing', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 8),
                if (results.isEmpty)
                  pw.Text('No results have been published for this event yet.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Position', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Winner Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('USN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Score', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      ...results.map((r) {
                        final student = r['registrations']?['student_master'] ?? {};
                        final pos = r['position']?.toString().toUpperCase() ?? 'N/A';
                        final name = student['name'] ?? 'N/A';
                        final usn = student['usn'] ?? 'N/A';
                        final score = r['score']?.toString() ?? 'N/A';
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(pos)),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(name)),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(usn)),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(score)),
                          ],
                        );
                      }),
                    ],
                  ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.grey700),
                        pw.SizedBox(height: 4),
                        pw.Text('Event Director', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.grey700),
                        pw.SizedBox(height: 4),
                        pw.Text('Joint Secretary', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.grey700),
                        pw.SizedBox(height: 4),
                        pw.Text('Student President', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.TableRow _pdfTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Event Report', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
        actions: [
          if (!_loading && _data != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _generateReportPdf,
              tooltip: 'Export PDF Report',
            ),
        ],
      ),
      body: _loading ? const LoadingView() : _data == null ? const ErrorView(message: 'Failed to load report') : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Event Report', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_data!['event']['name'] ?? '', style: Theme.of(context).textTheme.titleLarge),
              Text('Category: ${_data!['event']['category']}'),
              Text('Venue: ${_data!['event']['venue'] ?? 'TBA'}'),
              Text('Date: ${_data!['event']['event_date'] ?? 'TBA'}'),
            ]))),
            const SizedBox(height: 16),
            Text('Statistics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: StatCard(title: 'Registrations', value: '${_data!['regCount']}', icon: Icons.people, color: AppTheme.balwaanColor)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Attendance', value: '${_data!['attCount']}', icon: Icons.check_circle, color: AppTheme.kalakruthiColor)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Feedback', value: '${_data!['feedbackCount']}', icon: Icons.feedback, color: AppTheme.buddhimaanColor)),
            ]),
            const SizedBox(height: 24),
            Text('Winners', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_data!['results'] as List).map((r) => Card(child: ListTile(
              leading: Icon(r['position'] == 'winner' ? Icons.emoji_events : Icons.star, color: Colors.amber),
              title: Text(r['registrations']?['student_master']?['name'] ?? 'Unknown'),
              subtitle: Text('${r['position']} • Score: ${r['score'] ?? 'N/A'}'),
            ))),
          ],
        ),
      ),
    );
  }
}
