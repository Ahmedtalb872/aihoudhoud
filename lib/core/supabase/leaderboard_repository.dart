import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_exception.dart';
import 'supabase_config.dart';

/// One captain's rank on either leaderboard - points are always
/// trips_count * leaderboard_settings.points_per_trip, computed
/// server-side so the app never hardcodes that multiplier.
class LeaderboardEntry {
  final String captainId;
  final String fullName;
  final int tripsCount;
  final double points;

  const LeaderboardEntry({
    required this.captainId,
    required this.fullName,
    required this.tripsCount,
    required this.points,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) {
    return LeaderboardEntry(
      captainId: row['captain_id'] as String,
      fullName: row['full_name'] as String? ?? 'كابتن',
      tripsCount: (row['trips_count'] as num).toInt(),
      points: (row['points'] as num).toDouble(),
    );
  }
}

/// Today's and this week's top captains by points, and how many winners
/// the weekly prize actually covers - all computed server-side (see
/// 0032_leaderboard_points.sql) from real completed trips, not the
/// hardcoded placeholder list this screen used to show.
class LeaderboardRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<LeaderboardEntry>> getDailyLeaderboard({int limit = 3}) async {
    try {
      final rows = await _client.rpc(
        'get_daily_leaderboard',
        params: {'p_limit': limit},
      );
      return (rows as List)
          .map((r) => LeaderboardEntry.fromRow(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل ترتيب اليوم.');
    }
  }

  Future<List<LeaderboardEntry>> getWeeklyLeaderboard() async {
    try {
      final rows = await _client.rpc('get_weekly_leaderboard');
      return (rows as List)
          .map((r) => LeaderboardEntry.fromRow(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل ترتيب الأسبوع.');
    }
  }

  /// How many of the weekly list's names actually win a prize, and an
  /// optional note management can set describing what that prize is -
  /// both admin-controlled (see leaderboard_settings), never hardcoded.
  Future<({int winnersCount, String? prizeDescription})>
  getWeeklyPrizeInfo() async {
    try {
      final row = await _client
          .from('leaderboard_settings')
          .select('weekly_prize_winners_count, weekly_prize_description')
          .limit(1)
          .single();
      return (
        winnersCount: (row['weekly_prize_winners_count'] as num?)?.toInt() ?? 3,
        prizeDescription: row['weekly_prize_description'] as String?,
      );
    } on PostgrestException {
      return (winnersCount: 3, prizeDescription: null);
    }
  }
}
