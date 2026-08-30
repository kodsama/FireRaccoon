import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/models/people_models.dart';
import 'package:fireraccoon/providers/people_providers.dart';
import 'package:fireraccoon/router/app_router.dart';

const _fakeAdmin = Person(
  id: 'admin_1',
  name: 'alex',
  colorValue: 0xFF3B82F6,
  role: PersonRole.admin,
  passwordHash: 'hash',
  salt: 'salt',
  createdAtIso: '2026-01-01T00:00:00.000',
);

void main() {
  group('resolvePeopleRedirect', () {
    test('does not redirect when people are disabled', () {
      const state = PeopleState();
      expect(resolvePeopleRedirect(state, '/'), isNull);
      expect(resolvePeopleRedirect(state, '/transactions'), isNull);
    });

    test('bounces away from /login when people are disabled', () {
      const state = PeopleState();
      expect(resolvePeopleRedirect(state, '/login'), '/');
    });

    test('sends unauthenticated visitors to /login once enabled', () {
      const state = PeopleState(
        config: AccountOwnershipConfig(people: [_fakeAdmin]),
      );
      expect(resolvePeopleRedirect(state, '/'), '/login');
      expect(resolvePeopleRedirect(state, '/transactions'), '/login');
    });

    test('lets an unauthenticated visitor stay on /login', () {
      const state = PeopleState(
        config: AccountOwnershipConfig(people: [_fakeAdmin]),
      );
      expect(resolvePeopleRedirect(state, '/login'), isNull);
    });

    test('bounces a signed-in person away from /login', () {
      const state = PeopleState(
        config: AccountOwnershipConfig(people: [_fakeAdmin]),
        loggedInPersonId: 'admin_1',
      );
      expect(resolvePeopleRedirect(state, '/login'), '/');
    });

    test('does not redirect a signed-in person elsewhere', () {
      const state = PeopleState(
        config: AccountOwnershipConfig(people: [_fakeAdmin]),
        loggedInPersonId: 'admin_1',
      );
      expect(resolvePeopleRedirect(state, '/settings'), isNull);
    });
  });
}
