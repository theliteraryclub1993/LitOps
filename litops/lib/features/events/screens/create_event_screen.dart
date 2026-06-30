import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import 'event_detail_screen.dart';
import '../../../core/utils/responsive.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final Event? eventToEdit;
  final String? eventId;
  const CreateEventScreen({super.key, this.eventToEdit, this.eventId});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _rulesController = TextEditingController();
  final _venueController = TextEditingController();
  final _capacityController = TextEditingController();
  final _teamSizeController = TextEditingController(text: '1');

  EventCategory _category = EventCategory.balwaan;
  EventStatus _status = EventStatus.draft;
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  DateTime? _deadline;
  bool _isTeamEvent = false;
  bool _isLoadingEvent = false;

  @override
  void initState() {
    super.initState();
    if (widget.eventToEdit != null) {
      _loadEventData(widget.eventToEdit!);
    } else if (widget.eventId != null) {
      _fetchAndLoadEvent(widget.eventId!);
    }
  }

  void _loadEventData(Event e) {
    _nameController.text = e.name;
    _descController.text = e.description ?? '';
    _rulesController.text = e.rules ?? '';
    _venueController.text = e.venue ?? '';
    _capacityController.text = e.capacity?.toString() ?? '';
    _teamSizeController.text = e.teamSize.toString();
    _category = e.category;
    _status = e.status;
    _eventDate = e.eventDate;
    _isTeamEvent = e.isTeamEvent;
    _deadline = e.registrationDeadline;

    if (e.eventTime != null) {
      try {
        final parts = e.eventTime!.split(':');
        _eventTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }
  }

  Future<void> _fetchAndLoadEvent(String id) async {
    setState(() => _isLoadingEvent = true);
    try {
      final client = SupabaseConfig.client;
      final data = await client.from(SupabaseTables.events).select().eq('id', id).single();
      final event = Event.fromJson(data);
      if (mounted) {
        setState(() {
          _loadEventData(event);
          _isLoadingEvent = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching event details for editing: $e');
      if (mounted) {
        setState(() => _isLoadingEvent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load event details: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    _teamSizeController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    final data = {
      'title': _nameController.text.trim(),
      'category': _category.value,
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'rules': _rulesController.text.trim().isEmpty ? null : _rulesController.text.trim(),
      'venue': _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
      'event_date': _eventDate?.toIso8601String().split('T').first,
      'event_time': _eventTime != null ? '${_eventTime!.hour.toString().padLeft(2, '0')}:${_eventTime!.minute.toString().padLeft(2, '0')}:00' : null,
      'capacity': _capacityController.text.isNotEmpty ? int.tryParse(_capacityController.text) : null,
      'team_size': int.tryParse(_teamSizeController.text) ?? 1,
      'is_team_event': _isTeamEvent,
      'registration_deadline': _deadline?.toIso8601String(),
      'status': _status.value,
      'created_by': profile.id,
    };

    try {
      final isEdit = widget.eventToEdit != null || widget.eventId != null;
      final id = widget.eventToEdit?.id ?? widget.eventId;
      if (isEdit) {
        await SupabaseConfig.client
            .from(SupabaseTables.events)
            .update(data)
            .eq('id', id!);

        ref.invalidate(eventDetailProvider(id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event updated successfully')));
          context.pop();
        }
      } else {
        await SupabaseConfig.client.from(SupabaseTables.events).insert(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created successfully')));
          context.pop();
        }
      }
    } catch (e) {
      debugPrint('Error saving event: $e');
      if (mounted) {
        final isEdit = widget.eventToEdit != null || widget.eventId != null;
        String msg = isEdit ? 'Failed to update event' : 'Failed to create event';
        final errStr = e.toString();
        if (errStr.contains('Could not find the table') || errStr.contains('PGRST205')) {
          msg = 'Database not set up. Please run the schema SQL in Supabase Dashboard > SQL Editor first.';
        } else if (errStr.contains('new row violates row-level security')) {

          msg = 'Permission denied. Your role does not allow modifying events.';
        } else if (errStr.contains('SocketException') || errStr.contains('Network')) {
          msg = 'Network error. Check your internet connection.';
        } else {
          msg = '${isEdit ? "Failed to update" : "Failed to create"} event: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.eventToEdit != null || widget.eventId != null;
    final r = context.r;
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: LitColors.bone, size: r.icon(24)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEdit ? 'Edit Event' : 'Create Event',
          style: GoogleFonts.fredoka(color: LitColors.bone, fontWeight: FontWeight.bold, fontSize: r.sp(18)),
        ),
        actions: [
          TextButton(
            onPressed: _isLoadingEvent ? null : _saveEvent,
            child: Text(
              isEdit ? 'Update' : 'Save',
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.ember,
                fontWeight: FontWeight.bold,
                fontSize: r.sp(14),
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingEvent
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(r.w(16)),
                children: [
                  // Event Name
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Name *',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: r.h(8)),
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                          decoration: InputDecoration(
                            hintText: 'Enter event name',
                            hintStyle: GoogleFonts.plusJakartaSans(color: LitColors.ash.withValues(alpha: 0.5)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: LitColors.clay2),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.ember),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.coral),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.coral),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            filled: true,
                            fillColor: LitColors.clay,
                            contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Category
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: r.h(8)),
                        DropdownButtonFormField<EventCategory>(
                          initialValue: _category,
                          dropdownColor: LitColors.clay,
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                          decoration: InputDecoration(
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: LitColors.clay2),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.ember),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            filled: true,
                            fillColor: LitColors.clay,
                            contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                          ),
                          items: EventCategory.values.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c.label, style: GoogleFonts.plusJakartaSans()),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _category = v!),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Status
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: r.h(8)),
                        DropdownButtonFormField<EventStatus>(
                          initialValue: _status,
                          dropdownColor: LitColors.clay,
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                          decoration: InputDecoration(
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: LitColors.clay2),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.ember),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            filled: true,
                            fillColor: LitColors.clay,
                            contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                          ),
                          items: EventStatus.values.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.label, style: GoogleFonts.plusJakartaSans()),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Description
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: r.h(8)),
                        TextFormField(
                          controller: _descController,
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter event description',
                            hintStyle: GoogleFonts.plusJakartaSans(color: LitColors.ash.withValues(alpha: 0.5)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: LitColors.clay2),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.ember),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            filled: true,
                            fillColor: LitColors.clay,
                            contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Rules
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rules',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: r.h(8)),
                        TextFormField(
                          controller: _rulesController,
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Enter event rules',
                            hintStyle: GoogleFonts.plusJakartaSans(color: LitColors.ash.withValues(alpha: 0.5)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: LitColors.clay2),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.ember),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            filled: true,
                            fillColor: LitColors.clay,
                            contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Venue
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Venue',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: r.h(8)),
                        TextFormField(
                          controller: _venueController,
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                          decoration: InputDecoration(
                            hintText: 'Enter venue',
                            hintStyle: GoogleFonts.plusJakartaSans(color: LitColors.ash.withValues(alpha: 0.5)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: LitColors.clay2),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: LitColors.ember),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                            ),
                            filled: true,
                            fillColor: LitColors.clay,
                            contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Event Date, Time, Deadline
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      children: [
                        // Event Date
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _eventDate ?? DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: LitColors.ember,
                                      onPrimary: Colors.white,
                                      surface: LitColors.clay,
                                      onSurface: LitColors.bone,
                                    ), dialogTheme: DialogThemeData(backgroundColor: LitColors.void_),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) setState(() => _eventDate = date);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: r.h(12), horizontal: r.w(12)),
                            decoration: BoxDecoration(
                              color: LitColors.clay,
                              borderRadius: BorderRadius.circular(r.radius(12)),
                              border: Border.all(color: LitColors.clay2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: LitColors.ash, size: r.icon(20)),
                                SizedBox(width: r.w(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Event Date',
                                        style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: r.h(2)),
                                      Text(
                                        _eventDate != null ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}' : 'Not set',
                                        style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: r.sp(14)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: r.h(10)),

                        // Event Time
                        GestureDetector(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _eventTime ?? TimeOfDay.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: LitColors.ember,
                                      onPrimary: Colors.white,
                                      surface: LitColors.clay,
                                      onSurface: LitColors.bone,
                                    ), dialogTheme: DialogThemeData(backgroundColor: LitColors.void_),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) setState(() => _eventTime = time);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: r.h(12), horizontal: r.w(12)),
                            decoration: BoxDecoration(
                              color: LitColors.clay,
                              borderRadius: BorderRadius.circular(r.radius(12)),
                              border: Border.all(color: LitColors.clay2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, color: LitColors.ash, size: r.icon(20)),
                                SizedBox(width: r.w(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Event Time',
                                        style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: r.h(2)),
                                      Text(
                                        _eventTime != null ? '${_eventTime!.hour.toString().padLeft(2, '0')}:${_eventTime!.minute.toString().padLeft(2, '0')}' : 'Not set',
                                        style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: r.sp(14)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: r.h(10)),

                        // Registration Deadline
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _deadline ?? DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: LitColors.ember,
                                      onPrimary: Colors.white,
                                      surface: LitColors.clay,
                                      onSurface: LitColors.bone,
                                    ), dialogTheme: DialogThemeData(backgroundColor: LitColors.void_),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) setState(() => _deadline = date);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: r.h(12), horizontal: r.w(12)),
                            decoration: BoxDecoration(
                              color: LitColors.clay,
                              borderRadius: BorderRadius.circular(r.radius(12)),
                              border: Border.all(color: LitColors.clay2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer, color: LitColors.ash, size: r.icon(20)),
                                SizedBox(width: r.w(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Registration Deadline',
                                        style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: r.h(2)),
                                      Text(
                                        _deadline != null ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}' : 'Not set',
                                        style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: r.sp(14)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Capacity and Team Size
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Capacity',
                                style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: r.h(8)),
                              TextFormField(
                                controller: _capacityController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                                decoration: InputDecoration(
                                  hintText: 'Max participants',
                                  hintStyle: GoogleFonts.plusJakartaSans(color: LitColors.ash.withValues(alpha: 0.5)),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: LitColors.clay2),
                                    borderRadius: BorderRadius.circular(r.radius(12)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: LitColors.ember),
                                    borderRadius: BorderRadius.circular(r.radius(12)),
                                  ),
                                  filled: true,
                                  fillColor: LitColors.clay,
                                  contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: r.w(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Team Size',
                                style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(12), fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: r.h(8)),
                              TextFormField(
                                controller: _teamSizeController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.plusJakartaSans(color: LitColors.bone),
                                decoration: InputDecoration(
                                  hintText: 'Per team',
                                  hintStyle: GoogleFonts.plusJakartaSans(color: LitColors.ash.withValues(alpha: 0.5)),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: LitColors.clay2),
                                    borderRadius: BorderRadius.circular(r.radius(12)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: LitColors.ember),
                                    borderRadius: BorderRadius.circular(r.radius(12)),
                                  ),
                                  filled: true,
                                  fillColor: LitColors.clay,
                                  contentPadding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),

                  // Team Event Switch
                  ClayCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Team Event',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontWeight: FontWeight.w600, fontSize: r.sp(14)),
                        ),
                        ClaySwitch(
                          value: _isTeamEvent,
                          onChanged: (v) => setState(() => _isTeamEvent = v),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(24)),

                  // Save Button
                  ClayButton(
                    onPressed: _saveEvent,
                    height: r.h(52),
                    child: Text(
                      isEdit ? 'Update Event' : 'Create Event',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.sp(14)),
                    ),
                  ),
                  SizedBox(height: r.h(20)),
                ],
              ),
            ),
    );
  }
}
