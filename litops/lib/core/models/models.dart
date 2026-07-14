import 'package:litops/core/enums/enums.dart';

class Profile {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? photoUrl;
  final String? profileImage;
  final bool isActive;
  final String? accountStatus;
  final DateTime? dateOfBirth;
  final DateTime? dob;
  final int? year;
  final int? academicYear;
  final String? usn;
  final String? branch;
  final String? department;
  final List<String> customPermissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool profileCompleted;
  final ProfileStatus profileStatus;
  final String? rejectionReason;

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.photoUrl,
    this.profileImage,
    this.isActive = true,
    this.accountStatus,
    this.dateOfBirth,
    this.dob,
    this.year,
    this.academicYear,
    this.usn,
    this.branch,
    this.department,
    this.customPermissions = const [],
    required this.createdAt,
    required this.updatedAt,
    this.profileCompleted = false,
    this.profileStatus = ProfileStatus.pendingReview,
    this.rejectionReason,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final email = json['email'] as String;
    final roleStr = email == 'theliteraryclubmce@gmail.com' ? 'super_admin' : (json['role'] as String);
    
    // Parse custom permissions
    List<String> perms = [];
    if (json['custom_permissions'] != null) {
      try {
        perms = List<String>.from(json['custom_permissions'] as List);
      } catch (_) {
        // Fallback for string representation of postgres array e.g., "{perm1,perm2}"
        final raw = json['custom_permissions'].toString();
        if (raw.startsWith('{') && raw.endsWith('}')) {
          perms = raw.substring(1, raw.length - 1).split(',').where((s) => s.isNotEmpty).toList();
        }
      }
    }

    final rawPhoto = json['photo_url'] as String?;
    final rawProfileImage = json['profile_image'] as String? ?? rawPhoto;

    final rawDobStr = json['dob'] as String? ?? json['date_of_birth'] as String?;
    final rawDob = rawDobStr != null ? DateTime.tryParse(rawDobStr) : null;

    final rawYear = json['year'] as int?;
    final rawAcademicYear = json['academic_year'] as int? ?? rawYear;

    final rawIsActive = json['is_active'] as bool? ?? true;
    final rawAccountStatus = json['account_status'] as String? ?? (rawIsActive ? 'active' : 'disabled');

    return Profile(
      id: json['id'] as String,
      email: email,
      fullName: json['full_name'] as String,
      role: UserRole.fromString(roleStr),
      phone: json['phone'] as String?,
      photoUrl: rawPhoto,
      profileImage: rawProfileImage,
      isActive: rawIsActive,
      accountStatus: rawAccountStatus,
      dateOfBirth: rawDob,
      dob: rawDob,
      year: rawAcademicYear,
      academicYear: rawAcademicYear,
      usn: (() {
        try { return json['usn'] as String?; } catch (_) { return null; }
      })(),
      branch: json['branch'] as String?,
      department: json['department'] as String?,
      customPermissions: perms,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      profileCompleted: json['profile_completed'] as bool? ?? false,
      profileStatus: ProfileStatus.fromString(json['profile_status'] as String?),
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final effectiveImage = profileImage ?? photoUrl;
    final effectiveDob = dob ?? dateOfBirth;
    final effectiveYear = academicYear ?? year;
    final effectiveIsActive = accountStatus == null ? isActive : (accountStatus == 'active');
    final effectiveStatus = accountStatus ?? (effectiveIsActive ? 'active' : 'disabled');

    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.value,
      'phone': phone,
      'photo_url': effectiveImage,
      'profile_image': effectiveImage,
      'is_active': effectiveIsActive,
      'account_status': effectiveStatus,
      'date_of_birth': effectiveDob?.toIso8601String().split('T').first,
      'dob': effectiveDob?.toIso8601String().split('T').first,
      'year': effectiveYear,
      'academic_year': effectiveYear,
      'usn': usn,
      'branch': branch,
      'department': department,
      'custom_permissions': customPermissions,
      'profile_completed': profileCompleted,
      'profile_status': profileStatus.value,
      'rejection_reason': rejectionReason,
    };
  }

  Profile copyWith({
    String? email,
    String? fullName,
    UserRole? role,
    String? phone,
    String? photoUrl,
    String? profileImage,
    bool? isActive,
    String? accountStatus,
    DateTime? dateOfBirth,
    DateTime? dob,
    int? year,
    int? academicYear,
    String? usn,
    String? branch,
    String? department,
    List<String>? customPermissions,
    bool? profileCompleted,
    ProfileStatus? profileStatus,
    String? rejectionReason,
  }) {
    final nextImage = profileImage ?? photoUrl ?? this.profileImage ?? this.photoUrl;
    final nextDob = dob ?? dateOfBirth ?? this.dob ?? this.dateOfBirth;
    final nextYear = academicYear ?? year ?? this.academicYear ?? this.year;
    
    bool nextIsActive = this.isActive;
    if (isActive != null) {
      nextIsActive = isActive;
    } else if (accountStatus != null) {
      nextIsActive = accountStatus == 'active';
    }
    final nextStatus = accountStatus ?? (nextIsActive ? 'active' : 'disabled');

    return Profile(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      photoUrl: nextImage,
      profileImage: nextImage,
      isActive: nextIsActive,
      accountStatus: nextStatus,
      dateOfBirth: nextDob,
      dob: nextDob,
      year: nextYear,
      academicYear: nextYear,
      usn: usn ?? this.usn,
      branch: branch ?? this.branch,
      department: department ?? this.department,
      customPermissions: customPermissions ?? this.customPermissions,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      profileCompleted: profileCompleted ?? this.profileCompleted,
      profileStatus: profileStatus ?? this.profileStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

class Student {
  final String id;
  final String usn;
  final String name;
  final String branch;
  final int year;
  final String? section;
  final String? phone;
  final String? email;
  final String? gender;
  final String? stream;
  final String? photoUrl;
  final StudentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? academicYear;
  final int? semester;
  final String source;
  final String? importBatchId;

  const Student({
    required this.id,
    required this.usn,
    required this.name,
    required this.branch,
    required this.year,
    this.section,
    this.phone,
    this.email,
    this.gender,
    this.stream,
    this.photoUrl,
    this.status = StudentStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.academicYear,
    this.semester,
    this.source = 'fest_registration',
    this.importBatchId,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      usn: json['usn'] as String,
      name: json['name'] as String,
      branch: json['branch'] as String,
      year: json['year'] as int,
      section: json.containsKey('section') ? (json['section'] as String?) : null,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      gender: json['gender'] as String?,
      stream: json['stream'] as String?,
      photoUrl: json['photo_url'] as String?,
      status: StudentStatus.fromString(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      academicYear: json['academic_year'] as String?,
      semester: json['semester'] as int?,
      source: json['source'] as String? ?? 'fest_registration',
      importBatchId: json['import_batch_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usn': usn,
      'name': name,
      'branch': branch,
      'year': year,
      'section': section,
      'phone': phone,
      'email': email,
      'gender': gender,
      'stream': stream,
      'photo_url': photoUrl,
      'status': status.value,
      'academic_year': academicYear,
      'semester': semester,
      'source': source,
      'import_batch_id': importBatchId,
    };
  }

  Student copyWith({
    String? usn,
    String? name,
    String? branch,
    int? year,
    String? section,
    String? phone,
    String? email,
    String? gender,
    String? stream,
    String? photoUrl,
    StudentStatus? status,
    String? academicYear,
    int? semester,
    String? source,
    String? importBatchId,
  }) {
    return Student(
      id: id,
      usn: usn ?? this.usn,
      name: name ?? this.name,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      section: section ?? this.section,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      stream: stream ?? this.stream,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      source: source ?? this.source,
      importBatchId: importBatchId ?? this.importBatchId,
    );
  }
}

class ImportBatch {
  final String id;
  final String fileName;
  final String academicYear;
  final String? uploadedBy;
  final String duplicateMode; // 'replace' | 'skip'
  final String status; // 'pending' | 'processing' | 'completed' | 'failed'
  final int totalRows;
  final int processedRows;
  final int insertedCount;
  final int updatedCount;
  final int skippedCount;
  final String? errorLog;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ImportBatch({
    required this.id,
    required this.fileName,
    required this.academicYear,
    this.uploadedBy,
    required this.duplicateMode,
    required this.status,
    this.totalRows = 0,
    this.processedRows = 0,
    this.insertedCount = 0,
    this.updatedCount = 0,
    this.skippedCount = 0,
    this.errorLog,
    required this.createdAt,
    this.completedAt,
  });

  factory ImportBatch.fromJson(Map<String, dynamic> json) {
    return ImportBatch(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      academicYear: json['academic_year'] as String,
      uploadedBy: json['uploaded_by'] as String?,
      duplicateMode: json['duplicate_mode'] as String,
      status: json['status'] as String,
      totalRows: json['total_rows'] as int? ?? 0,
      processedRows: json['processed_rows'] as int? ?? 0,
      insertedCount: json['inserted_count'] as int? ?? 0,
      updatedCount: json['updated_count'] as int? ?? 0,
      skippedCount: json['skipped_count'] as int? ?? 0,
      errorLog: json['error_log'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'academic_year': academicYear,
      'uploaded_by': uploadedBy,
      'duplicate_mode': duplicateMode,
      'status': status,
      'total_rows': totalRows,
      'processed_rows': processedRows,
      'inserted_count': insertedCount,
      'updated_count': updatedCount,
      'skipped_count': skippedCount,
      'error_log': errorLog,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

class Event {
  final String id;
  final String name;
  final EventCategory category;
  final String? description;
  final String? rules;
  final String? venue;
  final DateTime? eventDate;
  final String? eventTime;
  final String? posterUrl;
  final int? capacity;
  final int teamSize;
  final bool isTeamEvent;
  final DateTime? registrationDeadline;
  final EventStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.rules,
    this.venue,
    this.eventDate,
    this.eventTime,
    this.posterUrl,
    this.capacity,
    this.teamSize = 1,
    this.isTeamEvent = false,
    this.registrationDeadline,
    this.status = EventStatus.draft,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: (json['title'] ?? json['name'] ?? '') as String,
      category: EventCategory.fromString(json['category'] as String),
      description: json['description'] as String?,
      rules: json['rules'] as String?,
      venue: json['venue'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : null,
      eventTime: json['event_time'] as String?,
      posterUrl: json['poster_url'] as String?,
      capacity: json['capacity'] as int?,
      teamSize: json['team_size'] as int? ?? 1,
      isTeamEvent: json['is_team_event'] as bool? ?? false,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String)
          : null,
      status: EventStatus.fromString(json['status'] as String? ?? 'draft'),
      createdBy: (json['created_by'] ?? json['creator_id'] ?? '') as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : (json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': name,
      'category': category.value,
      'description': description,
      'rules': rules,
      'venue': venue,
      'event_date': eventDate?.toIso8601String().split('T').first,
      'event_time': eventTime,
      'poster_url': posterUrl,
      'capacity': capacity,
      'team_size': teamSize,
      'is_team_event': isTeamEvent,
      'registration_deadline': registrationDeadline?.toIso8601String(),
      'status': status.value,
      'created_by': createdBy,
    };
  }

  Event copyWith({
    String? name,
    EventCategory? category,
    String? description,
    String? rules,
    String? venue,
    DateTime? eventDate,
    String? eventTime,
    String? posterUrl,
    int? capacity,
    int? teamSize,
    bool? isTeamEvent,
    DateTime? registrationDeadline,
    EventStatus? status,
  }) {
    return Event(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      venue: venue ?? this.venue,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      posterUrl: posterUrl ?? this.posterUrl,
      capacity: capacity ?? this.capacity,
      teamSize: teamSize ?? this.teamSize,
      isTeamEvent: isTeamEvent ?? this.isTeamEvent,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      status: status ?? this.status,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class Registration {
  final String id;
  final String eventId;
  final String studentId;
  final String? teamId;
  final RegistrationMethod registrationMethod;
  final String registeredBy;
  final DateTime registeredAt;
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  const Registration({
    required this.id,
    required this.eventId,
    required this.studentId,
    this.teamId,
    this.registrationMethod = RegistrationMethod.barcode,
    required this.registeredBy,
    required this.registeredAt,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancelledBy,
  });

  factory Registration.fromJson(Map<String, dynamic> json) {
    return Registration(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      studentId: json['student_id'] as String,
      teamId: json['team_id'] as String?,
      registrationMethod: RegistrationMethod.fromString(
          json['registration_method'] as String? ?? 'barcode'),
      registeredBy: json['registered_by'] as String,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      isCancelled: json['is_cancelled'] as bool? ?? false,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancelledBy: json['cancelled_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'student_id': studentId,
      'team_id': teamId,
      'registration_method': registrationMethod.value,
      'registered_by': registeredBy,
      'is_cancelled': isCancelled,
    };
  }
}

class Team {
  final String id;
  final String eventId;
  final String teamName;
  final String? captainId;
  final String registeredBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Team({
    required this.id,
    required this.eventId,
    required this.teamName,
    this.captainId,
    required this.registeredBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      teamName: json['team_name'] as String,
      captainId: json['captain_id'] as String?,
      registeredBy: json['registered_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'team_name': teamName,
      'captain_id': captainId,
      'registered_by': registeredBy,
    };
  }
}

class TeamMember {
  final String id;
  final String teamId;
  final String studentId;
  final bool isCaptain;
  final DateTime joinedAt;

  const TeamMember({
    required this.id,
    required this.teamId,
    required this.studentId,
    this.isCaptain = false,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      studentId: json['student_id'] as String,
      isCaptain: json['is_captain'] as bool? ?? false,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'student_id': studentId,
      'is_captain': isCaptain,
    };
  }
}

class WaitingListEntry {
  final String id;
  final String eventId;
  final String studentId;
  final int position;
  final DateTime addedAt;
  final DateTime? promotedAt;
  final bool isPromoted;

  const WaitingListEntry({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.position,
    required this.addedAt,
    this.promotedAt,
    this.isPromoted = false,
  });

  factory WaitingListEntry.fromJson(Map<String, dynamic> json) {
    return WaitingListEntry(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      studentId: json['student_id'] as String,
      position: json['position'] as int,
      addedAt: DateTime.parse(json['added_at'] as String),
      promotedAt: json['promoted_at'] != null
          ? DateTime.parse(json['promoted_at'] as String)
          : null,
      isPromoted: json['is_promoted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'student_id': studentId,
      'position': position,
      'is_promoted': isPromoted,
    };
  }
}

class AttendanceRecord {
  final String id;
  final String eventId;
  final String registrationId;
  final String studentId;
  final String? markedBy;
  final DateTime markedAt;
  final RegistrationMethod method;
  final bool isOffline;
  final DateTime? syncedAt;

  const AttendanceRecord({
    required this.id,
    required this.eventId,
    required this.registrationId,
    required this.studentId,
    this.markedBy,
    required this.markedAt,
    this.method = RegistrationMethod.barcode,
    this.isOffline = false,
    this.syncedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      registrationId: json['registration_id'] as String,
      studentId: json['student_id'] as String,
      markedBy: json['marked_by'] as String?,
      markedAt: DateTime.parse(json['marked_at'] as String),
      method: RegistrationMethod.fromString(
          json['method'] as String? ?? 'barcode'),
      isOffline: json['is_offline'] as bool? ?? false,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'registration_id': registrationId,
      'student_id': studentId,
      'marked_by': markedBy,
      'method': method.value,
      'is_offline': isOffline,
    };
  }
}

class EventRound {
  final String id;
  final String eventId;
  final int roundNumber;
  final String roundName;
  final String? description;
  final RoundStatus status;
  final String? qualificationCriteria;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventRound({
    required this.id,
    required this.eventId,
    required this.roundNumber,
    required this.roundName,
    this.description,
    this.status = RoundStatus.pending,
    this.qualificationCriteria,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventRound.fromJson(Map<String, dynamic> json) {
    return EventRound(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      roundNumber: json['round_number'] as int,
      roundName: json['round_name'] as String,
      description: json['description'] as String?,
      status: RoundStatus.fromString(json['status'] as String? ?? 'pending'),
      qualificationCriteria: json['qualification_criteria'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'round_number': roundNumber,
      'round_name': roundName,
      'description': description,
      'status': status.value,
      'qualification_criteria': qualificationCriteria,
    };
  }
}

class RoundScore {
  final String id;
  final String roundId;
  final String registrationId;
  final double? score;
  final String? remarks;
  final bool? isQualified;
  final String? scoredBy;
  final DateTime scoredAt;

  const RoundScore({
    required this.id,
    required this.roundId,
    required this.registrationId,
    this.score,
    this.remarks,
    this.isQualified,
    this.scoredBy,
    required this.scoredAt,
  });

  factory RoundScore.fromJson(Map<String, dynamic> json) {
    return RoundScore(
      id: json['id'] as String,
      roundId: json['round_id'] as String,
      registrationId: json['registration_id'] as String,
      score: (json['score'] as num?)?.toDouble(),
      remarks: json['remarks'] as String?,
      isQualified: json['is_qualified'] as bool?,
      scoredBy: json['scored_by'] as String?,
      scoredAt: DateTime.parse(json['scored_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'round_id': roundId,
      'registration_id': registrationId,
      'score': score,
      'remarks': remarks,
      'is_qualified': isQualified,
      'scored_by': scoredBy,
    };
  }
}

class Result {
  final String id;
  final String eventId;
  final String registrationId;
  final String? teamId;
  final ResultPosition position;
  final double? score;
  final String? remarks;
  final DateTime? publishedAt;
  final String? publishedBy;
  final DateTime createdAt;

  const Result({
    required this.id,
    required this.eventId,
    required this.registrationId,
    this.teamId,
    required this.position,
    this.score,
    this.remarks,
    this.publishedAt,
    this.publishedBy,
    required this.createdAt,
  });

  factory Result.fromJson(Map<String, dynamic> json) {
    return Result(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      registrationId: json['registration_id'] as String,
      teamId: json['team_id'] as String?,
      position: ResultPosition.fromString(json['position'] as String),
      score: (json['score'] as num?)?.toDouble(),
      remarks: json['remarks'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      publishedBy: json['published_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'registration_id': registrationId,
      'team_id': teamId,
      'position': position.value,
      'score': score,
      'remarks': remarks,
    };
  }
}

class Certificate {
  final String id;
  final String eventId;
  final String studentId;
  final CertificateType certificateType;
  final String? certificateUrl;
  final String qrCode;
  final DateTime issuedAt;
  final String? issuedBy;

  const Certificate({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.certificateType,
    this.certificateUrl,
    required this.qrCode,
    required this.issuedAt,
    this.issuedBy,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      studentId: json['student_id'] as String,
      certificateType:
          CertificateType.fromString(json['certificate_type'] as String),
      certificateUrl: json['certificate_url'] as String?,
      qrCode: json['qr_code'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      issuedBy: json['issued_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'student_id': studentId,
      'certificate_type': certificateType.value,
      'certificate_url': certificateUrl,
      'qr_code': qrCode,
      'issued_by': issuedBy,
    };
  }
}

class FeedbackEntry {
  final String id;
  final String eventId;
  final String? studentId;
  final int? eventQuality;
  final int? venueRating;
  final int? organizationRating;
  final String? comments;
  final DateTime createdAt;

  const FeedbackEntry({
    required this.id,
    required this.eventId,
    this.studentId,
    this.eventQuality,
    this.venueRating,
    this.organizationRating,
    this.comments,
    required this.createdAt,
  });

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) {
    return FeedbackEntry(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      studentId: json['student_id'] as String?,
      eventQuality: json['event_quality'] as int?,
      venueRating: json['venue_rating'] as int?,
      organizationRating: json['organization_rating'] as int?,
      comments: json['comments'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'student_id': studentId,
      'event_quality': eventQuality,
      'venue_rating': venueRating,
      'organization_rating': organizationRating,
      'comments': comments,
    };
  }
}

class Appeal {
  final String id;
  final String eventId;
  final String studentId;
  final AppealType appealType;
  final String description;
  final AppealStatus status;
  final String? resolution;
  final DateTime submittedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final DateTime updatedAt;

  const Appeal({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.appealType,
    required this.description,
    this.status = AppealStatus.submitted,
    this.resolution,
    required this.submittedAt,
    this.resolvedAt,
    this.resolvedBy,
    required this.updatedAt,
  });

  factory Appeal.fromJson(Map<String, dynamic> json) {
    return Appeal(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      studentId: json['student_id'] as String,
      appealType: AppealType.fromString(json['appeal_type'] as String),
      description: json['description'] as String,
      status: AppealStatus.fromString(json['status'] as String? ?? 'submitted'),
      resolution: json['resolution'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedBy: json['resolved_by'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'student_id': studentId,
      'appeal_type': appealType.value,
      'description': description,
      'status': status.value,
      'resolution': resolution,
    };
  }
}

class SarvottamPoint {
  final String id;
  final String eventId;
  final String branch;
  final String? studentId;
  final String? teamId;
  final int points;
  final String reason;
  final ResultPosition? position;
  final DateTime createdAt;

  const SarvottamPoint({
    required this.id,
    required this.eventId,
    required this.branch,
    this.studentId,
    this.teamId,
    required this.points,
    required this.reason,
    this.position,
    required this.createdAt,
  });

  factory SarvottamPoint.fromJson(Map<String, dynamic> json) {
    return SarvottamPoint(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      branch: json['branch'] as String,
      studentId: json['student_id'] as String?,
      teamId: json['team_id'] as String?,
      points: json['points'] as int,
      reason: json['reason'] as String,
      position: json['position'] != null
          ? ResultPosition.fromString(json['position'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AuditLog {
  final String id;
  final String? userId;
  final UserRole? userRole;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    this.userId,
    this.userRole,
    required this.action,
    required this.entityType,
    this.entityId,
    this.details,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userRole: json['user_role'] != null
          ? UserRole.fromString(json['user_role'] as String)
          : null,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Announcement {
  final String id;
  final String? eventId;
  final String title;
  final String message;
  final int priority;
  final String createdBy;
  final DateTime createdAt;

  const Announcement({
    required this.id,
    this.eventId,
    required this.title,
    required this.message,
    this.priority = 1,
    required this.createdBy,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      priority: json['priority'] as int? ?? 1,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'title': title,
      'message': message,
      'priority': priority,
      'created_by': createdBy,
    };
  }
}

class Incident {
  final String id;
  final String eventId;
  final String title;
  final String description;
  final int severity;
  final String reportedBy;
  final bool resolved;
  final String? resolution;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Incident({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    this.severity = 1,
    required this.reportedBy,
    this.resolved = false,
    this.resolution,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: json['severity'] as int? ?? 1,
      reportedBy: json['reported_by'] as String,
      resolved: json['resolved'] as bool? ?? false,
      resolution: json['resolution'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'title': title,
      'description': description,
      'severity': severity,
      'reported_by': reportedBy,
      'resolved': resolved,
      'resolution': resolution,
    };
  }
}

class NotificationItem {
  final String id;
  final String? userId;
  final String? senderUserId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? eventId;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    this.userId,
    this.senderUserId,
    required this.title,
    required this.message,
    this.type = 'general',
    this.isRead = false,
    this.eventId,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      senderUserId: json['sender_user_id'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String? ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      eventId: json['event_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'sender_user_id': senderUserId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'event_id': eventId,
    };
  }
}

class EventAssignment {
  final String id;
  final String eventId;
  final String userId;
  final AssignmentRole assignmentRole;
  final String assignedBy;
  final DateTime createdAt;

  const EventAssignment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.assignmentRole,
    required this.assignedBy,
    required this.createdAt,
  });

  factory EventAssignment.fromJson(Map<String, dynamic> json) {
    return EventAssignment(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      assignmentRole:
          AssignmentRole.fromString(json['assignment_role'] as String),
      assignedBy: json['assigned_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'assignment_role': assignmentRole.value,
      'assigned_by': assignedBy,
    };
  }
}

class ParticipationConstraint {
  final String id;
  final String eventId;
  final String branch;
  final int maxParticipants;
  final DateTime createdAt;

  const ParticipationConstraint({
    required this.id,
    required this.eventId,
    required this.branch,
    required this.maxParticipants,
    required this.createdAt,
  });

  factory ParticipationConstraint.fromJson(Map<String, dynamic> json) {
    return ParticipationConstraint(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      branch: json['branch'] as String,
      maxParticipants: json['max_participants'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'branch': branch,
      'max_participants': maxParticipants,
    };
  }
}

// ============================================================================
// ENTERPRISE EXTENSION MODELS
// ============================================================================

class ClubMember {
  final String id;
  final String userId;
  final UserRole role;
  final MemberStatus status;
  final String assignedBy;
  final DateTime assignedAt;
  final DateTime? suspendedAt;
  final String? suspendedReason;
  final DateTime? reactivatedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? memberName;
  final String? memberEmail;
  final String? memberPhone;
  final int? memberYear;

  const ClubMember({
    required this.id,
    required this.userId,
    required this.role,
    this.status = MemberStatus.active,
    required this.assignedBy,
    required this.assignedAt,
    this.suspendedAt,
    this.suspendedReason,
    this.reactivatedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.memberName,
    this.memberEmail,
    this.memberPhone,
    this.memberYear,
  });

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ClubMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: UserRole.fromString(json['role'] as String),
      status: MemberStatus.fromString(json['status'] as String? ?? 'active'),
      assignedBy: json['assigned_by'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      suspendedAt: json['suspended_at'] != null
          ? DateTime.parse(json['suspended_at'] as String)
          : null,
      suspendedReason: json['suspended_reason'] as String?,
      reactivatedAt: json['reactivated_at'] != null
          ? DateTime.parse(json['reactivated_at'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      memberName: profile?['full_name'] as String?,
      memberEmail: profile?['email'] as String?,
      memberPhone: profile?['phone'] as String?,
      memberYear: profile?['year'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role.value,
      'status': status.value,
      'assigned_by': assignedBy,
      'suspended_reason': suspendedReason,
      'notes': notes,
    };
  }
}

class YearlyArchive {
  final String id;
  final int festYear;
  final String festName;
  final int totalEvents;
  final int totalRegistrations;
  final int totalParticipants;
  final int totalAttendance;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const YearlyArchive({
    required this.id,
    required this.festYear,
    this.festName = 'Malnad Fest',
    this.totalEvents = 0,
    this.totalRegistrations = 0,
    this.totalParticipants = 0,
    this.totalAttendance = 0,
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory YearlyArchive.fromJson(Map<String, dynamic> json) {
    return YearlyArchive(
      id: json['id'] as String,
      festYear: json['fest_year'] as int,
      festName: json['fest_name'] as String? ?? 'Malnad Fest',
      totalEvents: json['total_events'] as int? ?? 0,
      totalRegistrations: json['total_registrations'] as int? ?? 0,
      totalParticipants: json['total_participants'] as int? ?? 0,
      totalAttendance: json['total_attendance'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fest_year': festYear,
      'fest_name': festName,
      'total_events': totalEvents,
      'total_registrations': totalRegistrations,
      'total_participants': totalParticipants,
      'total_attendance': totalAttendance,
      'is_active': isActive,
      'created_by': createdBy,
    };
  }
}

class YearlyImport {
  final String id;
  final int festYear;
  final String fileName;
  final String fileType;
  final int totalRecords;
  final int successfulImports;
  final int failedImports;
  final int duplicateCount;
  final String importedBy;
  final DateTime createdAt;

  const YearlyImport({
    required this.id,
    required this.festYear,
    required this.fileName,
    required this.fileType,
    this.totalRecords = 0,
    this.successfulImports = 0,
    this.failedImports = 0,
    this.duplicateCount = 0,
    required this.importedBy,
    required this.createdAt,
  });

  factory YearlyImport.fromJson(Map<String, dynamic> json) {
    return YearlyImport(
      id: json['id'] as String,
      festYear: json['fest_year'] as int,
      fileName: json['file_name'] as String,
      fileType: json['file_type'] as String,
      totalRecords: json['total_records'] as int? ?? 0,
      successfulImports: json['successful_imports'] as int? ?? 0,
      failedImports: json['failed_imports'] as int? ?? 0,
      duplicateCount: json['duplicate_count'] as int? ?? 0,
      importedBy: json['imported_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AuditExtended {
  final String id;
  final String? userId;
  final String? userEmail;
  final UserRole? userRole;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? previousValue;
  final Map<String, dynamic>? newValue;
  final String? ipAddress;
  final String? deviceInfo;
  final DateTime createdAt;

  const AuditExtended({
    required this.id,
    this.userId,
    this.userEmail,
    this.userRole,
    required this.action,
    required this.entityType,
    this.entityId,
    this.previousValue,
    this.newValue,
    this.ipAddress,
    this.deviceInfo,
    required this.createdAt,
  });

  factory AuditExtended.fromJson(Map<String, dynamic> json) {
    return AuditExtended(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      userRole: json['user_role'] != null
          ? UserRole.fromString(json['user_role'] as String)
          : null,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      previousValue: json['previous_value'] is Map
          ? Map<String, dynamic>.from(json['previous_value'] as Map)
          : null,
      newValue: json['new_value'] is Map
          ? Map<String, dynamic>.from(json['new_value'] as Map)
          : null,
      ipAddress: json['ip_address'] as String?,
      deviceInfo: json['device_info'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DepartmentRanking {
  final String id;
  final int festYear;
  final String branch;
  final int totalPoints;
  final int totalParticipations;
  final int totalWins;
  final int totalRunnerUps;
  final int totalSecondRunnerUps;
  final int? rankPosition;
  final DateTime lastCalculatedAt;

  const DepartmentRanking({
    required this.id,
    required this.festYear,
    required this.branch,
    this.totalPoints = 0,
    this.totalParticipations = 0,
    this.totalWins = 0,
    this.totalRunnerUps = 0,
    this.totalSecondRunnerUps = 0,
    this.rankPosition,
    required this.lastCalculatedAt,
  });

  factory DepartmentRanking.fromJson(Map<String, dynamic> json) {
    return DepartmentRanking(
      id: json['id'] as String,
      festYear: json['fest_year'] as int,
      branch: json['branch'] as String,
      totalPoints: json['total_points'] as int? ?? 0,
      totalParticipations: json['total_participations'] as int? ?? 0,
      totalWins: json['total_wins'] as int? ?? 0,
      totalRunnerUps: json['total_runner_ups'] as int? ?? 0,
      totalSecondRunnerUps: json['total_second_runner_ups'] as int? ?? 0,
      rankPosition: json['rank_position'] as int?,
      lastCalculatedAt: DateTime.parse(json['last_calculated_at'] as String),
    );
  }
}

class EventPoint {
  final String id;
  final String eventId;
  final String branch;
  final String? studentId;
  final String? teamId;
  final int points;
  final String reason;
  final ResultPosition? position;
  final String allocatedBy;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventPoint({
    required this.id,
    required this.eventId,
    required this.branch,
    this.studentId,
    this.teamId,
    this.points = 0,
    required this.reason,
    this.position,
    required this.allocatedBy,
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventPoint.fromJson(Map<String, dynamic> json) {
    return EventPoint(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      branch: json['branch'] as String,
      studentId: json['student_id'] as String?,
      teamId: json['team_id'] as String?,
      points: json['points'] as int? ?? 0,
      reason: json['reason'] as String,
      position: json['position'] != null
          ? ResultPosition.fromString(json['position'] as String)
          : null,
      allocatedBy: json['allocated_by'] as String,
      approvedBy: json['approved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'branch': branch,
      'student_id': studentId,
      'team_id': teamId,
      'points': points,
      'reason': reason,
      'position': position?.value,
      'allocated_by': allocatedBy,
      'approved_by': approvedBy,
    };
  }
}

class EventSchedule {
  final String id;
  final String eventId;
  final DateTime scheduleDate;
  final String startTime;
  final String endTime;
  final String venue;
  final bool isParallel;
  final String? parallelGroup;
  final int volunteerCount;
  final String? coordinatorId;
  final String? notes;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? eventName;
  final String? coordinatorName;

  const EventSchedule({
    required this.id,
    required this.eventId,
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    required this.venue,
    this.isParallel = false,
    this.parallelGroup,
    this.volunteerCount = 0,
    this.coordinatorId,
    this.notes,
    this.status = 'scheduled',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.eventName,
    this.coordinatorName,
  });

  factory EventSchedule.fromJson(Map<String, dynamic> json) {
    return EventSchedule(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      scheduleDate: DateTime.parse(json['schedule_date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      venue: json['venue'] as String,
      isParallel: json['is_parallel'] as bool? ?? false,
      parallelGroup: json['parallel_group'] as String?,
      volunteerCount: json['volunteer_count'] as int? ?? 0,
      coordinatorId: json['coordinator_id'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      eventName: ((json['events'] as Map<String, dynamic>?)?['title'] ?? (json['events'] as Map<String, dynamic>?)?['name']) as String?,
      coordinatorName: (json['coordinator'] as Map<String, dynamic>?)?['full_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'schedule_date': scheduleDate.toIso8601String().split('T').first,
      'start_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'is_parallel': isParallel,
      'parallel_group': parallelGroup,
      'volunteer_count': volunteerCount,
      'coordinator_id': coordinatorId,
      'notes': notes,
      'status': status,
      'created_by': createdBy,
    };
  }
}

class BarcodeLog {
  final String id;
  final String? eventId;
  final String? studentId;
  final String barcodeData;
  final String scanResult;
  final String? scannedBy;
  final String? deviceInfo;
  final DateTime createdAt;

  const BarcodeLog({
    required this.id,
    this.eventId,
    this.studentId,
    required this.barcodeData,
    required this.scanResult,
    this.scannedBy,
    this.deviceInfo,
    required this.createdAt,
  });

  factory BarcodeLog.fromJson(Map<String, dynamic> json) {
    return BarcodeLog(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      studentId: json['student_id'] as String?,
      barcodeData: json['barcode_data'] as String,
      scanResult: json['scan_result'] as String,
      scannedBy: json['scanned_by'] as String?,
      deviceInfo: json['device_info'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'student_id': studentId,
      'barcode_data': barcodeData,
      'scan_result': scanResult,
      'scanned_by': scannedBy,
      'device_info': deviceInfo,
    };
  }
}

class SearchHistoryEntry {
  final String id;
  final String userId;
  final String query;
  final String? resultType;
  final int resultCount;
  final DateTime createdAt;

  const SearchHistoryEntry({
    required this.id,
    required this.userId,
    required this.query,
    this.resultType,
    this.resultCount = 0,
    required this.createdAt,
  });

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      query: json['query'] as String,
      resultType: json['result_type'] as String?,
      resultCount: json['result_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'query': query,
      'result_type': resultType,
      'result_count': resultCount,
    };
  }
}

class SearchResult {
  final String resultType;
  final String resultId;
  final String primaryText;
  final String secondaryText;
  final double similarityScore;

  const SearchResult({
    required this.resultType,
    required this.resultId,
    required this.primaryText,
    required this.secondaryText,
    this.similarityScore = 0.0,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      resultType: json['result_type'] as String,
      resultId: json['result_id'] as String,
      primaryText: json['primary_text'] as String,
      secondaryText: json['secondary_text'] as String? ?? '',
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Rulebook {
  final String id;
  final String fileUrl;
  final String? uploadedBy;
  final DateTime uploadedAt;

  const Rulebook({
    required this.id,
    required this.fileUrl,
    this.uploadedBy,
    required this.uploadedAt,
  });

  factory Rulebook.fromJson(Map<String, dynamic> json) {
    return Rulebook(
      id: json['id'] as String,
      fileUrl: json['file_url'] as String,
      uploadedBy: json['uploaded_by'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_url': fileUrl,
      'uploaded_by': uploadedBy,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

