import 'package:supabase_flutter/supabase_flutter.dart';

/// Business analytics for Cura partner businesses.
///
/// This reuses the backend the mobile app uses: the SECURITY DEFINER Postgres
/// function `business_dashboard_summary(business_id, start, end)`, which returns
/// a complete, privacy-safe payload (k-anonymity hides any group < 3 students).
/// We never re-implement the queries; we just call the RPC and parse it.

class AnalyticsException implements Exception {
  const AnalyticsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A business owned by the signed-in user.
class OwnedBusiness {
  const OwnedBusiness({
    required this.id,
    required this.name,
    required this.category,
    required this.isActive,
    this.studyLocationId,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String category;
  final bool isActive;
  final String? studyLocationId;
  final String? imageUrl;

  factory OwnedBusiness.fromMap(Map<String, dynamic> map) => OwnedBusiness(
        id: map['id'].toString(),
        name: (map['name'] as String?) ?? '',
        category: (map['category'] as String?) ?? '',
        isActive: map['is_active'] as bool? ?? true,
        studyLocationId: map['study_location_id'] as String?,
        imageUrl: map['image_url'] as String?,
      );
}

/// Date-range presets for the dashboard.
enum DatePreset {
  sevenDays('7 days', 7),
  thirtyDays('30 days', 30),
  ninetyDays('90 days', 90);

  const DatePreset(this.label, this.days);
  final String label;
  final int days;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get start => _today.subtract(Duration(days: days - 1));
  DateTime get end => _today.add(const Duration(days: 1)); // inclusive of today

  /// The window of equal length immediately before [start], for deltas.
  DateTime get previousStart => start.subtract(Duration(days: days));
  DateTime get previousEnd => start;
}

class DashboardTotals {
  const DashboardTotals({
    required this.focusMinutes,
    required this.sessions,
    required this.uniqueStudents,
    required this.averageMinutes,
    required this.activeNow,
    required this.returnRate,
    required this.peakHour,
  });

  final int focusMinutes;
  final int sessions;
  final int uniqueStudents;
  final double averageMinutes;
  final int activeNow;
  final double returnRate; // 0..1
  final String peakHour;

  double get focusHours => focusMinutes / 60.0;

  factory DashboardTotals.fromMap(Map<String, dynamic> map) => DashboardTotals(
        focusMinutes: _int(map['focus_minutes']),
        sessions: _int(map['sessions']),
        uniqueStudents: _int(map['unique_students']),
        averageMinutes: _double(map['average_minutes']),
        activeNow: _int(map['active_now']),
        returnRate: _double(map['return_rate']),
        peakHour: _text(map['peak_hour'], fallback: 'No clear peak yet'),
      );

  static const empty = DashboardTotals(
    focusMinutes: 0,
    sessions: 0,
    uniqueStudents: 0,
    averageMinutes: 0,
    activeNow: 0,
    returnRate: 0,
    peakHour: 'No clear peak yet',
  );
}

class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.sessions,
    required this.focusMinutes,
    required this.uniqueStudents,
  });

  final DateTime date;
  final int sessions;
  final int focusMinutes;
  final int uniqueStudents;

  factory TrendPoint.fromMap(Map<String, dynamic> map) => TrendPoint(
        date: DateTime.tryParse(_text(map['date'])) ?? DateTime.now(),
        sessions: _int(map['sessions']),
        focusMinutes: _int(map['focus_minutes']),
        uniqueStudents: _int(map['unique_students']),
      );
}

class BreakdownItem {
  const BreakdownItem({
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String label;
  final int count;
  final double percentage; // 0..100

  factory BreakdownItem.fromMap(Map<String, dynamic> map) => BreakdownItem(
        label: _text(map['label'], fallback: 'Unknown'),
        count: _int(map['count']),
        percentage: _double(map['percentage']),
      );
}

class HourCell {
  const HourCell({
    required this.weekday,
    required this.hour,
    required this.sessions,
    required this.focusMinutes,
  });

  final int weekday; // 1=Mon .. 7=Sun
  final int hour; // 0..23
  final int sessions;
  final int focusMinutes;

  factory HourCell.fromMap(Map<String, dynamic> map) => HourCell(
        weekday: _int(map['weekday']).clamp(1, 7),
        hour: _int(map['hour']).clamp(0, 23),
        sessions: _int(map['sessions']),
        focusMinutes: _int(map['focus_minutes']),
      );
}

class DealPerformance {
  const DealPerformance({
    required this.title,
    required this.description,
    required this.requiredMinutes,
    required this.isActive,
    required this.studentsStarted,
    required this.studentsUnlocked,
    required this.averageProgress,
    required this.privacyLimited,
  });

  final String title;
  final String description;
  final int requiredMinutes;
  final bool isActive;
  final int studentsStarted;
  final int studentsUnlocked;
  final double averageProgress; // 0..1
  final bool privacyLimited;

  double get requiredHours => requiredMinutes / 60.0;

  factory DealPerformance.fromMap(Map<String, dynamic> map) => DealPerformance(
        title: _text(map['title'], fallback: 'Deal'),
        description: _text(map['description']),
        requiredMinutes: _int(map['required_minutes']),
        isActive: map['is_active'] as bool? ?? true,
        studentsStarted: _int(map['students_started']),
        studentsUnlocked: _int(map['students_unlocked']),
        averageProgress: _double(map['average_progress']),
        privacyLimited: map['privacy_limited'] as bool? ?? false,
      );
}

class DashboardInsight {
  const DashboardInsight({required this.title, required this.body});
  final String title;
  final String body;

  factory DashboardInsight.fromMap(Map<String, dynamic> map) => DashboardInsight(
        title: _text(map['title'], fallback: 'Insight'),
        body: _text(map['body']),
      );
}

/// The full payload returned by `business_dashboard_summary`.
class DashboardData {
  const DashboardData({
    required this.generatedAt,
    required this.privacyThreshold,
    required this.totals,
    required this.trend,
    required this.gender,
    required this.level,
    required this.year,
    required this.major,
    required this.hourly,
    required this.durationBuckets,
    required this.deals,
    required this.insights,
  });

  final DateTime generatedAt;
  final int privacyThreshold;
  final DashboardTotals totals;
  final List<TrendPoint> trend;
  final List<BreakdownItem> gender;
  final List<BreakdownItem> level;
  final List<BreakdownItem> year;
  final List<BreakdownItem> major;
  final List<HourCell> hourly;
  final List<BreakdownItem> durationBuckets;
  final List<DealPerformance> deals;
  final List<DashboardInsight> insights;

  factory DashboardData.fromRpc(Map<String, dynamic> json) => DashboardData(
        generatedAt:
            DateTime.tryParse(_text(json['generated_at'])) ?? DateTime.now(),
        privacyThreshold: _int(json['privacy_threshold'], fallback: 3),
        totals: DashboardTotals.fromMap(_map(json['totals'])),
        trend: _list(json['trend']).map(TrendPoint.fromMap).toList(),
        gender: _list(json['gender']).map(BreakdownItem.fromMap).toList(),
        level: _list(json['level']).map(BreakdownItem.fromMap).toList(),
        year: _list(json['year']).map(BreakdownItem.fromMap).toList(),
        major: _list(json['major']).map(BreakdownItem.fromMap).toList(),
        hourly: _list(json['hourly']).map(HourCell.fromMap).toList(),
        durationBuckets:
            _list(json['duration_buckets']).map(BreakdownItem.fromMap).toList(),
        deals: _list(json['deals']).map(DealPerformance.fromMap).toList(),
        insights:
            _list(json['insights']).map(DashboardInsight.fromMap).toList(),
      );
}

/// Current-period data plus the immediately-prior period (for ↑/↓ deltas).
class DashboardBundle {
  const DashboardBundle({required this.current, this.previous});
  final DashboardData current;
  final DashboardData? previous;
}

class AnalyticsService {
  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Businesses owned by the signed-in user (empty if they own none).
  Future<List<OwnedBusiness>> fetchMyBusinesses() async {
    final uid = _uid;
    if (uid == null) return const <OwnedBusiness>[];
    try {
      final data = await _client
          .from('businesses')
          .select('id,owner_id,study_location_id,name,category,image_url,is_active')
          .eq('owner_id', uid)
          .order('created_at')
          .limit(10);
      return data
          .map((e) => OwnedBusiness.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw AnalyticsException(_friendly(e));
    }
  }

  /// Calls the dashboard RPC for one business and date window.
  Future<DashboardData> fetchDashboard({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await _client.rpc(
        'business_dashboard_summary',
        params: <String, dynamic>{
          'p_business_id': businessId,
          'p_start_date': _dateOnly(start),
          'p_end_date': _dateOnly(end),
        },
      );
      final json = switch (response) {
        Map<String, dynamic> v => v,
        Map v => Map<String, dynamic>.from(v),
        List v when v.isNotEmpty && v.first is Map =>
          Map<String, dynamic>.from(v.first as Map),
        _ => throw const AnalyticsException(
            'Analytics returned an unexpected response.'),
      };
      return DashboardData.fromRpc(json);
    } on AnalyticsException {
      rethrow;
    } catch (e) {
      throw AnalyticsException(_friendly(e));
    }
  }

  /// Current window + the prior equal-length window (prior is best-effort).
  Future<DashboardBundle> fetchBundle({
    required String businessId,
    required DatePreset preset,
  }) async {
    final current = await fetchDashboard(
      businessId: businessId,
      start: preset.start,
      end: preset.end,
    );
    DashboardData? previous;
    try {
      previous = await fetchDashboard(
        businessId: businessId,
        start: preset.previousStart,
        end: preset.previousEnd,
      );
    } catch (_) {
      previous = null; // deltas are a nice-to-have; never block the page on them
    }
    return DashboardBundle(current: current, previous: previous);
  }

  String _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day)
          .toIso8601String()
          .substring(0, 10);

  String _friendly(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('authentication required')) {
      return 'Please sign in again to view analytics.';
    }
    if (text.contains('row-level security') ||
        text.contains('policy') ||
        text.contains('not allowed')) {
      return 'Not allowed — make sure you own this business.';
    }
    if (text.contains('does not exist') || text.contains('could not find')) {
      return 'Analytics are not available yet for this account.';
    }
    return 'Something went wrong loading analytics. Please try again.';
  }
}

// ---- parsing helpers (mirror the mobile app) ----

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _double(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
