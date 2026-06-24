import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

enum SiteAudience { student, business }

/// Sticky top navigation. Transparent over the hero, fading into a solid cream
/// bar as you scroll ([scrolled] 0 -> 1). Text stays dark (the hero border and
/// the content sections are both light).
class TopNav extends StatelessWidget {
  const TopNav({
    super.key,
    required this.scrolled,
    required this.audience,
    required this.onAudienceChanged,
    this.onDashboard,
  });

  final double scrolled;
  final SiteAudience audience;
  final ValueChanged<SiteAudience> onAudienceChanged;
  final VoidCallback? onDashboard;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double t = scrolled.clamp(0.0, 1.0);
    final Color barColor = AppColors.cream.withValues(alpha: 0.94 * t);
    const Color fg = AppColors.espresso;
    final bool wide = width >= 760;
    final bool compact = width < 390;
    final bool businessView = audience == SiteAudience.business;
    final bool showNavBadge = !compact && (!businessView || width >= 650);

    return Container(
      color: barColor,
      padding: EdgeInsets.fromLTRB(wide ? 40 : 18, 0, wide ? 24 : 12, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: <Widget>[
              Text(
                'Cura',
                style: GoogleFonts.fraunces(
                  fontSize: wide ? 28 : 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: fg,
                ),
              ),
              if (showNavBadge) ...<Widget>[
                SizedBox(width: wide ? 18 : 12),
                AppStoreBadge(compact: !wide),
              ],
              const Spacer(),
              if (businessView) ...<Widget>[
                _AudienceButton(
                  label: compact ? 'Students' : 'For Students',
                  icon: Icons.school_rounded,
                  onTap: () => onAudienceChanged(SiteAudience.student),
                  compact: compact,
                ),
                SizedBox(width: compact ? 8 : 10),
                _DashboardButton(onTap: onDashboard, compact: compact),
              ] else
                _BusinessButton(
                  label: compact ? 'Businesses' : 'For Businesses',
                  onTap: () => onAudienceChanged(SiteAudience.business),
                  compact: compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessButton extends StatelessWidget {
  const _BusinessButton({
    required this.label,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.espresso,
        foregroundColor: AppColors.cream,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: AppColors.latte.withValues(alpha: 0.55)),
      ),
      icon: Icon(Icons.storefront_rounded, size: compact ? 16 : 18),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AudienceButton extends StatelessWidget {
  const _AudienceButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.espresso,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: AppColors.espresso.withValues(alpha: 0.24)),
        backgroundColor: AppColors.cream.withValues(alpha: 0.72),
      ),
      icon: Icon(icon, size: compact ? 16 : 18),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({this.onTap, required this.compact});

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap ?? () {},
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.espresso,
        foregroundColor: AppColors.cream,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: AppColors.latte.withValues(alpha: 0.55)),
      ),
      icon: Icon(Icons.dashboard_rounded, size: compact ? 16 : 18),
      label: Text(
        'Dashboard',
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A re-creation of Apple's "Download on the App Store" badge. Recognizable and
/// functional; for production, swap in Apple's official downloadable badge
/// asset (their guidelines require the official artwork).
class AppStoreBadge extends StatelessWidget {
  const AppStoreBadge({super.key, this.onTap, this.compact = false});

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double height = compact ? 40 : 46;
    final double iconSize = compact ? 24 : 28;
    final double labelSize = compact ? 8 : 9;
    final double titleSize = compact ? 15 : 18;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(compact ? 8 : 9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.apple, color: Colors.white, size: iconSize),
              SizedBox(width: compact ? 7 : 9),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Download on the',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: labelSize,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    'App Store',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: titleSize,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
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

class ContactButton extends StatelessWidget {
  const ContactButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap ?? () {},
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.espresso,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: AppColors.latte.withValues(alpha: 0.55)),
      ),
      icon: const Icon(Icons.mail_rounded, size: 18),
      label: Text(
        'Contact Us',
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
