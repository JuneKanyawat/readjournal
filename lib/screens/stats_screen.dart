import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '📊 Stats',
        style: TextStyle(
          fontSize: 24,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
