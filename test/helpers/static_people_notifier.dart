import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/providers/people_providers.dart';

/// People notifier that skips async hydration so ownership is deterministic.
///
/// The first person is treated as signed in, which is what anything reading
/// `currentPerson` needs.
class StaticPeopleNotifier extends PeopleNotifier {
  StaticPeopleNotifier(this.people, {this.isHydrated = true});

  final List<Person> people;

  /// Set false to stand in for the startup window before people have loaded.
  final bool isHydrated;

  @override
  PeopleState build() => PeopleState(
    config: AccountOwnershipConfig(people: people),
    loggedInPersonId: people.isEmpty ? null : people.first.id,
    isHydrated: isHydrated,
  );
}

Person testPerson(
  String id,
  String name, {
  PersonRole role = PersonRole.user,
}) => Person(
  id: id,
  name: name,
  colorValue: 0xFF1565C0,
  role: role,
  createdAtIso: '2026-01-01T00:00:00.000Z',
);
