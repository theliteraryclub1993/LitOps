import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/events/screens/events_screen.dart';
import '../../features/events/screens/event_detail_screen.dart';
import '../../features/events/screens/create_event_screen.dart';
import '../../features/students/screens/student_list_screen.dart';
import '../../features/students/screens/student_detail_screen.dart';
import '../../features/students/screens/add_student_screen.dart';
import '../../features/students/screens/import_students_screen.dart';
import '../../features/students/screens/database_management_screen.dart';
import '../../features/registration/screens/registration_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/attendance/screens/attendance_scan_screen.dart';
import '../../features/assignments/screens/assignment_screen.dart';
import '../../features/command_center/screens/command_center_screen.dart';
import '../../features/results/screens/results_screen.dart';
import '../../features/results/screens/score_entry_screen.dart';
import '../../features/rounds/screens/rounds_screen.dart';
import '../../features/certificates/screens/certificates_screen.dart';
import '../../features/certificates/screens/verify_certificate_screen.dart';
import '../../features/feedback/screens/feedback_screen.dart';
import '../../features/reports/screens/report_screen.dart';
import '../../features/appeals/screens/appeals_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/sarvottam/screens/leaderboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/profile_setup_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/waiting_list/screens/waiting_list_screen.dart';
import '../../features/events/screens/registered_participants_screen.dart';
import '../../features/shell/screens/app_shell.dart';

// Enterprise Extension Screens
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/member_management_screen.dart';
import '../../features/admin/screens/points_management_screen.dart';
import '../../features/admin/screens/yearly_database_screen.dart';
import '../../features/admin/screens/historical_import_screen.dart';
import '../../features/admin/screens/audit_dashboard_screen.dart';
import '../../features/search/screens/global_search_screen.dart';
import '../../features/scheduling/screens/event_scheduling_screen.dart';
import '../../core/enums/enums.dart';

bool debugBypassIncompleteCheck = false;

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Page Not Found', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(state.error?.message ?? 'Unknown route', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      final currentAuth = ref.read(authStateProvider);
      final location = state.matchedLocation;
      final isLoggedIn = currentAuth.isAuthenticated;
      final isLoading = currentAuth.isLoading;

      // Prevent eager redirects while profile is still loading asynchronously
      if (isLoading && location != '/splash') {
        // Let the current page stay or show a loading indicator without forcing redirect
        return null; 
      }

      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isRegister = location == '/register';
      final isForgotPassword = location == '/forgot-password';
      final isVerifyCert = location.startsWith('/verify');

      if (isVerifyCert) return null;

      // Root redirect
      if (location == '/') {
        return isLoggedIn ? '/dashboard' : '/login';
      }

      if (!isLoggedIn) {
        if (isLogin || isRegister || isForgotPassword || isSplash) return null;
        return '/login';
      }

      if (isSplash) return '/dashboard';

      // Check if profile is incomplete (exclude demo admin and super admin bypass)
      final profile = currentAuth.profile;
      if (profile != null &&
          profile.id != AuthNotifier.demoAdminId &&
          !profile.role.isSuperAdmin &&
          profile.email != 'theliteraryclubmce@gmail.com' &&
          !debugBypassIncompleteCheck) {
        final isProfileIncomplete = profile.dateOfBirth == null || profile.year == null;
        final isGoingToSetup = location == '/profile-setup';
        
        if (isProfileIncomplete) {
          if (!isGoingToSetup) {
            return '/profile-setup';
          }
          return null;
        } else if (isGoingToSetup) {
          return '/dashboard';
        }
      }

      if (isLogin || isRegister) return '/dashboard';

      // Enterprise Role Guards
      final userRole = currentAuth.profile?.role ?? UserRole.juniorWing;
      final isGoingToAdmin = location.startsWith('/admin');
      final isGoingToScheduling = location.startsWith('/scheduling');
      final isGoingToCreateEvent = location == '/events/create';
      final isGoingToAppeals = location.startsWith('/appeals');
      final isGoingToScoreEntry = location.startsWith('/results/score');

      if (isGoingToAdmin && !userRole.isSuperAdmin) {
        return '/dashboard';
      }

      if (isGoingToAppeals && !userRole.canViewAppeals) {
        return '/dashboard';
      }

      if (isGoingToScheduling && !userRole.canManageEventSchedule && profile?.year != 4) {
        return '/dashboard';
      }

      if (isGoingToCreateEvent && !userRole.canCreateEvents) {
        return '/dashboard';
      }

      if (isGoingToScoreEntry && !userRole.canManageResults) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify/:qrCode',
        builder: (context, state) => VerifyCertificateScreen(
          qrCode: state.pathParameters['qrCode']!,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (context, state) => const EventsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => CreateEventScreen(
                  eventToEdit: state.extra as Event?,
                ),
              ),
              GoRoute(
                path: ':eventId',
                builder: (context, state) => EventDetailScreen(
                  eventId: state.pathParameters['eventId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'participants',
                    builder: (context, state) => RegisteredParticipantsScreen(
                      eventId: state.pathParameters['eventId']!,
                      event: state.extra as Event?,
                    ),
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => CreateEventScreen(
                      eventToEdit: state.extra as Event?,
                      eventId: state.pathParameters['eventId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddStudentScreen(),
              ),
              GoRoute(
                path: 'import',
                builder: (context, state) => const ImportStudentsScreen(),
              ),
              GoRoute(
                path: 'manage',
                builder: (context, state) => const DatabaseManagementScreen(),
              ),
              GoRoute(
                path: ':studentId',
                builder: (context, state) => StudentDetailScreen(
                  studentId: state.pathParameters['studentId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/registration',
            builder: (context, state) => RegistrationScreen(
              initialEvent: state.extra as Event?,
            ),
            routes: [
              GoRoute(
                path: 'scan',
                builder: (context, state) => RegistrationScreen(
                  initialEvent: state.extra as Event?,
                ),
              ),
              GoRoute(
                path: 'team',
                builder: (context, state) => RegistrationScreen(
                  initialEvent: state.extra as Event?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
            routes: [
              GoRoute(
                path: 'scan',
                builder: (context, state) => const AttendanceScanScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/assignments',
            builder: (context, state) => AssignmentScreen(
              initialEvent: state.extra as Event?,
            ),
          ),
          GoRoute(
            path: '/command-center/:eventId',
            builder: (context, state) => CommandCenterScreen(
              eventId: state.pathParameters['eventId']!,
            ),
          ),
          GoRoute(
            path: '/results',
            builder: (context, state) => const ResultsScreen(),
            routes: [
              GoRoute(
                path: 'score/:eventId',
                builder: (context, state) => ScoreEntryScreen(
                  eventId: state.pathParameters['eventId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/rounds/:eventId',
            builder: (context, state) => RoundsScreen(
              eventId: state.pathParameters['eventId']!,
            ),
          ),
          GoRoute(
            path: '/certificates',
            builder: (context, state) => const CertificatesScreen(),
          ),
          GoRoute(
            path: '/feedback',
            builder: (context, state) => const FeedbackScreen(),
          ),
          GoRoute(
            path: '/reports/:eventId',
            builder: (context, state) => ReportScreen(
              eventId: state.pathParameters['eventId']!,
            ),
          ),
          GoRoute(
            path: '/appeals',
            builder: (context, state) => const AppealsScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: '/waiting-list/:eventId',
            builder: (context, state) => WaitingListScreen(
              eventId: state.pathParameters['eventId']!,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),

          // Enterprise Extension Routes
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/members',
            builder: (context, state) => const MemberManagementScreen(),
          ),
          GoRoute(
            path: '/admin/points',
            builder: (context, state) => const PointsManagementScreen(),
          ),
          GoRoute(
            path: '/admin/yearly',
            builder: (context, state) => const YearlyDatabaseScreen(),
          ),
          GoRoute(
            path: '/admin/import',
            builder: (context, state) => const HistoricalImportScreen(),
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (context, state) => const AuditDashboardScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const GlobalSearchScreen(),
          ),
          GoRoute(
            path: '/scheduling',
            builder: (context, state) => const EventSchedulingScreen(),
          ),
        ],
      ),
    ],
  );
});

