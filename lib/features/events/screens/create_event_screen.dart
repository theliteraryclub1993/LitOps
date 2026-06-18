import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';
import 'event_detail_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(isEdit ? 'Edit Event' : 'Create Event', style: const TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isLoadingEvent ? null : _saveEvent,
            child: Text(
              isEdit ? 'Update' : 'Save',
              style: const TextStyle(color: Color(0xFFFF6A2C), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoadingEvent
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Event Name *'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EventCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: EventCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EventStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: EventStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                  const SizedBox(height: 16),
                  TextFormField(controller: _rulesController, decoration: const InputDecoration(labelText: 'Rules'), maxLines: 4),
                  const SizedBox(height: 16),
                  TextFormField(controller: _venueController, decoration: const InputDecoration(labelText: 'Venue')),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Event Date'),
                    subtitle: Text(_eventDate != null ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}' : 'Not set'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: _eventDate ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                      if (date != null) setState(() => _eventDate = date);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Event Time'),
                    subtitle: Text(_eventTime != null ? '${_eventTime!.hour}:${_eventTime!.minute.toString().padLeft(2, '0')}' : 'Not set'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: _eventTime ?? TimeOfDay.now());
                      if (time != null) setState(() => _eventTime = time);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Registration Deadline'),
                    subtitle: Text(_deadline != null ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}' : 'Not set'),
                    trailing: const Icon(Icons.timer),
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: _deadline ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                      if (date != null) setState(() => _deadline = date);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          decoration: const InputDecoration(labelText: 'Capacity'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _teamSizeController,
                          decoration: const InputDecoration(labelText: 'Team Size'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Team Event'),
                    value: _isTeamEvent,
                    onChanged: (v) => setState(() => _isTeamEvent = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveEvent,
                      child: Text(isEdit ? 'Update Event' : 'Create Event'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
