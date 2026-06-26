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

  bool _loadingBusiness = true;
  String? _businessError;
  OwnedBusiness? _business;

  DatePreset _preset = DatePreset.thirtyDays;
  TrendMetric _trendMetric = TrendMetric.sessions;
  Future<DashboardBundle>? _bundleFuture;
  final Set<String> _busyOfferIds = <String>{};
  bool _creatingOffer = false;

  bool get _signedIn => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    if (_signedIn) _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    setState(() {
      _loadingBusiness = true;
      _businessError = null;
    });
    try {
      final business = await _svc.fetchMyBusiness();
      if (!mounted) return;
      setState(() {
        _business = business;
        _loadingBusiness = false;
      });
      if (_business != null) _loadBundle();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBusiness = false;
        _businessError = e.toString();
      });
    }
  }

  void _loadBundle() {
    final business = _business;
    if (business == null) return;
    setState(() {
      _bundleFuture = _svc.fetchBundle(
        businessId: business.id,
        preset: _preset,
      );
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

  String get _signInForDashboard => Uri(
    path: '/sign-in',
    queryParameters: const <String, String>{'redirect': '/dashboard'},
  ).toString();

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
        onAction: () => context.go(_signInForDashboard),
      );
    }
    if (_loadingBusiness) return const _LoadingState();
    if (_businessError != null) {
      return _Centered(
        icon: Icons.error_outline_rounded,
        title: 'Couldn\'t load your dashboard',
        body: _businessError!,
        actionLabel: 'Try again',
        onAction: _loadBusiness,
      );
    }
    if (_business == null) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 700;
        final EdgeInsets padding = EdgeInsets.fromLTRB(
          narrow ? 14 : 24,
          narrow ? 16 : 24,
          narrow ? 14 : 24,
          64,
        );
        return Scrollbar(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: padding,
                  child: FutureBuilder<DashboardBundle>(
                    future: _bundleFuture,
                    builder: (context, snap) {
                      final header = _header(snap.data);
                      if (snap.connectionState == ConnectionState.waiting) {
                        return Column(
                          children: <Widget>[
                            header,
                            const SizedBox(height: 24),
                            const _LoadingState(compact: true),
                          ],
                        );
                      }
                      if (snap.hasError) {
                        return Column(
                          children: <Widget>[
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
                          ],
                        );
                      }
                      if (!snap.hasData) {
                        return Column(
                          children: <Widget>[
                            header,
                            const SizedBox(height: 24),
                            const _LoadingState(compact: true),
                          ],
                        );
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
          ),
        );
      },
    );
  }

  Widget _header(DashboardBundle? bundle) {
    final business = _business!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 760;
        final title = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _BusinessAvatar(business: business),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    business.name.isEmpty ? 'Your business' : business.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: narrow ? 28 : 34,
                      fontWeight: FontWeight.w700,
                      height: 1.08,
                      letterSpacing: 0,
                      color: AppColors.warmBlack,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    business.category.isEmpty
                        ? 'Business analytics'
                        : business.category,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.mocha,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final controls = _HeaderControls(
          preset: _preset,
          onPresetChanged: (p) {
            setState(() => _preset = p);
            _loadBundle();
          },
          stacked: narrow,
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[title, const SizedBox(height: 16), controls],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 20),
            Flexible(
              child: Align(alignment: Alignment.topRight, child: controls),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _sections(DashboardBundle bundle) {
    final t = bundle.current.totals;
    final data = bundle.current;
    return <Widget>[
      _SnapshotCard(bundle: bundle, preset: _preset),
      const SizedBox(height: 14),
      _grid(
        minWidth: 210,
        gap: 14,
        itemHeight: 176,
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
            value: _formatHours(t.focusHours),
            icon: Icons.schedule_outlined,
            caption: '${compactInt(t.focusMinutes)} focus minutes',
            deltaPct: _delta(bundle, (x) => x.focusMinutes),
          ),
          KpiCard(
            label: 'Studying now',
            value: compactInt(t.activeNow),
            icon: Icons.bolt_outlined,
            caption: 'active sessions',
          ),
          KpiCard(
            label: 'Peak time',
            value: _peakHourText(t.peakHour),
            icon: Icons.access_time_rounded,
            caption: _peakHourCaption(t.peakHour),
          ),
        ],
      ),
      const SizedBox(height: 16),

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: TrendChart(
            key: ValueKey<TrendMetric>(_trendMetric),
            trend: data.trend,
            metric: _trendMetric,
          ),
        ),
      ),
      const SizedBox(height: 16),

      _grid(
        minWidth: 360,
        children: <Widget>[
          DashboardCard(
            title: 'When students study',
            subtitle: 'Busier cells = more sessions. Tap or hover for details.',
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
      const SizedBox(height: 22),

      _SectionHeader(
        title: 'Who studies here',
        subtitle: 'Aggregated and privacy-safe. Small groups are hidden.',
      ),
      const SizedBox(height: 14),
      _grid(
        minWidth: 310,
        children: <Widget>[
          DashboardCard(
            title: 'Level of study',
            child: BreakdownList(
              items: data.level,
              privacyThreshold: data.privacyThreshold,
            ),
          ),
          DashboardCard(
            title: 'Year',
            child: BreakdownList(
              items: data.year,
              privacyThreshold: data.privacyThreshold,
            ),
          ),
          DashboardCard(
            title: 'Top majors',
            child: BreakdownList(
              items: data.major,
              privacyThreshold: data.privacyThreshold,
            ),
          ),
          DashboardCard(
            title: 'Gender',
            child: BreakdownList(
              items: data.gender,
              privacyThreshold: data.privacyThreshold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),

      _SectionHeader(
        title: 'Reward performance',
        subtitle: 'Cura-points offers and redemptions.',
        trailing: FilledButton.icon(
          onPressed: _creatingOffer ? null : () => _editOffer(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New offer'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.espresso,
            foregroundColor: AppColors.cream,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (data.deals.isEmpty)
        const DashboardCard(
          child: DashboardEmptyState(
            icon: Icons.card_giftcard_outlined,
            message: 'No offers yet. Add a Cura-points offer.',
          ),
        )
      else
        _grid(
          minWidth: 310,
          gap: 14,
          itemHeight: 450,
          children: <Widget>[
            for (final deal in data.deals)
              DealCard(
                deal: deal,
                busy: _busyOfferIds.contains(deal.id),
                onEdit: deal.id.isEmpty ? null : () => _editOffer(deal: deal),
                onToggleActive: deal.id.isEmpty
                    ? null
                    : () => _toggleOfferActive(deal),
                onDelete: deal.id.isEmpty ? null : () => _deleteOffer(deal),
              ),
          ],
        ),
      const SizedBox(height: 22),

      _SectionHeader(
        title: 'Insights',
        subtitle: 'Plain-English takeaways from the analytics payload.',
      ),
      const SizedBox(height: 14),
      if (data.insights.isEmpty)
        const DashboardCard(
          child: DashboardEmptyState(
            icon: Icons.auto_awesome_outlined,
            message: 'No generated insights for this period yet.',
          ),
        )
      else
        _grid(
          minWidth: 360,
          children: <Widget>[
            for (final insight in data.insights) InsightCard(insight: insight),
          ],
        ),
    ];
  }

  String _formatHours(double hours) {
    if (hours >= 100) return compactInt(hours);
    if (hours % 1 == 0) return hours.toStringAsFixed(0);
    return hours.toStringAsFixed(1);
  }

  /// Responsive wrap: items flow into as many columns as fit [minWidth].
  Widget _grid({
    required List<Widget> children,
    required double minWidth,
    double gap = 16,
    double? itemHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        int cols = ((maxW + gap) / (minWidth + gap)).floor().clamp(
          1,
          children.isEmpty ? 1 : children.length,
        );
        if (cols < 1) cols = 1;
        final double itemW = (maxW - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final child in children)
              SizedBox(width: itemW, height: itemHeight, child: child),
          ],
        );
      },
    );
  }

  Future<void> _editOffer({DealPerformance? deal}) async {
    final business = _business;
    if (business == null) return;

    final result = await showDialog<_OfferFormValue>(
      context: context,
      builder: (context) => _OfferEditorDialog(deal: deal),
    );
    if (result == null) return;

    final String busyKey = deal?.id ?? '__new_offer__';
    setState(() {
      if (deal == null) _creatingOffer = true;
      _busyOfferIds.add(busyKey);
    });

    try {
      await _svc.saveOffer(
        id: deal?.id,
        businessId: business.id,
        title: result.title,
        description: result.description,
        discountKind: result.discountKind,
        discountValue: result.discountValue,
        redemptionCode: result.redemptionCode,
        startsAt: result.startsAt,
        endsAt: result.endsAt,
        isActive: result.isActive,
      );
      if (!mounted) return;
      _showDashboardMessage(deal == null ? 'Offer added.' : 'Offer updated.');
      _loadBundle();
    } catch (e) {
      if (!mounted) return;
      _showDashboardMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _creatingOffer = false;
          _busyOfferIds.remove(busyKey);
        });
      }
    }
  }

  Future<void> _toggleOfferActive(DealPerformance deal) async {
    setState(() => _busyOfferIds.add(deal.id));
    try {
      await _svc.setOfferActive(
        id: deal.id,
        businessId: deal.businessId,
        isActive: !deal.isActive,
      );
      if (!mounted) return;
      _showDashboardMessage(
        deal.isActive ? 'Offer paused.' : 'Offer activated.',
      );
      _loadBundle();
    } catch (e) {
      if (!mounted) return;
      _showDashboardMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _busyOfferIds.remove(deal.id));
      }
    }
  }

  Future<void> _deleteOffer(DealPerformance deal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete offer?'),
        content: Text(
          'This removes "${deal.title}" from your business dashboard and the student app.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9F1D18),
              foregroundColor: AppColors.white,
            ),
            child: const Text('Delete offer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyOfferIds.add(deal.id));
    try {
      await _svc.deleteOffer(id: deal.id, businessId: deal.businessId);
      if (!mounted) return;
      _showDashboardMessage('Offer deleted.');
      _loadBundle();
    } catch (e) {
      if (!mounted) return;
      _showDashboardMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _busyOfferIds.remove(deal.id));
      }
    }
  }

  void _showDashboardMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _peakHourText(String value) {
    if (_isNoClearPeak(value)) return 'no clear peak yet';
    return value;
  }

  String _peakHourCaption(String value) {
    if (_isNoClearPeak(value)) return 'more visits needed';
    return 'busiest study window';
  }

  bool _isNoClearPeak(String value) {
    return value.trim().toLowerCase().startsWith('no clear peak');
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.bundle, required this.preset});

  final DashboardBundle bundle;
  final DatePreset preset;

  @override
  Widget build(BuildContext context) {
    final totals = bundle.current.totals;
    final String hours = _formatHours(totals.focusHours);
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Dashboard snapshot',
            style: GoogleFonts.fraunces(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.warmBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cura recorded ${compactInt(totals.sessions)} '
            '${_plural(totals.sessions, 'study session')} from '
            '${compactInt(totals.uniqueStudents)} '
            '${_plural(totals.uniqueStudents, 'student')}, adding up to '
            '$hours ${_plural(totals.focusHours, 'focus hour')}.',
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.55,
              color: AppColors.mocha,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    if (hours >= 100) return compactInt(hours);
    if (hours % 1 == 0) return hours.toStringAsFixed(0);
    return hours.toStringAsFixed(1);
  }

  String _plural(num value, String singular) {
    if (value == 1) return singular;
    return '${singular}s';
  }
}

class _OfferFormValue {
  const _OfferFormValue({
    required this.title,
    required this.description,
    required this.discountKind,
    required this.discountValue,
    required this.redemptionCode,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  final String title;
  final String description;
  final String discountKind;
  final double? discountValue;
  final String redemptionCode;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
}

class _OfferEditorDialog extends StatefulWidget {
  const _OfferEditorDialog({this.deal});

  final DealPerformance? deal;

  @override
  State<_OfferEditorDialog> createState() => _OfferEditorDialogState();
}

class _OfferEditorDialogState extends State<_OfferEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _discountValue;
  late final TextEditingController _duration;
  late final TextEditingController _redemptionCode;
  late String _discountKind;
  late _RunUnit _runUnit;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final deal = widget.deal;
    final initialRunLength = _initialRunLength(deal);
    _title = TextEditingController(text: deal?.title ?? '');
    _description = TextEditingController(text: deal?.description ?? '');
    _discountKind = deal?.discountKind ?? 'dollar';
    _discountValue = TextEditingController(
      text: deal != null && deal.discountValue != null
          ? _trimNum(deal.discountValue!)
          : '',
    );
    _duration = TextEditingController(text: initialRunLength.$1.toString());
    _redemptionCode = TextEditingController(text: deal?.redemptionCode ?? '');
    _runUnit = initialRunLength.$2;
    _isActive = deal?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _discountValue.dispose();
    _duration.dispose();
    _redemptionCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.deal != null;
    return AlertDialog(
      title: Text(editing ? 'Edit offer' : 'New offer'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Offer title',
                    hintText: 'Free latte after focused study',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Add an offer title.';
                    if (text.length > 120) {
                      return 'Use 120 characters or fewer.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Tell students what they can unlock.',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length > 500) {
                      return 'Use 500 characters or fewer.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _DialogSection(
                  icon: Icons.sell_rounded,
                  title: 'Discount & Cura points',
                  subtitle:
                      'Students spend Cura points to redeem. \$1 off = 60 points, 1% off = 60 points.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _DiscountKindChip(
                              label: 'Dollars off (\$)',
                              selected: _discountKind == 'dollar',
                              onTap: () =>
                                  setState(() => _discountKind = 'dollar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DiscountKindChip(
                              label: 'Percent off (%)',
                              selected: _discountKind == 'percent',
                              onTap: () =>
                                  setState(() => _discountKind = 'percent'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _discountValue,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _discountKind == 'dollar'
                              ? 'Dollars off'
                              : 'Percent off',
                          hintText: _discountKind == 'dollar' ? '2' : '10',
                        ),
                        validator: _validateDiscount,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _PointsPreview(points: _computedPoints()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DialogSection(
                  icon: Icons.event_rounded,
                  title: 'Run length',
                  subtitle: 'Choose how long students can see and redeem it.',
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Length',
                          ),
                          validator: _validateDuration,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<_RunUnit>(
                        value: _runUnit,
                        items: <DropdownMenuItem<_RunUnit>>[
                          for (final unit in _RunUnit.values)
                            DropdownMenuItem<_RunUnit>(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: (unit) {
                          if (unit != null) {
                            setState(() => _runUnit = unit);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DialogSection(
                  icon: Icons.point_of_sale_rounded,
                  title: 'POS coupon code',
                  subtitle:
                      'Create this coupon in your POS first. The barista will see this exact code when a student redeems.',
                  child: TextFormField(
                    controller: _redemptionCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Coupon code',
                      hintText: 'CURA-LATTE',
                    ),
                    validator: _validateCode,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: Text(
                    _isActive ? 'Offer is active' : 'Offer is paused',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.espresso,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Students can see and unlock this offer.'
                        : 'Students will not see this offer.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.mocha,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.espresso,
            foregroundColor: AppColors.cream,
          ),
          child: Text(editing ? 'Save changes' : 'Add offer'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final now = DateTime.now().toUtc();
    final startsAt = widget.deal?.startsAt?.toUtc() ?? now;
    Navigator.of(context).pop(
      _OfferFormValue(
        title: _title.text.trim(),
        description: _description.text.trim(),
        discountKind: _discountKind,
        discountValue: double.tryParse(_discountValue.text.trim()),
        redemptionCode: _redemptionCode.text.trim(),
        startsAt: startsAt,
        endsAt: now.add(_runDuration()),
        isActive: _isActive,
      ),
    );
  }

  String? _validateDiscount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || amount <= 0) return 'Enter a discount amount.';
    if (_discountKind == 'percent' && amount > 100) {
      return 'Use 100% or less.';
    }
    if (_discountKind == 'dollar' && amount > 1000) {
      return 'Use \$1000 or less.';
    }
    return null;
  }

  String? _validateDuration(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    if (amount == null || amount <= 0) return 'Enter a run length.';
    if (_runUnit == _RunUnit.hours && amount > 720) {
      return 'Use days or weeks for longer runs.';
    }
    if (_runUnit == _RunUnit.weeks && amount > 52) {
      return 'Use 52 weeks or fewer.';
    }
    return null;
  }

  String? _validateCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the POS coupon code.';
    if (text.length > 80) return 'Use 80 characters or fewer.';
    return null;
  }

  Duration _runDuration() {
    final amount = int.tryParse(_duration.text.trim()) ?? 1;
    return _runUnit.duration(amount);
  }

  int _computedPoints() {
    final amount = double.tryParse(_discountValue.text.trim());
    if (amount == null || amount <= 0) return 0;
    final raw = amount * 60;
    return raw.round().clamp(1, 60000).toInt();
  }

  (int, _RunUnit) _initialRunLength(DealPerformance? deal) {
    final endsAt = deal?.endsAt;
    if (endsAt == null) return (7, _RunUnit.days);
    final remaining = endsAt.difference(DateTime.now());
    final safeRemaining = remaining.isNegative
        ? const Duration(days: 7)
        : remaining;
    if (safeRemaining.inHours < 48) {
      return (safeRemaining.inHours.clamp(1, 720).toInt(), _RunUnit.hours);
    }
    if (safeRemaining.inDays >= 14 && safeRemaining.inDays % 7 == 0) {
      return ((safeRemaining.inDays ~/ 7).clamp(1, 52).toInt(), _RunUnit.weeks);
    }
    return (safeRemaining.inDays.clamp(1, 365).toInt(), _RunUnit.days);
  }

  String _trimNum(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

enum _RunUnit {
  hours('hours'),
  days('days'),
  weeks('weeks');

  const _RunUnit(this.label);

  final String label;

  Duration duration(int amount) {
    return switch (this) {
      _RunUnit.hours => Duration(hours: amount),
      _RunUnit.days => Duration(days: amount),
      _RunUnit.weeks => Duration(days: amount * 7),
    };
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.latte.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.espresso.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: AppColors.espresso, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.espresso,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.mocha,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DiscountKindChip extends StatelessWidget {
  const _DiscountKindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.espresso.withValues(alpha: 0.32)
                : AppColors.espresso.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppColors.espresso : AppColors.mocha,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warmBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsPreview extends StatelessWidget {
  const _PointsPreview({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.forest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.forestDark,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            points > 0 ? '$points Cura points' : 'Enter a discount',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.forestDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: GoogleFonts.fraunces(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: AppColors.warmBlack,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.4,
            color: AppColors.mocha,
          ),
        ),
      ],
    );
    if (trailing == null) return titleBlock;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              titleBlock,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            trailing!,
          ],
        );
      },
    );
  }
}

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({required this.business});

  final OwnedBusiness business;

  @override
  Widget build(BuildContext context) {
    final imageUrl = business.imageUrl;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.latte.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.espresso.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl.isEmpty
          ? const Icon(Icons.storefront_rounded, color: AppColors.espresso)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.storefront_rounded,
                color: AppColors.espresso,
              ),
            ),
    );
  }
}

class _HeaderControls extends StatelessWidget {
  const _HeaderControls({
    required this.preset,
    required this.onPresetChanged,
    required this.stacked,
  });

  final DatePreset preset;
  final ValueChanged<DatePreset> onPresetChanged;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _Segmented<DatePreset>(
        value: preset,
        options: const <(String, DatePreset)>[
          ('7 days', DatePreset.sevenDays),
          ('30 days', DatePreset.thirtyDays),
          ('90 days', DatePreset.ninetyDays),
        ],
        onChanged: onPresetChanged,
      ),
    ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: children,
    );
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.espresso.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (label, val) in options)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 16,
                      vertical: compact ? 7 : 9,
                    ),
                    decoration: BoxDecoration(
                      color: val == value
                          ? AppColors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: val == value
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.espresso.withValues(
                                  alpha: 0.10,
                                ),
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
                        color: val == value
                            ? AppColors.espresso
                            : AppColors.mocha,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
              fontSize: 14.5,
              height: 1.55,
              color: AppColors.mocha,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.cream,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (embedded) {
      return Padding(padding: const EdgeInsets.all(40), child: content);
    }
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
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
              const SizedBox(
                width: 220,
                height: 130,
                child: SkeletonBox(height: 130),
              ),
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
