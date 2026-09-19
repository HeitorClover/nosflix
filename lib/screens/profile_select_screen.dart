import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/platform_hint.dart';
import '../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import '../widgets/nosflix_widgets.dart';

class ProfileSelectScreen extends ConsumerWidget {
  const ProfileSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = suggestedProfile();

    return Scaffold(
      body: SizedBox.expand(
        // Fundo mistura o vermelho dele com o rosa dela.
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Profile.heitor.glowColor, const Color(0xFF0B0709), Profile.leticia.glowColor],
              stops: const [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wordmark(
                          size: 68,
                          gradient: LinearGradient(
                            colors: [Profile.heitor.seedColor, Profile.leticia.seedColor],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Quem tá assistindo?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 40),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: profile.gradient,
        borderRadius: BorderRadius.circular(24),
        border: highlighted ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: profile.seedColor.withValues(alpha: highlighted ? 0.55 : 0.3),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: Text(
                    profile.displayName[0],
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    profile.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(
                  highlighted ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
