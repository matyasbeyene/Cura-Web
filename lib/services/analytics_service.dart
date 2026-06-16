import 'dart:convert';

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

enum OfferType {
  study('study'),
  promotion('promotion');

  const OfferType(this.value);

  final String value;

  bool get isStudy => this == OfferType.study;
  bool get isPromotion => this == OfferType.promotion;

  static OfferType fromValue(Object? value) {
    return value?.toString() == promotion.value ? promotion : study;
  }
}

/// The single business owned by the signed-in user.
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
    peakHour: _text(map['peak_hour'], fallback: 'no clear peak yet'),
  );

  static const empty = DashboardTotals(
    focusMinutes: 0,
    sessions: 0,
    uniqueStudents: 0,
    averageMinutes: 0,
    activeNow: 0,
    returnRate: 0,
    peakHour: 'no clear peak yet',
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
    required this.id,
    required this.businessId,
    required this.title,
    required this.description,
    required this.offerType,
    required this.requiredMinutes,
    required this.redemptionCode,
    required this.isActive,
    this.startsAt,
    this.endsAt,
    required this.redemptions,
    required this.studentsStarted,
    required this.studentsUnlocked,
    required this.averageProgress,
    required this.privacyLimited,
  });

  final String id;
  final String businessId;
  final String title;
  final String description;
  final OfferType offerType;
  final int requiredMinutes;
  final String redemptionCode;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int redemptions;
  final int studentsStarted;
  final int studentsUnlocked;
  final double averageProgress; // 0..1
  final bool privacyLimited;

  double get requiredHours => requiredMinutes / 60.0;
  bool get isPromotion => offerType.isPromotion;

  factory DealPerformance.fromMap(Map<String, dynamic> map) {
    final legacyMetadata = _parseLegacyOfferMetadata(_text(map['description']));
    final type =
        legacyMetadata.offerType ?? OfferType.fromValue(map['offer_type']);
    return DealPerformance(
      id: _text(map['offer_id'], fallback: _text(map['id'])),
      businessId: _text(map['business_id']),
      title: _text(map['title'], fallback: 'Deal'),
      description: legacyMetadata.description,
      offerType: type,
      requiredMinutes: type.isPromotion ? 0 : _int(map['required_minutes']),
      redemptionCode: _text(
        map['redemption_code'],
        fallback: legacyMetadata.redemptionCode,
      ),
      isActive: map['is_active'] as bool? ?? true,
      startsAt: DateTime.tryParse(_text(map['starts_at'])),
      endsAt: DateTime.tryParse(_text(map['ends_at'])),
      redemptions: _int(map['redemptions']),
      studentsStarted: _int(map['students_started']),
      studentsUnlocked: _int(map['students_unlocked']),
      averageProgress: _ratio(map['average_progress']),
      privacyLimited: map['privacy_limited'] as bool? ?? false,
    );
  }
}

class DashboardInsight {
  const DashboardInsight({required this.title, required this.body});
  final String title;
  final String body;

  factory DashboardInsight.fromMap(Map<String, dynamic> map) =>
      DashboardInsight(
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
    durationBuckets: _list(
      json['duration_buckets'],
    ).map(BreakdownItem.fromMap).toList(),
    deals: _list(json['deals']).map(DealPerformance.fromMap).toList(),
    insights: _list(json['insights']).map(DashboardInsight.fromMap).toList(),
  );

  DashboardData copyWith({List<DealPerformance>? deals}) => DashboardData(
    generatedAt: generatedAt,
    privacyThreshold: privacyThreshold,
    totals: totals,
    trend: trend,
    gender: gender,
    level: level,
    year: year,
    major: major,
    hourly: hourly,
    durationBuckets: durationBuckets,
    deals: deals ?? this.deals,
    insights: insights,
  );
}

/// Current-period data plus the immediately-prior period for deltas.
class DashboardBundle {
  const DashboardBundle({required this.current, this.previous});
  final DashboardData current;
  final DashboardData? previous;
}

class AnalyticsService {
  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// The business owned by the signed-in user.
  ///
  /// Cura's business model is one owned business per auth UID. Supabase should
  /// enforce that with a unique `businesses.owner_id`.
  Future<OwnedBusiness?> fetchMyBusiness() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final data = await _client
          .from('businesses')
          .select(
            'id,owner_id,study_location_id,name,category,image_url,is_active',
          )
          .eq('owner_id', uid)
          .maybeSingle();
      if (data == null) return null;
      return OwnedBusiness.fromMap(Map<String, dynamic>.from(data));
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
        List v when v.isNotEmpty && v.first is Map => Map<String, dynamic>.from(
          v.first as Map,
        ),
        _ => throw const AnalyticsException(
          'Analytics returned an unexpected response.',
        ),
      };
      return await _withDirectDealsIfNeeded(
        DashboardData.fromRpc(json),
        businessId: businessId,
      );
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
      previous =
          null; // deltas are a nice-to-have; never block the page on them
    }
    return DashboardBundle(current: current, previous: previous);
  }

  Future<void> saveOffer({
    String? id,
    required String businessId,
    required String title,
    required String description,
    required OfferType offerType,
    required int requiredMinutes,
    required String redemptionCode,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
  }) async {
    if (_uid == null) {
      throw const AnalyticsException('Please sign in again to manage rewards.');
    }
    if (!endsAt.isAfter(startsAt)) {
      throw const AnalyticsException(
        'Offer end time must be after start time.',
      );
    }

    final normalizedTitle = _cleanText(title, field: 'Offer title', max: 120);
    final normalizedDescription = _cleanText(
      description,
      field: 'Offer description',
      max: 500,
      required: false,
    );
    final normalizedRequiredMinutes = _requiredMinutes(
      requiredMinutes,
      offerType,
    );
    final normalizedRedemptionCode = _cleanText(
      redemptionCode,
      field: 'POS coupon code',
      max: 80,
    );
    final values = <String, dynamic>{
      'business_id': businessId,
      'title': normalizedTitle,
      'description': normalizedDescription,
      'offer_type': offerType.value,
      'required_minutes': normalizedRequiredMinutes,
      'redemption_code': normalizedRedemptionCode,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'is_active': isActive,
    };

    try {
      await _writeOffer(id: id, businessId: businessId, values: values);
    } catch (e) {
      if (!_isSchemaMismatch(e)) throw AnalyticsException(_friendly(e));
      if (offerType.isPromotion) {
        final legacyValues = <String, dynamic>{
          'business_id': businessId,
          'title': normalizedTitle,
          'description': _encodeLegacyOfferMetadata(
            description: normalizedDescription,
            offerType: offerType,
            redemptionCode: normalizedRedemptionCode,
          ),
          'required_minutes': 1,
          'is_active': isActive,
        };
        try {
          await _writeOffer(
            id: id,
            businessId: businessId,
            values: legacyValues,
          );
          return;
        } catch (legacyError) {
          throw AnalyticsException(_friendly(legacyError));
        }
      }
      final legacyValues = <String, dynamic>{
        'business_id': businessId,
        'title': normalizedTitle,
        'description': _encodeLegacyOfferMetadata(
          description: normalizedDescription,
          offerType: offerType,
          redemptionCode: normalizedRedemptionCode,
        ),
        'required_minutes': normalizedRequiredMinutes,
        'is_active': isActive,
      };
      try {
        await _writeOffer(id: id, businessId: businessId, values: legacyValues);
      } catch (legacyError) {
        throw AnalyticsException(_friendly(legacyError));
      }
    }
  }

  Future<void> _writeOffer({
    required String? id,
    required String businessId,
    required Map<String, dynamic> values,
  }) async {
    if (id == null) {
      await _client.from('offers').insert(values);
    } else {
      await _client
          .from('offers')
          .update(values)
          .eq('id', id)
          .eq('business_id', businessId);
    }
  }

  Future<void> deleteOffer({
    required String id,
    required String businessId,
  }) async {
    if (_uid == null) {
      throw const AnalyticsException('Please sign in again to manage rewards.');
    }
    try {
      await _client
          .from('offers')
          .delete()
          .eq('id', id)
          .eq('business_id', businessId);
    } catch (e) {
      throw AnalyticsException(_friendly(e));
    }
  }

  Future<void> setOfferActive({
    required String id,
    required String businessId,
    required bool isActive,
  }) async {
    if (_uid == null) {
      throw const AnalyticsException('Please sign in again to manage rewards.');
    }
    try {
      await _client
          .from('offers')
          .update(<String, dynamic>{'is_active': isActive})
          .eq('id', id)
          .eq('business_id', businessId);
    } catch (e) {
      throw AnalyticsException(_friendly(e));
    }
  }

  Future<DashboardData> _withDirectDealsIfNeeded(
    DashboardData dashboard, {
    required String businessId,
  }) async {
    if (dashboard.deals.isNotEmpty) return dashboard;
    final deals = await _fetchDirectDeals(businessId);
    if (deals.isEmpty) return dashboard;
    return dashboard.copyWith(deals: deals);
  }

  Future<List<DealPerformance>> _fetchDirectDeals(String businessId) async {
    try {
      final response = await _client.rpc(
        'business_offer_admin_rows',
        params: <String, dynamic>{'p_business_id': businessId},
      );
      return _parseDeals(response);
    } catch (e) {
      if (!_isSchemaMismatch(e)) return const <DealPerformance>[];
    }

    try {
      final data = await _client
          .from('offers')
          .select(_directOfferColumns)
          .eq('business_id', businessId)
          .limit(100);
      return _parseDeals(data);
    } catch (_) {
      try {
        final data = await _client
            .from('offers')
            .select(_legacyDirectOfferColumns)
            .eq('business_id', businessId)
            .limit(100);
        return _parseDeals(data);
      } catch (_) {
        return const <DealPerformance>[];
      }
    }
  }

  String _dateOnly(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
  ).toIso8601String().substring(0, 10);

  String _friendly(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('authentication required')) {
      return 'Please sign in again to view analytics.';
    }
    if (text.contains('row-level security') ||
        text.contains('policy') ||
        text.contains('not allowed')) {
      return 'Not allowed. Make sure you own this business.';
    }
    if (text.contains('multiple') || text.contains('singular')) {
      return 'This account is linked to more than one business. Supabase should allow only one business per owner.';
    }
    if (text.contains('offers') &&
        (text.contains('does not exist') ||
            text.contains('could not find') ||
            text.contains('not found'))) {
      return 'Offer management is not available yet. Apply the Supabase offer policies, then try again.';
    }
    if (text.contains('does not exist') || text.contains('could not find')) {
      return 'Analytics are not available yet for this account.';
    }
    if (text.contains('violates check constraint') ||
        text.contains('offers_title_check')) {
      return 'Check the offer title, type, run window, study time, and POS coupon code.';
    }
    if (text.contains('permission denied') ||
        text.contains('offers') && text.contains('not found')) {
      return 'Offer management is not available yet. Apply the Supabase offer policies, then try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  bool _isSchemaMismatch(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('offer_type') ||
        text.contains('redemption_code') ||
        text.contains('starts_at') ||
        text.contains('schema cache') ||
        text.contains('could not find') ||
        text.contains('does not exist') ||
        text.contains('pgrst204');
  }

  String _cleanText(
    String value, {
    required String field,
    required int max,
    bool required = true,
  }) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (required && normalized.isEmpty) {
      throw AnalyticsException('$field is required.');
    }
    if (normalized.length > max) {
      throw AnalyticsException('$field must be $max characters or fewer.');
    }
    return normalized;
  }

  int _requiredMinutes(int value, OfferType offerType) {
    if (offerType.isPromotion) return 0;
    if (value < 1) {
      throw const AnalyticsException(
        'Required study time must be at least 1 minute.',
      );
    }
    if (value > 100000) {
      throw const AnalyticsException('Required study time is too high.');
    }
    return value;
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

double _ratio(dynamic value, {double fallback = 0}) {
  final raw = _double(value, fallback: fallback);
  if (raw > 1) return (raw / 100).clamp(0.0, 1.0);
  return raw.clamp(0.0, 1.0);
}

const _legacyMarkerPrefix = '[CURA_OFFER_META:';
const _legacyMarkerSuffix = ']';
const _directOfferColumns =
    'id,business_id,title,description,offer_type,required_minutes,'
    'redemption_code,starts_at,ends_at,is_active';
const _legacyDirectOfferColumns =
    'id,business_id,title,description,required_minutes,is_active';

List<DealPerformance> _parseDeals(Object? data) {
  final rows = data is List ? data : const <Object?>[];
  return <DealPerformance>[
    for (final row in rows)
      if (row is Map) DealPerformance.fromMap(Map<String, dynamic>.from(row)),
  ];
}

class _LegacyOfferMetadata {
  const _LegacyOfferMetadata({
    required this.description,
    this.offerType,
    this.redemptionCode = '',
  });

  final String description;
  final OfferType? offerType;
  final String redemptionCode;
}

String _encodeLegacyOfferMetadata({
  required String description,
  required OfferType offerType,
  required String redemptionCode,
}) {
  final metadata = jsonEncode({
    'offer_type': offerType.value,
    'redemption_code': redemptionCode,
  });
  final encoded = base64Url.encode(utf8.encode(metadata));
  final cleanDescription = _parseLegacyOfferMetadata(description).description;
  return [
    if (cleanDescription.trim().isNotEmpty) cleanDescription.trim(),
    '$_legacyMarkerPrefix$encoded$_legacyMarkerSuffix',
  ].join('\n\n');
}

_LegacyOfferMetadata _parseLegacyOfferMetadata(String value) {
  final trimmed = value.trimRight();
  final start = trimmed.lastIndexOf(_legacyMarkerPrefix);
  if (start < 0) return _LegacyOfferMetadata(description: value);

  final markerEnd = trimmed.indexOf(_legacyMarkerSuffix, start);
  if (markerEnd < 0 ||
      markerEnd != trimmed.length - _legacyMarkerSuffix.length) {
    return _LegacyOfferMetadata(description: value);
  }

  final encoded = trimmed.substring(
    start + _legacyMarkerPrefix.length,
    markerEnd,
  );
  try {
    final decoded = utf8.decode(base64Url.decode(encoded));
    final json = jsonDecode(decoded);
    if (json is! Map) return _LegacyOfferMetadata(description: value);
    return _LegacyOfferMetadata(
      description: trimmed.substring(0, start).trimRight(),
      offerType: OfferType.fromValue(json['offer_type']),
      redemptionCode: json['redemption_code']?.toString().trim() ?? '',
    );
  } catch (_) {
    return _LegacyOfferMetadata(description: value);
  }
}
