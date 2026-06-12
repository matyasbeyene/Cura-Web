import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_widgets.dart';

/// Business analytics dashboard. Requires a signed-in user who owns a business.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AnalyticsService _svc = AnalyticsService();

  bool _loadingBiz = true;
  String? _bizError;
  List<OwnedBusiness> _businesses = const <OwnedBusiness>[];
  OwnedBusiness? _selected;

  DatePreset _preset = DatePreset.thirtyDays;
  TrendMetric _trendMetric = TrendMetric.sessions;
  Future<DashboardBundle>? _bundleFuture;

  bool get _signedIn => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    if (_signedIn) _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _loadingBiz = true;
      _bizError = null;
    });
    try {
      final biz = await _svc.fetchMyBusinesses();
      if (!mounted) return;
      setState(() {
        _businesses = biz;
        _selected = biz.isNotEmpty ? biz.first : null;
        _loadingBiz = false;
      });
      if (_selected != null) _loadBundle();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBiz = false;
        _bizError = e.toString();
      });
    }
  }

  void _loadBundle() {
    final business = _selected;
    if (business == null) return;
    setState(() {
      _bundleFuture = _svc.fetchBundle(businessId: business.id, preset: _preset);
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/');
  }

  double? _delta(DashboardBundle b, num Function(DashboardTotals) pick) {
    final prev = b.previous;
    if (prev == null) return null;
    final p = pick(prev.totals);
    if (p <= 0) return null;
    return (pick(b.current.totals) - p) / p * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(onSignOut: _signedIn ? _signOut : null),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (!_signedIn) {
      return _Centered(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to view your dashboard',
        body: 'The business portal is for Cura partner businesses.',
        actionLabel: 'Sign in',
        onAction: () => context.push('/sign-in'),
      );
    }
    if (_loadingBiz) return const _LoadingState();
    if (_bizError != null) {
      return _Centered(
        icon: Icons.error_outline_rounded,
        title: 'Couldn\'t load your dashboard',
        body: _bizError!,
        actionLabel: 'Try again',
        onAction: _loadBusinesses,
      );
    }
    if (_businesses.isEmpty) {
      return _Centered(
        icon: Icons.storefront_outlined,
        title: 'No business on this account',
        body:
            'This portal shows analytics for Cura partner businesses. The account you signed in with doesn\'t own one yet.',
        actionLabel: 'Back to home',
        onAction: () => context.go('/'),
      );
    }
    return _dashboard();
  }

  Widget _dashboard() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
            child: FutureBuilder<DashboardBundle>(
              future: _bundleFuture,
              builder: (context, snap) {
                final header = _header(snap.data);
                if (snap.connectionState == ConnectionState.waiting) {
                  return Column(children: <Widget>[header, const SizedBox(height: 24), const _LoadingState(compact: true)]);
                }
                if (snap.hasError) {
                  return Column(children: <Widget>[
                    header,
                    const SizedBox(height: 24),
                    _Centered(
                      icon: Icons.error_outline_rounded,
                      title: 'Couldn\'t load analytics',
                      body: snap.error.toString(),
                      actionLabel: 'Retry',
                      onAction: _loadBundle,
                      embedded: true,
                    ),
                  ]);
                }
                final bundle = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 24),
                    ..._sections(bundle),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(DashboardBundle? bundle) {
    final business = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  business.name.isEmpty ? 'Your business' : business.name,
                  style: GoogleFonts.fraunces(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    color: AppColors.warmBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  business.category.isEmpty
                      ? 'Business analytics'
                      : business.category,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.mocha),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            _Segmented<DatePreset>(
              value: _preset,
              options: const <(String, DatePreset)>[
                ('7 days', DatePreset.sevenDays),
                ('30 days', DatePreset.thirtyDays),
                ('90 days', DatePreset.ninetyDays),
              ],
              onChanged: (p) {
                setState(() => _preset = p);
                _loadBundle();
              },
            ),
            const Spacer(),
            if (bundle != null)
              Text(
                'Updated ${_timeAgo(bundle.current.generatedAt)}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.mocha),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _sections(DashboardBundle bundle) {
    final t = bundle.current.totals;
    final data = bundle.current;
    return <Widget>[
      // KPI grid
      _grid(
        minWidth: 220,
        children: <Widget>[
          KpiCard(
            label: 'Unique students',
            value: compactInt(t.uniqueStudents),
            icon: Icons.groups_outlined,
            deltaPct: _delta(bundle, (x) => x.uniqueStudents),
          ),
          KpiCard(
            label: 'Study sessions',
            value: compactInt(t.sessions),
            icon: Icons.event_available_outlined,
            deltaPct: _delta(bundle, (x) => x.sessions),
          ),
          KpiCard(
            label: 'Returning rate',
            value: '${(t.returnRate * 100).round()}%',
            icon: Icons.replay_rounded,
            caption: 'came back again',
            deltaPct: _delta(bundle, (x) => x.returnRate),
          ),
          KpiCard(
            label: 'Avg. session',
            value: '${t.averageMinutes.round()}m',
            icon: Icons.timer_outlined,
            deltaPct: _delta(bundle, (x) => x.averageMinutes),
          ),
          KpiCard(
            label: 'Focus hours',
            value: compactInt(t.focusHours),
            icon: Icons.schedule_outlined,
            deltaPct: _delta(bundle, (x) => x.focusMinutes),
          ),
          KpiCard(
            label: 'Studying now',
            value: compactInt(t.activeNow),
            icon: Icons.bolt_outlined,
            caption: 'active sessions',
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Trend
      DashboardCard(
        title: 'Visits over time',
        subtitle: 'Last ${_preset.days} days',
        trailing: _Segmented<TrendMetric>(
          value: _trendMetric,
          compact: true,
          options: const <(String, TrendMetric)>[
            ('Sessions', TrendMetric.sessions),
            ('Students', TrendMetric.students),
            ('Minutes', TrendMetric.minutes),
          ],
          onChanged: (m) => setState(() => _trendMetric = m),
        ),
        child: TrendChart(trend: data.trend, metric: _trendMetric),
      ),
      const SizedBox(height: 16),

      // Peak hours + session length
      _grid(
        minWidth: 340,
        children: <Widget>[
          DashboardCard(
            title: 'When students study',
            subtitle: 'Busier cells = more sessions',
            child: PeakHoursHeatmap(cells: data.hourly),
          ),
          DashboardCard(
            title: 'Session length',
            subtitle: 'How long visits last',
            child: BreakdownList(
              items: data.durationBuckets,
              privacyThreshold: data.privacyThreshold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Demographics
      Text(
        'Who studies here',
        style: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.warmBlack,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Aggregated and privacy-safe — small groups are hidden.',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.mocha),
      ),
      const SizedBox(height: 14),
      _grid(
        minWidth: 320,
        children: <Widget>[
          DashboardCard(
            title: 'Level of study',
            child: BreakdownList(
                items: data.level, privacyThreshold: data.privacyThreshold),
          ),
          DashboardCard(
            title: 'Year',
            child: BreakdownList(
                items: data.year, privacyThreshold: data.privacyThreshold),
          ),
          DashboardCard(
            title: 'Top majors',
            child: BreakdownList(
                items: data.major, privacyThreshold: data.privacyThreshold),
          ),
          DashboardCard(
            title: 'Gender',
            child: BreakdownList(
                items: data.gender, privacyThreshold: data.privacyThreshold),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Deals
      if (data.deals.isNotEmpty) ...<Widget>[
        Text(
          'Reward performance',
          style: GoogleFonts.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.warmBlack,
          ),
        ),
        const SizedBox(height: 14),
        _grid(
          minWidth: 300,
          children: <Widget>[
            for (final deal in data.deals) DealCard(deal: deal),
          ],
        ),
        const SizedBox(height: 16),
      ],

      // Insights
      if (data.insights.isNotEmpty) ...<Widget>[
        Text(
          'Insights',
          style: GoogleFonts.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.warmBlack,
          ),
        ),
        const SizedBox(height: 14),
        for (final insight in data.insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InsightCard(insight: insight),
          ),
      ],
    ];
  }

  /// Responsive wrap: items flow into as many columns as fit [minWidth].
  Widget _grid({required List<Widget> children, required double minWidth, double gap = 16}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        int cols = (maxW / minWidth).floor().clamp(1, children.isEmpty ? 1 : children.length);
        if (cols < 1) cols = 1;
        final double itemW = (maxW - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final child in children) SizedBox(width: itemW, child: child),
          ],
        );
      },
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onSignOut});
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border(
          bottom: BorderSide(color: AppColors.espresso.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: <Widget>[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.go('/'),
              child: Row(
                children: <Widget>[
                  Text(
                    'Cura',
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.espresso,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Business',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (onSignOut != null)
            TextButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Sign out'),
              style: TextButton.styleFrom(foregroundColor: AppColors.mocha),
            ),
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  final T value;
  final List<(String, T)> options;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.espresso.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (label, val) in options)
            GestureDetector(
              onTap: () => onChanged(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16, vertical: compact ? 7 : 9),
                decoration: BoxDecoration(
                  color: val == value ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: val == value
                      ? <BoxShadow>[
                          BoxShadow(
                            color: AppColors.espresso.withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.w600,
                    color:
                        val == value ? AppColors.espresso : AppColors.mocha,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.embedded = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.forestDark, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.warmBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14.5, height: 1.55, color: AppColors.mocha),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.cream,
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionLabel,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (embedded) return Padding(padding: const EdgeInsets.all(40), child: content);
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: content));
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            for (int i = 0; i < 6; i++)
              const SizedBox(width: 220, height: 130, child: SkeletonBox(height: 130)),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonBox(height: 280),
      ],
    );
    if (compact) return body;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(padding: const EdgeInsets.all(24), child: body),
      ),
    );
  }
}
