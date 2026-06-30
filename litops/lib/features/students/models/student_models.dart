import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';

class RegistrationWithEvent {
  final String registrationId;
  final String eventId;
  final String eventName;
  final DateTime registeredAt;
  final String? teamId;
  final String? teamName;

  const RegistrationWithEvent({
    required this.registrationId,
    required this.eventId,
    required this.eventName,
    required this.registeredAt,
    this.teamId,
    this.teamName,
  });
}

class UnifiedStudent {
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

  // Unified / resolved fields
  final String academicYear;
  final int festYear;
  final bool isRegistered;
  final String dataSource; // 'Current Year' or 'Previous Years'

  const UnifiedStudent({
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
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.academicYear,
    required this.festYear,
    required this.isRegistered,
    required this.dataSource,
  });

  factory UnifiedStudent.fromStudent(
    Student student, {
    required String academicYear,
    required int festYear,
    required bool isRegistered,
    required String dataSource,
  }) {
    return UnifiedStudent(
      id: student.id,
      usn: student.usn,
      name: student.name,
      branch: student.branch,
      year: student.year,
      section: student.section,
      phone: student.phone,
      email: student.email,
      gender: student.gender,
      stream: student.stream,
      photoUrl: student.photoUrl,
      status: student.status,
      createdAt: student.createdAt,
      updatedAt: student.updatedAt,
      academicYear: academicYear,
      festYear: festYear,
      isRegistered: isRegistered,
      dataSource: dataSource,
    );
  }
}
