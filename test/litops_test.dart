import 'package:flutter_test/flutter_test.dart';
import 'package:litops/core/enums/enums.dart';
import 'package:litops/core/utils/app_utils.dart';
import 'package:litops/core/models/models.dart';

void main() {
  group('UserRole', () {
    test('fromString returns correct role', () {
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRole.fromString('student_president'), UserRole.studentPresident);
      expect(UserRole.fromString('junior_wing'), UserRole.juniorWing);
      expect(UserRole.fromString('unknown'), UserRole.juniorWing);
    });

    test('isAdmin returns true for admin roles', () {
      expect(UserRole.superAdmin.isAdmin, true);
      expect(UserRole.studentPresident.isAdmin, true);
      expect(UserRole.studentVicePresident.isAdmin, true);
      expect(UserRole.jointSecretary.isAdmin, true);
      expect(UserRole.eventDirector.isAdmin, true);
      expect(UserRole.juniorWing.isAdmin, false);
    });

    test('isSuperAdmin returns true only for superAdmin', () {
      expect(UserRole.superAdmin.isSuperAdmin, true);
      expect(UserRole.studentPresident.isSuperAdmin, false);
      expect(UserRole.juniorWing.isSuperAdmin, false);
    });

    test('isCoreCommittee matches hierarchy specs', () {
      expect(UserRole.superAdmin.isCoreCommittee, true);
      expect(UserRole.studentPresident.isCoreCommittee, true);
      expect(UserRole.databaseManager.isCoreCommittee, true);
      expect(UserRole.eventManager.isCoreCommittee, false);
      expect(UserRole.juniorWing.isCoreCommittee, false);
    });

    test('canEditPoints only for superAdmin', () {
      expect(UserRole.superAdmin.canEditPoints, true);
      expect(UserRole.studentPresident.canEditPoints, false);
    });

    test('canManageMembers only for superAdmin', () {
      expect(UserRole.superAdmin.canManageMembers, true);
      expect(UserRole.studentPresident.canManageMembers, false);
    });

    test('canRegisterParticipants returns correct values', () {
      expect(UserRole.superAdmin.canRegisterParticipants, true);
      expect(UserRole.studentPresident.canRegisterParticipants, true);
      expect(UserRole.eventManager.canRegisterParticipants, true);
      expect(UserRole.assistantCoordinator.canRegisterParticipants, true);
      expect(UserRole.juniorWing.canRegisterParticipants, false);
    });

    test('canManualEntry returns correct values', () {
      expect(UserRole.superAdmin.canManualEntry, true);
      expect(UserRole.studentPresident.canManualEntry, true);
      expect(UserRole.databaseManager.canManualEntry, true);
      expect(UserRole.eventManager.canManualEntry, false);
    });

    test('canResetDatabase is true for superAdmin and president', () {
      expect(UserRole.superAdmin.canResetDatabase, true);
      expect(UserRole.studentPresident.canResetDatabase, true);
      expect(UserRole.studentVicePresident.canResetDatabase, false);
      expect(UserRole.databaseManager.canResetDatabase, false);
    });
  });

  group('MemberStatus', () {
    test('fromString returns correct values', () {
      expect(MemberStatus.fromString('active'), MemberStatus.active);
      expect(MemberStatus.fromString('suspended'), MemberStatus.suspended);
      expect(MemberStatus.fromString('inactive'), MemberStatus.inactive);
    });
  });

  group('EventCategory', () {
    test('fromString returns correct category', () {
      expect(EventCategory.fromString('balwaan'), EventCategory.balwaan);
      expect(EventCategory.fromString('buddhimaan'), EventCategory.buddhimaan);
      expect(EventCategory.fromString('darpan'), EventCategory.darpan);
      expect(EventCategory.fromString('kalakruthi'), EventCategory.kalakruthi);
    });
  });

  group('EventStatus', () {
    test('fromString returns correct status', () {
      expect(EventStatus.fromString('draft'), EventStatus.draft);
      expect(EventStatus.fromString('ongoing'), EventStatus.ongoing);
      expect(EventStatus.fromString('results_published'), EventStatus.resultsPublished);
    });
  });

  group('ResultPosition', () {
    test('points are correct', () {
      expect(ResultPosition.winner.points, 10);
      expect(ResultPosition.runnerUp.points, 7);
      expect(ResultPosition.secondRunnerUp.points, 5);
    });
  });

  group('AppUtils', () {
    test('isValidEmail validates correctly', () {
      expect(AppUtils.isValidEmail('test@example.com'), true);
      expect(AppUtils.isValidEmail('invalid'), false);
    });

    test('isValidPhone validates correctly', () {
      expect(AppUtils.isValidPhone('9876543210'), true);
      expect(AppUtils.isValidPhone('123'), false);
    });

    test('getInitials returns correct initials', () {
      expect(AppUtils.getInitials('John Doe'), 'JD');
      expect(AppUtils.getInitials('John'), 'J');
    });

    test('truncate works correctly', () {
      expect(AppUtils.truncate('Hello World', 5), 'Hello...');
      expect(AppUtils.truncate('Hi', 10), 'Hi');
    });

    test('formatDate formats correctly', () {
      final date = DateTime(2026, 7, 15);
      expect(AppUtils.formatDate(date), '15 Jul 2026');
    });
  });

  group('Models', () {
    test('Student fromJson parses correctly', () {
      final json = {
        'id': 'test-id',
        'usn': '1MS21CS001',
        'name': 'John Doe',
        'branch': 'CSE',
        'year': 2,
        'section': 'A',
        'phone': '9876543210',
        'email': 'john@test.com',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final student = Student.fromJson(json);
      expect(student.usn, '1MS21CS001');
      expect(student.name, 'John Doe');
      expect(student.branch, 'CSE');
      expect(student.year, 2);
      expect(student.status, StudentStatus.active);
    });

    test('Event fromJson parses correctly', () {
      final json = {
        'id': 'event-id',
        'name': 'Quiz',
        'category': 'buddhimaan',
        'status': 'registration_open',
        'created_by': 'user-id',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final event = Event.fromJson(json);
      expect(event.name, 'Quiz');
      expect(event.category, EventCategory.buddhimaan);
      expect(event.status, EventStatus.registrationOpen);
    });

    test('Profile fromJson parses correctly', () {
      final json = {
        'id': 'user-id',
        'email': 'test@test.com',
        'full_name': 'Test User',
        'role': 'event_director',
        'is_active': true,
        'date_of_birth': '1998-05-15',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final profile = Profile.fromJson(json);
      expect(profile.fullName, 'Test User');
      expect(profile.role, UserRole.eventDirector);
      expect(profile.isActive, true);
      expect(profile.dateOfBirth?.year, 1998);
      expect(profile.dateOfBirth?.month, 5);
      expect(profile.dateOfBirth?.day, 15);
    });

    test('ClubMember fromJson parses correctly', () {
      final json = {
        'id': 'member-id',
        'user_id': 'user-id',
        'role': 'database_manager',
        'status': 'active',
        'assigned_by': 'admin-id',
        'assigned_at': '2026-01-01T00:00:00Z',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'profiles': {
          'full_name': 'Database Officer',
          'email': 'db@litops.com',
          'phone': '1234567890'
        }
      };
      final member = ClubMember.fromJson(json);
      expect(member.role, UserRole.databaseManager);
      expect(member.status, MemberStatus.active);
      expect(member.memberName, 'Database Officer');
      expect(member.memberEmail, 'db@litops.com');
    });

    test('YearlyArchive fromJson parses correctly', () {
      final json = {
        'id': 'archive-id',
        'fest_year': 2025,
        'fest_name': 'Malnad Fest 2025',
        'total_events': 15,
        'total_registrations': 300,
        'total_participants': 280,
        'total_attendance': 250,
        'is_active': false,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final archive = YearlyArchive.fromJson(json);
      expect(archive.festYear, 2025);
      expect(archive.totalEvents, 15);
      expect(archive.totalRegistrations, 300);
      expect(archive.isActive, false);
    });

    test('EventPoint fromJson parses correctly', () {
      final json = {
        'id': 'point-id',
        'event_id': 'event-id',
        'branch': 'CSE',
        'points': 10,
        'reason': 'Winner of Quiz',
        'position': 'winner',
        'allocated_by': 'admin-id',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };
      final point = EventPoint.fromJson(json);
      expect(point.branch, 'CSE');
      expect(point.points, 10);
      expect(point.position, ResultPosition.winner);
    });
  });
}

