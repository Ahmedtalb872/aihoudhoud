import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/leaderboard_repository.dart';
import '../../providers/app_state_provider.dart';

/// Real points earned from completed trips - today's top 3 (shown to every
/// captain every day) and this week's fuller ranking (Monday-Sunday, see
/// 0032_leaderboard_points.sql), which is what the end-of-week prize
/// winners are picked from. Replaces the previous screen's hardcoded list
/// of ten made-up names and a vague "win monthly prizes" banner.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _repository = LeaderboardRepository();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المسابقات وترتيب الكباتن'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
            fontFamily: 'El Messiri',
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'اليوم'),
            Tab(text: 'هذا الأسبوع'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DailyLeaderboardTab(repository: _repository),
          _WeeklyLeaderboardTab(repository: _repository),
        ],
      ),
    );
  }
}

class _DailyLeaderboardTab extends StatelessWidget {
  final LeaderboardRepository repository;
  const _DailyLeaderboardTab({required this.repository});

  @override
  Widget build(BuildContext context) {
    return _LeaderboardList(
      banner: const _InfoBanner(
        text: 'أفضل 3 كباتن اليوم حسب عدد النقاط - تُحتسب نقطة واحدة أو أكثر عن كل رحلة مكتملة.',
      ),
      future: repository.getDailyLeaderboard(limit: 3),
    );
  }
}

class _WeeklyLeaderboardTab extends StatelessWidget {
  final LeaderboardRepository repository;
  const _WeeklyLeaderboardTab({required this.repository});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: repository.getWeeklyPrizeInfo(),
      builder: (context, prizeSnapshot) {
        final prize = prizeSnapshot.data;
        final bannerText = prize?.prizeDescription?.trim().isNotEmpty == true
            ? prize!.prizeDescription!
            : 'أفضل ${prize?.winnersCount ?? 3} كباتن هذا الأسبوع (الاثنين - الأحد) يفوزون بجوائز عند نهاية الأسبوع.';
        return _LeaderboardList(
          banner: _InfoBanner(text: bannerText),
          future: repository.getWeeklyLeaderboard(),
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.primaryDark,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'El Messiri',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final Widget banner;
  final Future<List<LeaderboardEntry>> future;
  const _LeaderboardList({required this.banner, required this.future});

  @override
  Widget build(BuildContext context) {
    final myId = Provider.of<AppStateProvider>(context, listen: false).userId;

    return FutureBuilder<List<LeaderboardEntry>>(
      future: future,
      builder: (context, snapshot) {
        Widget body;
        if (snapshot.connectionState != ConnectionState.done) {
          body = const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          final message = snapshot.error is AppAuthException
              ? (snapshot.error as AppAuthException).message
              : 'تعذر تحميل الترتيب، حاول مرة أخرى.';
          body = Center(
            child: Text(
              message,
              style: const TextStyle(fontFamily: 'El Messiri', color: AppColors.error),
            ),
          );
        } else {
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            body = const Center(
              child: Text(
                'لا يوجد كباتن أكملوا رحلات بعد في هذه الفترة.',
                style: TextStyle(fontFamily: 'El Messiri', color: AppColors.secondaryText),
              ),
            );
          } else {
            body = ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _buildRankRow(
                  rank: index + 1,
                  entry: entry,
                  isMe: entry.captainId == myId,
                );
              },
            );
          }
        }

        return Column(
          children: [
            banner,
            Expanded(child: body),
          ],
        );
      },
    );
  }

  Widget _buildRankRow({
    required int rank,
    required LeaderboardEntry entry,
    required bool isMe,
  }) {
    Color? medalColor;
    if (rank == 1) medalColor = const Color(0xFFFFD700);
    if (rank == 2) medalColor = const Color(0xFFC0C0C0);
    if (rank == 3) medalColor = const Color(0xFFCD7F32);

    final pointsLabel = entry.points == entry.points.roundToDouble()
        ? entry.points.toInt().toString()
        : entry.points.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: AppColors.primaryDark, width: 1.5)
            : null,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: medalColor != null
                ? Icon(Icons.emoji_events_rounded, color: medalColor, size: 26)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.secondaryText,
                      fontFamily: 'El Messiri',
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.background,
            child: Icon(Icons.person, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${entry.fullName} (أنت)' : entry.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.darkText,
                fontFamily: 'El Messiri',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pointsLabel نقطة',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontFamily: 'El Messiri',
                ),
              ),
              Text(
                '${entry.tripsCount} رحلة',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                  fontFamily: 'El Messiri',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
