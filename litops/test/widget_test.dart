import 'package:flutter_test/flutter_test.dart';
import 'package:litops/core/enums/enums.dart';
import 'package:litops/core/utils/app_utils.dart';

void main() {
  group('UserRole', () {
    test('fromString returns correct role', () {
      expect(UserRole.fromString('student_president'), UserRole.studentPresident);
      expect(UserRole.fromString('junior_wing'), UserRole.juniorWing);
      expect(UserRole.fromString('unknown'), UserRole.juniorWing);
    });

    test('isAdmin returns true for admin roles', () {
      expect(UserRole.studentPresident.isAdmin, true);
      expect(UserRole.studentVicePresident.isAdmin, true);
      expect(UserRole.jointSecretary.isAdmin, true);
      expect(UserRole.eventDirector.isAdmin, true);
      expect(UserRole.juniorWing.isAdmin, false);
    });

    test('canRegisterParticipants returns correct values', () {
      expect(UserRole.studentPresident.canRegisterParticipants, true);
      expect(UserRole.eventManager.canRegisterParticipants, true);
      expect(UserRole.juniorWing.canRegisterParticipants, false);
    });
  });

  group('AppUtils', () {
    test('isValidEmail validates correctly', () {
      expect(AppUtils.isValidEmail('test@example.com'), true);
      expect(AppUtils.isValidEmail('invalid'), false);
    });

    test('isValidUSN validates correctly', () {
      expect(AppUtils.isValidUSN('1MC21CS001'), true);
      expect(AppUtils.isValidUSN('AB'), false);
    });

    test('formatDate returns formatted string', () {
      final date = DateTime(2024, 1, 15);
      expect(AppUtils.formatDate(date), '15 Jan 2024');
    });

    test('extractUsnFromScan removes ]C1 prefix', () {
      expect(AppUtils.extractUsnFromScan(']C14MC22IS100'), '4MC22IS100');
      expect(AppUtils.extractUsnFromScan(']c14MC22IS100'), '4MC22IS100');
      expect(AppUtils.extractUsnFromScan('4MC22IS100'), '4MC22IS100');
    });
  });

  group('EventCategory', () {
    test('fromString returns correct category', () {
      expect(EventCategory.fromString('balwaan'), EventCategory.balwaan);
      expect(EventCategory.fromString('unknown'), EventCategory.balwaan);
    });
  });

  group('EventStatus', () {
    test('fromString returns correct status', () {
      expect(EventStatus.fromString('draft'), EventStatus.draft);
      expect(EventStatus.fromString('ongoing'), EventStatus.ongoing);
    });
  });
}
