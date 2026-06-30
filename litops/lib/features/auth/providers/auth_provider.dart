import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/services/notification_service.dart';
import '../repositories/auth_repository.dart';
import 'auth_settings_provider.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final Profile? profile;
  final String? error;
  final bool rememberMe;
  final bool requiresDobVerification;
  final String? pendingEmail;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.profile,
    this.error,
    this.rememberMe = false,
    this.requiresDobVerification = false,
    this.pendingEmail,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    Profile? profile,
    String? error,
    bool? rememberMe,
    bool? requiresDobVerification,
    String? pendingEmail,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      error: error,
      rememberMe: rememberMe ?? this.rememberMe,
      requiresDobVerification: requiresDobVerification ?? this.requiresDobVerification,
      pendingEmail: pendingEmail ?? this.pendingEmail,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription? _authSubscription;
  final Ref _ref;
  static const _secureStorage = FlutterSecureStorage();

  // Super Admin credentials (real Supabase account - change these later)
  static const superAdminEmail = 'theliteraryclubmce@gmail.com';
  static const _superAdminEmail = superAdminEmail;
  static const _superAdminPassword = 'Malnad2K27';

  // Demo Admin credentials (offline bypass - no Supabase needed)
  // TODO: Remove this after setting up real admin in Supabase
  static const _demoAdminEmail = 'admin@litops.com';
  static const _demoAdminPassword = 'litops123';
  static const demoAdminId = '61bff047-a01c-4cf3-98ba-694647930ccf';

  String? _loadingProfileId;

  AuthNotifier(this._authRepository, this._ref) : super(const AuthState()) {
    _initialize();
  }

  void _initialize() {
    _tryAutoLogin();

    // Listen for auth changes (wrapped in try-catch for Supabase connection issues)
    try {
      _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        // Skip if demo admin is logged in
        if (state.profile?.id == demoAdminId) return;

        if (session != null && (event == supabase.AuthChangeEvent.signedIn || event == supabase.AuthChangeEvent.initialSession || event == supabase.AuthChangeEvent.tokenRefreshed)) {
          _loadProfile(session.user.id);
        } else if (event == supabase.AuthChangeEvent.signedOut) {
          state = const AuthState();
        }
      }, onError: (_) {
        // Supabase connection error - demo admin still works
      });
    } catch (_) {
      // Supabase not available - demo admin still works
    }
  }

  Future<void> _tryAutoLogin() async {
    try {
      // Check Supabase session (automatically persisted by Supabase SDK)
      final session = SupabaseConfig.client.auth.currentSession;
      if (session != null) {
        _loadProfile(session.user.id);
      }
    } catch (_) {
      // No saved session, proceed normally
    }
  }

  Future<void> _loadProfile(String userId) async {
    if (state.profile?.id == userId || _loadingProfileId == userId) return;

    _loadingProfileId = userId;
    state = state.copyWith(isLoading: true, error: null);
    try {
      Profile profile;
      try {
        profile = await _authRepository.getProfile(userId);
      } catch (e) {
        // Profile doesn't exist yet — create it
        final user = SupabaseConfig.client.auth.currentUser;
        if (user == null) throw Exception('No user session');

        final isAdmin = user.email == _superAdminEmail;
        final fullName = user.userMetadata?['full_name'] ??
            (isAdmin ? 'Super Admin' : user.email?.split('@').first ?? 'User');
        final dobStr = user.userMetadata?['date_of_birth'] as String?;
        final roleStr = isAdmin ? 'super_admin' : 'junior_wing';

        final newProfile = <String, dynamic>{
          'id': userId,
          'email': user.email ?? '',
          'full_name': fullName,
          'role': roleStr,
        };
        if (dobStr != null) {
          newProfile['date_of_birth'] = dobStr;
        }

        try {
          // Use upsert to avoid duplicate-key errors
          await SupabaseConfig.client
              .from(SupabaseTables.profiles)
              .upsert(newProfile, onConflict: 'id');
        } catch (_) {
          // Upsert failed (e.g. RLS) — continue and try to fetch anyway
        }

        // Try fetching the profile again after upsert
        try {
          profile = await _authRepository.getProfile(userId);
        } catch (_) {
          // Still no profile row — build a local Profile so the user isn't blocked
          profile = Profile(
            id: userId,
            email: user.email ?? '',
            fullName: fullName,
            role: UserRole.fromString(roleStr),
            phone: null,
            dateOfBirth: dobStr != null ? DateTime.tryParse(dobStr) : null,
            year: null,
            photoUrl: null,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }

      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        profile: profile,
        rememberMe: state.rememberMe,
      );

      // Persist if remember me (skip on web - secure storage not available)
      if (state.rememberMe && !kIsWeb) {
        await _secureStorage.write(key: 'remember_email', value: profile.email);
        await _secureStorage.write(key: 'remember_role', value: profile.role.value);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _loadingProfileId = null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updateData) async {
    if (state.profile == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (state.profile!.id == demoAdminId) {
        final localProfile = state.profile!;
        final updatedProfile = Profile(
          id: localProfile.id,
          email: localProfile.email,
          fullName: updateData['full_name'] as String? ?? localProfile.fullName,
          role: UserRole.fromString(updateData['role'] as String?),
          phone: updateData['phone'] as String? ?? localProfile.phone,
          photoUrl: updateData['photo_url'] as String? ?? localProfile.photoUrl,
          isActive: localProfile.isActive,
          dateOfBirth: updateData['date_of_birth'] != null
              ? DateTime.tryParse(updateData['date_of_birth'] as String)
              : localProfile.dateOfBirth,
          year: updateData['year'] as int? ?? localProfile.year,
          createdAt: localProfile.createdAt,
          updatedAt: DateTime.now(),
          usn: updateData['usn'] as String? ?? localProfile.usn,
        );
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          profile: updatedProfile,
          rememberMe: state.rememberMe,
        );
        return;
      }

      await _authRepository.updateProfile(state.profile!.id, updateData);
      // Re-fetch the updated profile directly (bypasses _loadProfile dedup guard)
      final updatedProfile = await _authRepository.getProfile(state.profile!.id);
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        profile: updatedProfile,
        rememberMe: state.rememberMe,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<String> uploadProfileImage(Uint8List bytes, String userId) async {
    final fileName = '${userId}_profile.png';
    try {
      await SupabaseConfig.client.storage
          .from('profile_pictures')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const supabase.FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      final rawUrl = SupabaseConfig.client.storage
          .from('profile_pictures')
          .getPublicUrl(fileName);
      final url = '$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      return url;
    } catch (e) {
      debugPrint('[AuthNotifier] uploadProfileImage error: $e');
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    final userId = state.profile?.id ?? SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final updatedProfile = await _authRepository.getProfile(userId);
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        profile: updatedProfile,
        rememberMe: state.rememberMe,
      );
    } catch (_) {
      // Silently ignore background/refresh errors
    }
  }

  Future<void> signIn(String email, String password, {bool rememberMe = false}) async {
    state = state.copyWith(isLoading: true, error: null, rememberMe: rememberMe);

    final emailLower = email.trim().toLowerCase();
    final isSuperAdminLogin = emailLower == _superAdminEmail.toLowerCase();
    if (!isSuperAdminLogin) {
      try {
        final settings = await fetchAuthSettings();
        if (!settings.signInEnabled) {
          state = state.copyWith(
            isLoading: false,
            error: settings.signInDisabledMessage,
          );
          return;
        }
      } catch (_) {
        // Fail-open if settings table is unavailable
      }
    }

    // ── DEMO ADMIN BYPASS ──────────────────────────────────────────────
    // Works without Supabase. Full Student President access.
    // Login: admin@litops.com / litops123
    // TODO: Remove this block after configuring real admin in Supabase
    if (emailLower == _demoAdminEmail.toLowerCase() && password == _demoAdminPassword) {
      await Future.delayed(const Duration(milliseconds: 500));
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        profile: Profile(
          id: demoAdminId,
          email: _demoAdminEmail,
          fullName: 'Demo Admin',
          role: UserRole.studentPresident,
          phone: '+91 9876543210',
          photoUrl: 'avatar:0',
          isActive: true,
          dateOfBirth: DateTime(2004, 1, 1),
          year: 4,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        rememberMe: rememberMe,
      );
      if (rememberMe && !kIsWeb) {
        await _secureStorage.write(key: 'remember_email', value: email);
      } else if (!rememberMe && !kIsWeb) {
        await _secureStorage.delete(key: 'remember_email');
      }
      return;
    }
    // ── END DEMO BYPASS ────────────────────────────────────────────────

    try {
      await _authRepository.signIn(email, password);
      // _loadProfile will be triggered by onAuthStateChange listener

      if (rememberMe && !kIsWeb) {
        await _secureStorage.write(key: 'remember_email', value: email);
      } else if (!rememberMe && !kIsWeb) {
        await _secureStorage.delete(key: 'remember_email');
      }
    } on supabase.AuthException catch (e) {
      // If user doesn't exist, try to sign up (for admin auto-setup)
      if (email == _superAdminEmail && password == _superAdminPassword &&
          (e.message.contains('Invalid login credentials') || e.message.contains('Email not confirmed'))) {
        try {
          await _authRepository.signUp(email, password);
          final session = SupabaseConfig.client.auth.currentSession;
          if (session == null) {
            state = state.copyWith(
              isLoading: false,
              error: 'Account created but needs email confirmation. Go to Supabase Dashboard > Authentication > Providers > Email > Turn OFF "Confirm email", then try again.',
            );
            return;
          }
          // Session exists - profile will be auto-created by _loadProfile
        } catch (signUpErr) {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to set up admin account: $signUpErr. Make sure the Supabase schema is deployed and Email Auth is enabled.',
          );
          return;
        }
      } else {
        String errorMsg = e.message;
        if (errorMsg.contains('Invalid login credentials')) {
          errorMsg = 'Invalid email or password. Check your credentials.';
        } else if (errorMsg.contains('Email not confirmed')) {
          errorMsg = 'Email not confirmed. Go to Supabase Dashboard > Auth > Users and confirm the user, or disable email confirmation.';
        }
        state = state.copyWith(isLoading: false, error: errorMsg);
        return;
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('SocketException') || errorMsg.contains('Network')) {
        errorMsg = 'Network error. Check your internet connection and Supabase project URL.';
      } else if (errorMsg.contains('404') || errorMsg.contains('not found')) {
        errorMsg = 'Supabase project not found. Verify the project URL matches your new account.';
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
    }

  }

  Future<bool> verifyDateOfBirth(DateTime dob) async {
    if (state.profile == null) return false;

    try {
      final profileDob = state.profile!.dateOfBirth;
      if (profileDob == null) {
        // No DOB set, skip verification
        return true;
      }

      return profileDob.year == dob.year &&
          profileDob.month == dob.month &&
          profileDob.day == dob.day;
    } catch (e) {
      state = state.copyWith(error: 'DOB verification failed: $e');
      return false;
    }
  }

  Future<bool> preAuthVerifyDob(String email, DateTime dob) async {
    return _authRepository.preAuthVerifyDob(email, dob);
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.resetPasswordForEmail(email);
      state = state.copyWith(
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send reset email: $e',
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final settings = await fetchAuthSettings();
      if (!settings.registrationEnabled) {
        state = state.copyWith(
          isLoading: false,
          error: 'New account registration is currently closed. Please contact the club admin.',
        );
        return;
      }

      await _authRepository.signUp(email, password);

      // Registration successful — signal the UI
      state = const AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: 'REGISTRATION_SUCCESS',
      );
    } on supabase.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    // Only sign out from Supabase if we have a real session
    if (state.profile?.id != demoAdminId) {
      try {
        // Unregister FCM token while still authenticated
        await NotificationService().unregisterFcmToken();
      } catch (e) {
        debugPrint('[AuthNotifier] Error unregistering FCM token: $e');
      }
      try {
        await _authRepository.signOut();
      } catch (_) {}
    }
    state = const AuthState();
  }

  void setRememberMe(bool value) {
    state = state.copyWith(rememberMe: value);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = ChangeNotifierProvider((ref) => RouterNotifier(ref));

final currentProfileProvider = Provider<Profile?>((ref) {
  return ref.watch(authStateProvider).profile;
});

final currentUserRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(authStateProvider).profile?.role ?? UserRole.juniorWing;
});

final canManageEventScheduleProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return false;
  final role = profile.role;
  return role.isSuperAdmin || 
         role == UserRole.eventDirector ||
         role == UserRole.eventManager ||
         role == UserRole.eventManagerCoEditorial ||
         profile.year == 4;
});
