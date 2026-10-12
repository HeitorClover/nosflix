import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'nosflix_widgets.dart';
import '../models/audience.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';

/// Texto curto do progresso de série, ex: "T2 · E5". Nulo se não houver.
String? progressLabel(TitleModel title) {
  if (title.status != WatchStatus.assistindo || title.currentSeason == null) return null;
  return 'T${title.currentSeason} · E${title.currentEpisode ?? 1}';
}

class TitleCard extends StatelessWidget {
  final TitleModel title;
  final VoidCallback onTap;

  /// Nota média do casal (0–5), se houver.
  final double? rating;

  const TitleCard({super.key, required this.title, required this.onTap, this.rating});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (title.releaseYear != null) '${title.releaseYear}',
      title.category.label,
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 8)),
          BoxShadow(color: scheme.primary.withValues(alpha: 0.10), blurRadius: 24),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            title.posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: title.posterUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => _placeholder(scheme),
                    placeholder: (context, url) => _placeholder(scheme),
                  )
                : _placeholder(scheme),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 1],
                  colors: [Colors.transparent, context.nx.base.withValues(alpha: 0.96)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Positioned(top: 10, left: 10, child: _StatusBadge(title: title)),
            if (rating != null) Positioned(top: 10, right: 10, child: _RatingBadge(value: rating!)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant, size: 36),
      );
}

class _RatingBadge extends StatelessWidget {
  final double value;
  const _RatingBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 3),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TitleModel title;
  const _StatusBadge({required this.title});

  @override
  Widget build(BuildContext context) {
    final progress = progressLabel(title);
    if (progress != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(gradient: context.nx.gradient, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 2),
            Text(progress, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    final solo = title.audience.profile;
    if (solo != null && title.status != WatchStatus.recomendo) {
      return Tooltip(message: '${title.status.label}: só ${solo.displayName}', child: ProfileAvatar(profile: solo, radius: 12));
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: title.status.label,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
        child: Icon(
          title.status.icon,
          size: 14,
          color: title.status == WatchStatus.queroVer ? Colors.white : primary,
        ),
      ),
    );
  }
}
