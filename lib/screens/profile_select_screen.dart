import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import '../widgets/nosflix_widgets.dart';

class ProfileSelectScreen extends ConsumerWidget {
  const ProfileSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            BackdropPhoto.home.asset,
            fit: BoxFit.cover,
            alignment: BackdropPhoto.home.alignment,
            errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF0B0709)),
          ),
          // Rosa (dela) à esquerda, vermelho (dele) à direita, escurecendo embaixo.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Profile.leticia.deepColor.withValues(alpha: 0.7),
                  Profile.heitor.deepColor.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0xE60B0709)],
                stops: [0, 0.75],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wordmark(
                        size: 68,
                        gradient: LinearGradient(
                          colors: [Profile.leticia.lightColor, Profile.heitor.lightColor],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Quem tá assistindo?',
                        style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.75)),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          Expanded(
                            child: _ProfileCard(
                              profile: Profile.leticia,
                              onTap: () => ref.read(profileProvider.notifier).select(Profile.leticia),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ProfileCard(
                              profile: Profile.heitor,
                              onTap: () => ref.read(profileProvider.notifier).select(Profile.heitor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: profile.seedColor.withValues(alpha: 0.45), blurRadius: 30, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                profile.photoAsset,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.3),
                errorBuilder: (_, _, _) => ColoredBox(color: profile.deepColor),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1],
                    colors: [Colors.transparent, profile.deepColor.withValues(alpha: 0.95)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(color: Colors.transparent, child: InkWell(onTap: onTap)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
