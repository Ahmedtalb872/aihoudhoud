import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A single pickup/destination line: a colored dot followed by the address,
/// with an optional trailing note (e.g. a distance). Two of these stacked -
/// green dot for pickup, red for destination - is the app's standard way of
/// showing a trip's route, each point on its own line.
class RouteRow extends StatelessWidget {
  final Color dotColor;
  final String text;
  final String? trailing;

  const RouteRow({
    super.key,
    required this.dotColor,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ],
    );
  }
}
