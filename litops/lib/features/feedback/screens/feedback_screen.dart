import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  Event? _selectedEvent;
  List<Event> _events = [];
  List<FeedbackEntry> _feedback = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final data = await SupabaseConfig.client.from(SupabaseTables.events).select().order('title');
    setState(() {
      _events = (data as List).map((e) => Event.fromJson(e)).toList();
      if (_events.isNotEmpty) {
        _selectedEvent = _events.first;
        _loadFeedback(_selectedEvent!.id);
      }
    });
  }

  Future<void> _loadFeedback(String eventId) async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseConfig.client.from(SupabaseTables.feedback).select().eq('event_id', eventId);
      setState(() {
        _feedback = (data as List).map((f) => FeedbackEntry.fromJson(f)).toList();
      });
    } catch (e) {
      debugPrint('Error loading feedback: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  int _getBucketCount(int stars) {
    return _feedback.where((f) {
      final q = f.eventQuality ?? 0;
      final v = f.venueRating ?? 0;
      final o = f.organizationRating ?? 0;
      int count = 0;
      int sum = 0;
      if (f.eventQuality != null) {
        count++;
        sum += q;
      }
      if (f.venueRating != null) {
        count++;
        sum += v;
      }
      if (f.organizationRating != null) {
        count++;
        sum += o;
      }
      if (count == 0) return false;
      final avg = (sum / count).round();
      return avg == stars;
    }).length;
  }

  Future<void> _showRateEventSheet() async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No events available to rate.')),
      );
      return;
    }

    Event? localSelectedEvent = _selectedEvent ?? _events.first;
    int qualityStars = 5;
    int venueStars = 5;
    int organizationStars = 5;
    final List<String> availableTags = ["Well Organized", "Venue Issue", "Loved the Theme", "Clear Rules", "Delay in start"];
    final List<String> selectedTags = [];
    final commentCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: LitColors.clay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final r = Responsive(ctx);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + r.bottomSafeArea + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rate this Event',
                        style: GoogleFonts.fredoka(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: LitColors.bone,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: LitColors.ash),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select Event',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ClayInsetCard(
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<Event>(
                      dropdownColor: LitColors.clay,
                      initialValue: localSelectedEvent,
                      style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                      decoration: const InputDecoration(border: InputBorder.none),
                      items: _events
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.name, style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                              ))
                          .toList(),
                      onChanged: (v) => setS(() => localSelectedEvent = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStarRatingRow(
                    label: 'Event Quality',
                    currentRating: qualityStars,
                    onChanged: (val) => setS(() => qualityStars = val),
                  ),
                  const SizedBox(height: 12),
                  _buildStarRatingRow(
                    label: 'Venue Rating',
                    currentRating: venueStars,
                    onChanged: (val) => setS(() => venueStars = val),
                  ),
                  const SizedBox(height: 12),
                  _buildStarRatingRow(
                    label: 'Organization Rating',
                    currentRating: organizationStars,
                    onChanged: (val) => setS(() => organizationStars = val),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'What did you think?',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return ChoiceChip(
                        label: Text(tag, style: GoogleFonts.plusJakartaSans(color: isSelected ? const Color(0xFF1A0D05) : LitColors.bone)),
                        selected: isSelected,
                        selectedColor: LitColors.amber,
                        backgroundColor: LitColors.clay2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                        onSelected: (selected) {
                          setS(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comments (Optional)',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ClayTextField(
                    controller: commentCtrl,
                    hintText: 'Share your experience...',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  ClayButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setS(() => submitting = true);
                            try {
                              String? studentId;
                              if (profile.usn != null) {
                                final stData = await SupabaseConfig.client
                                    .from(SupabaseTables.studentMaster)
                                    .select('id')
                                    .eq('usn', profile.usn!)
                                    .maybeSingle();
                                if (stData != null) studentId = stData['id'];
                              }
                              if (studentId == null) {
                                final stData = await SupabaseConfig.client
                                    .from(SupabaseTables.studentMaster)
                                    .select('id')
                                    .eq('email', profile.email)
                                    .maybeSingle();
                                if (stData != null) studentId = stData['id'];
                              }
                              if (studentId == null) {
                                final firstSt = await SupabaseConfig.client
                                    .from(SupabaseTables.studentMaster)
                                    .select('id')
                                    .limit(1)
                                    .maybeSingle();
                                studentId = firstSt?['id'];
                              }

                              final commentsBuffer = StringBuffer();
                              if (selectedTags.isNotEmpty) {
                                commentsBuffer.write('[${selectedTags.join(", ")}] ');
                              }
                              commentsBuffer.write(commentCtrl.text.trim());

                              await SupabaseConfig.client.from(SupabaseTables.feedback).insert({
                                'event_id': localSelectedEvent!.id,
                                'student_id': studentId,
                                'event_quality': qualityStars,
                                'venue_rating': venueStars,
                                'organization_rating': organizationStars,
                                'comments': commentsBuffer.toString().trim().isEmpty ? null : commentsBuffer.toString().trim(),
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Feedback submitted! Thank you.'),
                                    backgroundColor: LitColors.moss,
                                  ),
                                );
                                Navigator.pop(ctx);
                                _loadFeedback(localSelectedEvent!.id);
                              }
                            } catch (e) {
                              String errorMsg = e.toString();
                              if (errorMsg.contains('duplicate key value violates unique constraint')) {
                                errorMsg = 'You have already submitted feedback for this event.';
                              }
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: LitColors.coral,
                                ),
                              );
                            } finally {
                              setS(() => submitting = false);
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2),
                          )
                        : Text('Submit Feedback', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarRatingRow({
    required String label,
    required int currentRating,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Row(
          children: List.generate(5, (index) {
            final starVal = index + 1;
            final isLit = starVal <= currentRating;
            return IconButton(
              icon: Icon(
                isLit ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isLit ? LitColors.amber : LitColors.ash,
                size: 28,
              ),
              onPressed: () => onChanged(starVal),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avgQuality = _feedback.isNotEmpty
        ? (_feedback.where((f) => f.eventQuality != null).fold(0, (s, f) => s + (f.eventQuality ?? 0)) /
            _feedback.where((f) => f.eventQuality != null).length)
        : 0.0;
    final avgVenue = _feedback.isNotEmpty
        ? (_feedback.where((f) => f.venueRating != null).fold(0, (s, f) => s + (f.venueRating ?? 0)) /
            _feedback.where((f) => f.venueRating != null).length)
        : 0.0;
    final avgOrg = _feedback.isNotEmpty
        ? (_feedback.where((f) => f.organizationRating != null).fold(0, (s, f) => s + (f.organizationRating ?? 0)) /
            _feedback.where((f) => f.organizationRating != null).length)
        : 0.0;

    final overallAverage = (avgQuality + avgVenue + avgOrg) / 3.0;

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Event Feedback',
          style: GoogleFonts.fredoka(color: LitColors.bone, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClayCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Event',
                    style: GoogleFonts.fredoka(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: LitColors.bone,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClayInsetCard(
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<Event>(
                      initialValue: _selectedEvent,
                      dropdownColor: LitColors.clay,
                      decoration: const InputDecoration(border: InputBorder.none),
                      items: _events
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: LitColors.bone,
                                    fontSize: 13,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedEvent = v);
                        if (v != null) _loadFeedback(v.id);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedEvent != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClayCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              overallAverage > 0 ? overallAverage.toStringAsFixed(1) : 'N/A',
                              style: GoogleFonts.fredoka(fontSize: 32, fontWeight: FontWeight.bold, color: LitColors.amber),
                            ),
                            Text(
                              'Average Rating',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: LitColors.bone),
                            ),
                            Text(
                              '${_feedback.length} responses',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: LitColors.ash),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _ratingStatMini('Quality', avgQuality),
                            const SizedBox(width: 8),
                            _ratingStatMini('Venue', avgVenue),
                            const SizedBox(width: 8),
                            _ratingStatMini('Org', avgOrg),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(height: 1, color: LitColors.clay3),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Rating Distribution',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: LitColors.ash),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final stars = index + 1;
                        final count = _getBucketCount(stars);
                        final total = _feedback.length;
                        final double pct = total > 0 ? (count / total) : 0.0;
                        return Column(
                          children: [
                            Text('$count', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: LitColors.ash)),
                            const SizedBox(height: 4),
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  width: 24,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: LitColors.clay,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 60 * pct + 4,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [LitColors.amber, LitColors.ember],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('$stars★', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: LitColors.ash)),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: _loading
                ? const LoadingView()
                : _feedback.isEmpty
                    ? const EmptyView(icon: Icons.feedback_outlined, title: 'No feedback yet')
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: context.r.listBottomPadding,
                        ),
                        itemCount: _feedback.length,
                        itemBuilder: (ctx, i) {
                          final f = _feedback[i];
                          return ClayCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              title: Row(
                                children: [
                                  if (f.eventQuality != null) ...[
                                    const Icon(Icons.star_rounded, color: LitColors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Quality: ${f.eventQuality}/5',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: LitColors.bone),
                                    ),
                                  ],
                                  const SizedBox(width: 12),
                                  if (f.venueRating != null) ...[
                                    const Icon(Icons.location_on_rounded, color: LitColors.ember, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Venue: ${f.venueRating}/5',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: LitColors.ash),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: f.comments != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        f.comments!,
                                        style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 12.5),
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: context.r.bottomSpacing(), right: context.r.w(8)),
        child: ClayButton(
          width: 140,
          height: 48,
          borderRadius: 24,
          onPressed: _showRateEventSheet,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rate_rounded),
              const SizedBox(width: 6),
              Text(
                'Rate Event',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ratingStatMini(String label, double val) {
    return ClayInsetCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 10,
      child: Column(
        children: [
          Text(
            val > 0 ? val.toStringAsFixed(1) : 'N/A',
            style: GoogleFonts.fredoka(color: LitColors.amber, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text(label, style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 9)),
        ],
      ),
    );
  }
}

