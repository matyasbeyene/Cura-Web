import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Sticky top navigation. Transparent over the hero, fading into a solid cream
/// bar as you scroll ([scrolled] 0 -> 1). Text stays dark (the hero border and
/// the content sections are both light).
class TopNav extends StatelessWidget {
  const TopNav({
    super.key,
    required this.scrolled,
    this.onSignIn,
    this.onGetApp,
    this.onDashboard,
  });

  final double scrolled;
  final VoidCallback? onSignIn;
  final VoidCallback? onGetApp;
  final VoidCallback? onDashboard;

  @override
  Widget build(BuildContext context) {
    final double t = scrolled.clamp(0.0, 1.0);
    final Color barColor = AppColors.cream.withValues(alpha: 0.94 * t);
    const Color fg = AppColors.espresso;
    final bool wide = MediaQuery.of(context).size.width >= 760;

    return Container(
      color: barColor,
      padding: EdgeInsets.fromLTRB(wide ? 40 : 18, 0, wide ? 24 : 12, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: <Widget>[
              // Wordmark: the Cura logo. Drop a transparent PNG at
              // web/media/logo.png; until then it falls back to "Cura" text.
              Image.network(
                Uri.base.resolve('media/logo.png').toString(),
                height: 40,
                filterQuality: FilterQuality.high,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                  return Text(
                    'Cura',
                    style: GoogleFonts.fraunces(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: fg,
                    ),
                  );
                },
              ),
              const Spacer(),
              if (wide) ...<Widget>[
                _NavLink(label: 'Home', color: fg),
                _NavLink(label: 'Features', color: fg),
                _NavLink(label: 'Dashboard', color: fg, onTap: onDashboard),
                const SizedBox(width: 16),
              ],
              // Sign in now uses the forest-green color the CTA used to have.
              _SolidButton(label: 'Sign in', onTap: onSignIn),
              const SizedBox(width: 12),
              // Get the app is the App Store badge.
              AppStoreBadge(onTap: onGetApp),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  const _SolidButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap ?? () {},
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A re-creation of Apple's "Download on the App Store" badge. Recognizable and
/// functional; for production, swap in Apple's official downloadable badge
/// asset (their guidelines require the official artwork).
class AppStoreBadge extends StatelessWidget {
  const AppStoreBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.apple, color: Colors.white, size: 28),
              const SizedBox(width: 9),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Download on the',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    'App Store',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
