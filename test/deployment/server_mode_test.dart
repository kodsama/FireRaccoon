import 'package:fireraccoon/deployment/fireraccoon_mode.dart';
import 'package:fireraccoon/providers/people_providers.dart';
import 'package:fireraccoon/providers/server_session_provider.dart';
import 'package:fireraccoon/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'resolveFireraccoonMode prefers config.json over dart-define default',
    () {
      expect(resolveFireraccoonMode(), FireraccoonMode.local);
      expect(
        resolveFireraccoonMode(configJson: {'FIRERACCOON_MODE': 'server'}),
        FireraccoonMode.server,
      );
      expect(
        resolveFireraccoonMode(configJson: {'mode': 'local'}),
        FireraccoonMode.local,
      );
    },
  );

  test('resolveServerRedirect sends locked existing store to unlock', () {
    const session = AsyncData(
      ServerSession(
        token: '',
        proxyBase: '/api/firefly',
        storeLocked: true,
        storeExists: true,
        setupRequired: true,
      ),
    );
    expect(
      resolveServerRedirect(session: session, matchedLocation: '/'),
      '/unlock',
    );
  });

  test('resolveServerRedirect sends empty locked store to unlock (create)', () {
    const session = AsyncData(
      ServerSession(
        token: '',
        proxyBase: '/api/firefly',
        storeLocked: true,
        storeExists: false,
        setupRequired: true,
      ),
    );
    expect(
      resolveServerRedirect(session: session, matchedLocation: '/login'),
      '/unlock',
    );
  });

  test('resolveServerRedirect sends first boot to setup', () {
    const session = AsyncData(
      ServerSession(
        token: '',
        proxyBase: '/api/firefly',
        setupRequired: true,
        storeLocked: false,
        storeExists: true,
      ),
    );
    expect(
      resolveServerRedirect(session: session, matchedLocation: '/'),
      '/setup',
    );
    expect(
      resolveServerRedirect(session: session, matchedLocation: '/setup'),
      isNull,
    );
  });

  test('resolveServerRedirect sends unauthenticated users to login', () {
    const session = AsyncData<ServerSession?>(null);
    expect(
      resolveServerRedirect(session: session, matchedLocation: '/'),
      '/login',
    );
  });

  test('resolveServerRedirect covers unlock setup login and auth bounce', () {
    expect(
      resolveServerRedirect(
        session: const AsyncLoading(),
        matchedLocation: '/',
      ),
      isNull,
    );

    const locked = AsyncData(
      ServerSession(
        token: '',
        proxyBase: '/api/firefly',
        storeLocked: true,
        storeExists: true,
      ),
    );
    expect(
      resolveServerRedirect(session: locked, matchedLocation: '/unlock'),
      isNull,
    );

    const needsSetup = AsyncData(
      ServerSession(token: '', proxyBase: '/api/firefly', setupRequired: true),
    );
    expect(
      resolveServerRedirect(session: needsSetup, matchedLocation: '/unlock'),
      '/setup',
    );

    const anon = AsyncData<ServerSession?>(null);
    expect(
      resolveServerRedirect(session: anon, matchedLocation: '/unlock'),
      '/login',
    );
    expect(
      resolveServerRedirect(session: anon, matchedLocation: '/setup'),
      '/login',
    );
    expect(
      resolveServerRedirect(session: anon, matchedLocation: '/login'),
      isNull,
    );

    const authed = AsyncData(
      ServerSession(
        token: 't',
        proxyBase: '/api/firefly',
        person: {'id': '1', 'name': 'A'},
      ),
    );
    expect(
      resolveServerRedirect(session: authed, matchedLocation: '/login'),
      '/',
    );
    expect(
      resolveServerRedirect(session: authed, matchedLocation: '/'),
      isNull,
    );
  });

  test('resolveAppUsersRedirect aliases resolvePeopleRedirect', () {
    const people = PeopleState();
    expect(resolveAppUsersRedirect(people, '/login'), '/');
  });
}
