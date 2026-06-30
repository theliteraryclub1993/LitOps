import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:litops/features/auth/screens/login_screen.dart';
import 'package:litops/features/auth/providers/auth_provider.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> {
  FakeAuthNotifier() : super(const AuthState());
}

void main() {
  testWidgets('LoginScreen renders correctly without layout crashes', (WidgetTester tester) async {
    // Build the login screen overriding authStateProvider to avoid calling Supabase
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => FakeAuthNotifier()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify that the login screen and basic text elements are present
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to run the fest'), findsOneWidget);
  });
}
