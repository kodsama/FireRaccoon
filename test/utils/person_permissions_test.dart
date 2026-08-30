import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/models/people_models.dart';
import 'package:fireraccoon/utils/person_permissions.dart';

void main() {
  group('when people are disabled (bootstrap state)', () {
    test('everything is allowed regardless of role', () {
      expect(canWriteFinancialData(peopleEnabled: false), isTrue);
      expect(canManagePeople(peopleEnabled: false), isTrue);
      expect(canManageFireflyConnection(peopleEnabled: false), isTrue);
      expect(
        canWriteFinancialData(peopleEnabled: false, role: PersonRole.viewer),
        isTrue,
      );
    });
  });

  group('when people exist and nobody is signed in', () {
    test('everything is denied', () {
      expect(canWriteFinancialData(peopleEnabled: true), isFalse);
      expect(canManagePeople(peopleEnabled: true), isFalse);
      expect(canManageFireflyConnection(peopleEnabled: true), isFalse);
    });
  });

  group('admin role', () {
    const role = PersonRole.admin;
    test('can write, manage people, and manage Firefly connection', () {
      expect(canWriteFinancialData(peopleEnabled: true, role: role), isTrue);
      expect(canManagePeople(peopleEnabled: true, role: role), isTrue);
      expect(
        canManageFireflyConnection(peopleEnabled: true, role: role),
        isTrue,
      );
    });
  });

  group('user role', () {
    const role = PersonRole.user;
    test('can write financial data', () {
      expect(canWriteFinancialData(peopleEnabled: true, role: role), isTrue);
    });

    test('cannot manage people or the Firefly connection', () {
      expect(canManagePeople(peopleEnabled: true, role: role), isFalse);
      expect(
        canManageFireflyConnection(peopleEnabled: true, role: role),
        isFalse,
      );
    });
  });

  group('viewer role', () {
    const role = PersonRole.viewer;
    test('is fully read-only', () {
      expect(canWriteFinancialData(peopleEnabled: true, role: role), isFalse);
      expect(canManagePeople(peopleEnabled: true, role: role), isFalse);
      expect(
        canManageFireflyConnection(peopleEnabled: true, role: role),
        isFalse,
      );
    });
  });
}
