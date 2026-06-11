import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'pages/landing_page.dart';
import 'pages/sign_in_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const CuraApp());
}

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const LandingPage(),
    ),
    GoRoute(
      path: '/sign-in',
      builder: (BuildContext context, GoRouterState state) =>
          const SignInPage(),
    ),
  ],
);

class CuraApp extends StatelessWidget {
  const CuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cura',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
