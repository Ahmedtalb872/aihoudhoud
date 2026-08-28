import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../dummy_data/dummy_data.dart';

class ProfileScreen extends StatelessWidget {
  final bool showAppBar;
  const ProfileScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    final avatarUrl = DummyData.dummyCaptain.user.avatar;
    final userName = provider.captainName;
    final userPhone = provider.captainPhone;
    final rating = DummyData.dummyCaptain.user.rating;
    final tripsCount = provider.captainTripsCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar ? AppBar(title: const Text('الملف الشخصي')) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (!showAppBar) const SizedBox(height: 20),

            // Profile Header Card
            _buildProfileHeader(
              avatarUrl,
              userName,
              userPhone,
              rating,
              tripsCount,
            ),
            const SizedBox(height: 24),

            // Only the delivery-mode toggle lives here now - every other
            // menu item (edit info, wallet, trip history, settings,
            // support) moved into the drawer and would just be a
            // duplicate shortcut to the exact same screen if kept here too.
            _buildCaptainMenu(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    String avatar,
    String name,
    String phone,
    double rating,
    int trips,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: NetworkImage(avatar),
              backgroundColor: AppColors.background,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHeaderStat('التقييم', '$rating ⭐'),
                Container(width: 1, height: 30, color: AppColors.border),
                _buildHeaderStat('المشاوير', '$trips مشوار'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  // Available to every captain: for a motorcycle captain this is the only
  // kind of request they ever receive; for a car captain it's on top of
  // their normal passenger rides. Not in the drawer, so it stays here.
  Widget _buildCaptainMenu(AppStateProvider provider) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.inventory_2_rounded,
          color: provider.deliveryModeEnabled
              ? AppColors.primaryDark
              : AppColors.secondaryText,
          size: 22,
        ),
        title: const Text(
          'قبول طلبات توصيل',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        trailing: Switch(
          value: provider.deliveryModeEnabled,
          activeColor: AppColors.primaryDark,
          onChanged: (_) => provider.toggleDeliveryMode(),
        ),
      ),
    );
  }
}
