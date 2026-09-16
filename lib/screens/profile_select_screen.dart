import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/platform_hint.dart';
import '../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';

class ProfileSelectScreen extends ConsumerWidget {
  const ProfileSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = suggestedProfile();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, size: 56, color: Colors.pinkAccent),
                  const SizedBox(height: 12),
                  Text('Nosflix', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Quem tá assistindo?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _ProfileCard(
                    profile: Profile.heitor,
                    highlighted: suggested == Profile.heitor,
                    onTap: () => ref.read(profileProvider.notifier).select(Profile.heitor),
                  ),
                  const SizedBox(height: 16),
                  _ProfileCard(
                    profile: Profile.leticia,
                    highlighted: suggested == Profile.leticia,
                    onTap: () => ref.read(profileProvider.notifier).select(Profile.leticia),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final bool highlighted;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.highlighted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = profile.seedColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: highlighted ? color : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Text(
                profile.displayName[0],
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                profile.displayName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            if (highlighted) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}
