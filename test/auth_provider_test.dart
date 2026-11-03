import 'package:flutter_test/flutter_test.dart';

import 'package:flat_rent_manager/providers/auth_provider.dart';

void main() {
  test('rejects empty credentials before touching the network', () async {
    final auth = AuthProvider();

    expect(await auth.login('', ''), 'Username and password are required');
    expect(await auth.login('admin', ''), 'Username and password are required');
    expect(await auth.login('   ', 'secret'), 'Username and password are required');

    auth.dispose();
  });

  test('starts signed out', () {
    final auth = AuthProvider();

    expect(auth.isLoggedIn, isFalse);
    expect(auth.isAdmin, isFalse);
    expect(auth.displayName, '');

    auth.dispose();
  });
}
