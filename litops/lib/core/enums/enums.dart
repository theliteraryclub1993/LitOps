enum UserRole {
  superAdmin('super_admin', 'Super Admin'),
  studentPresident('student_president', 'Student President'),
  studentVicePresident('student_vice_president', 'Student Vice President'),
  jointSecretary('joint_secretary', 'Joint Secretary'),
  creativeDirector('creative_director', 'Creative Director'),
  eventDirector('event_director', 'Event Director'),
  designerInChief('designer_in_chief', 'Designer in Chief'),
  treasurer('treasurer', 'Treasurer'),
  coTreasurerSocialMedia('co_treasurer_social_media', 'Co-treasurer and Social Media Manager'),
  editorialHead('editorial_head', 'Editorial Head'),
  eventManager('event_manager', 'Event Manager'),
  eventManagerCoEditorial('event_manager_co_editorial', 'Event Manager and Co-editorial Head'),
  creativeHead('creative_head', 'Creative Head'),
  digitalHead('digital_head', 'Digital Head'),
  databaseManager('database_manager', 'Database Manager'),
  photographyHead('photography_head', 'Photography Head'),
  assistantCoordinator('assistant_coordinator', 'Assistant Coordinator'),
  juniorWing('junior_wing', 'Junior Wing');

  final String value;
  final String label;
  const UserRole(this.value, this.label);

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.juniorWing;
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.juniorWing,
    );
  }

  bool get isSuperAdmin => this == UserRole.superAdmin;

  bool get isAdmin =>
      this == UserRole.superAdmin ||
      this == UserRole.studentPresident ||
      this == UserRole.studentVicePresident ||
      this == UserRole.jointSecretary ||
      this == UserRole.eventDirector ||
      this == UserRole.creativeDirector ||
      this == UserRole.designerInChief;

  bool get isCoreCommittee =>
      this != UserRole.eventManager &&
      this != UserRole.eventManagerCoEditorial &&
      this != UserRole.assistantCoordinator &&
      this != UserRole.juniorWing;

  bool get canRegisterParticipants => this != UserRole.juniorWing;

  bool get canEditRegistrations =>
      isAdmin ||
      this == UserRole.eventManager ||
      this == UserRole.eventManagerCoEditorial;

  bool get canDeleteRegistrations => isSuperAdmin;

  bool get canManualEntry =>
      isSuperAdmin ||
      this == UserRole.studentPresident ||
      this == UserRole.databaseManager;

  bool get canManageEvents => this != UserRole.juniorWing && this != UserRole.assistantCoordinator;

  bool get canCreateEvents => this != UserRole.juniorWing && this != UserRole.assistantCoordinator;

  bool get canAssignMembers =>
      isSuperAdmin ||
      this == UserRole.eventManager ||
      this == UserRole.eventManagerCoEditorial ||
      this == UserRole.studentPresident ||
      this == UserRole.studentVicePresident ||
      this == UserRole.jointSecretary ||
      this == UserRole.creativeDirector ||
      this == UserRole.eventDirector ||
      this == UserRole.designerInChief;

  bool get canManageDatabase =>
      isSuperAdmin ||
      this == UserRole.databaseManager ||
      this == UserRole.studentPresident;

  bool get canResetDatabase => isSuperAdmin || this == UserRole.studentPresident;

  bool get canViewAppeals =>
      isSuperAdmin ||
      this == UserRole.studentPresident ||
      this == UserRole.studentVicePresident ||
      this == UserRole.jointSecretary;

  bool get canManageResults =>
      isSuperAdmin ||
      isAdmin ||
      this == UserRole.eventManager ||
      this == UserRole.eventManagerCoEditorial;

  bool get canGenerateCertificates => isAdmin;

  bool get canMarkAttendance => true;

  // Enterprise extension getters
  bool get canEditPoints => isSuperAdmin;

  bool get canManageMembers => isSuperAdmin;

  bool get canManageYearlyData => isSuperAdmin;

  bool get canManageEventSchedule =>
      isSuperAdmin ||
      this == UserRole.eventManager ||
      this == UserRole.eventManagerCoEditorial ||
      this == UserRole.studentPresident ||
      this == UserRole.studentVicePresident ||
      this == UserRole.jointSecretary ||
      this == UserRole.creativeDirector ||
      this == UserRole.eventDirector ||
      this == UserRole.designerInChief;

  bool get canViewAuditLogs => isSuperAdmin;

  bool get canImportData =>
      isSuperAdmin || this == UserRole.databaseManager;

  int get hierarchyLevel {
    switch (this) {
      case UserRole.superAdmin:
        return 0;
      case UserRole.studentPresident:
        return 1;
      case UserRole.studentVicePresident:
        return 2;
      case UserRole.jointSecretary:
        return 3;
      case UserRole.creativeDirector:
        return 4;
      case UserRole.eventDirector:
        return 5;
      case UserRole.designerInChief:
        return 6;
      case UserRole.treasurer:
        return 7;
      case UserRole.coTreasurerSocialMedia:
        return 8;
      case UserRole.editorialHead:
        return 9;
      case UserRole.eventManager:
        return 10;
      case UserRole.eventManagerCoEditorial:
        return 11;
      case UserRole.creativeHead:
        return 12;
      case UserRole.digitalHead:
        return 13;
      case UserRole.databaseManager:
        return 14;
      case UserRole.photographyHead:
        return 15;
      case UserRole.assistantCoordinator:
        return 16;
      case UserRole.juniorWing:
        return 17;
    }
  }
}


enum EventCategory {
  balwaan('balwaan', 'Balwaan', 'Sports Events'),
  buddhimaan('buddhimaan', 'Buddhimaan', 'Intellectual Events'),
  darpan('darpan', 'Darpan', 'Stage Events'),
  kalakruthi('kalakruthi', 'Kalakruthi', 'Creative Events');

  final String value;
  final String label;
  final String description;
  const EventCategory(this.value, this.label, this.description);

  static EventCategory fromString(String value) {
    return EventCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventCategory.balwaan,
    );
  }
}

enum EventStatus {
  draft('draft', 'Draft'),
  upcoming('upcoming', 'Upcoming'),
  registrationOpen('registration_open', 'Registration Open'),
  registrationClosed('registration_closed', 'Registration Closed'),
  ongoing('ongoing', 'Ongoing'),
  completed('completed', 'Completed'),
  resultsPublished('results_published', 'Results Published'),
  archived('archived', 'Archived');

  final String value;
  final String label;
  const EventStatus(this.value, this.label);

  static EventStatus fromString(String value) {
    return EventStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventStatus.draft,
    );
  }
}

enum RegistrationMethod {
  barcode('barcode', 'Barcode Scan'),
  usnSearch('usn_search', 'USN Search'),
  manual('manual', 'Manual Entry');

  final String value;
  final String label;
  const RegistrationMethod(this.value, this.label);

  static RegistrationMethod fromString(String value) {
    return RegistrationMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RegistrationMethod.barcode,
    );
  }
}

enum AppealStatus {
  submitted('submitted', 'Submitted'),
  underReview('under_review', 'Under Review'),
  resolved('resolved', 'Resolved'),
  rejected('rejected', 'Rejected');

  final String value;
  final String label;
  const AppealStatus(this.value, this.label);

  static AppealStatus fromString(String value) {
    return AppealStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AppealStatus.submitted,
    );
  }
}

enum AppealType {
  registrationIssue('registration_issue', 'Registration Issue'),
  attendanceIssue('attendance_issue', 'Attendance Issue'),
  scoreDispute('score_dispute', 'Score Dispute');

  final String value;
  final String label;
  const AppealType(this.value, this.label);

  static AppealType fromString(String value) {
    return AppealType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AppealType.registrationIssue,
    );
  }
}

enum CertificateType {
  participation('participation', 'Participation'),
  winner('winner', 'Winner'),
  runnerUp('runner_up', 'Runner-Up'),
  secondRunnerUp('second_runner_up', 'Second Runner-Up'),
  volunteer('volunteer', 'Volunteer');

  final String value;
  final String label;
  const CertificateType(this.value, this.label);

  static CertificateType fromString(String value) {
    return CertificateType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CertificateType.participation,
    );
  }
}

enum ResultPosition {
  winner('winner', 'Winner', 10),
  runnerUp('runner_up', 'Runner-Up', 7),
  secondRunnerUp('second_runner_up', 'Second Runner-Up', 5);

  final String value;
  final String label;
  final int points;
  const ResultPosition(this.value, this.label, this.points);

  static ResultPosition fromString(String value) {
    return ResultPosition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ResultPosition.winner,
    );
  }
}

enum AssignmentRole {
  primaryHandler('primary_handler', 'Primary Handler'),
  secondaryHandler('secondary_handler', 'Secondary Handler'),
  supportMember('support_member', 'Support Member'),
  photographer('photographer', 'Photographer'),
  volunteer('volunteer', 'Volunteer');

  final String value;
  final String label;
  const AssignmentRole(this.value, this.label);

  static AssignmentRole fromString(String value) {
    return AssignmentRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AssignmentRole.volunteer,
    );
  }
}

enum RoundStatus {
  pending('pending', 'Pending'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed');

  final String value;
  final String label;
  const RoundStatus(this.value, this.label);

  static RoundStatus fromString(String value) {
    return RoundStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RoundStatus.pending,
    );
  }
}

enum StudentStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive'),
  graduated('graduated', 'Graduated');

  final String value;
  final String label;
  const StudentStatus(this.value, this.label);

  static StudentStatus fromString(String value) {
    return StudentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StudentStatus.active,
    );
  }
}

enum MemberStatus {
  active('active', 'Active'),
  suspended('suspended', 'Suspended'),
  inactive('inactive', 'Inactive');

  final String value;
  final String label;
  const MemberStatus(this.value, this.label);

  static MemberStatus fromString(String value) {
    return MemberStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MemberStatus.active,
    );
  }
}

enum ProfileStatus {
  pendingReview('pending_review', 'Pending Review'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  final String value;
  final String label;
  const ProfileStatus(this.value, this.label);

  static ProfileStatus fromString(String? value) {
    if (value == null) return ProfileStatus.pendingReview;
    return ProfileStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProfileStatus.pendingReview,
    );
  }
}
