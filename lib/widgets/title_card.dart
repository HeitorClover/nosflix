import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
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

  const TitleCard({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.55, 1],
                  colors: [Colors.transparent, Color(0xEE000000)],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                title.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.15,
                ),
              ),
            ),
            Positioned(top: 8, left: 8, child: _StatusBadge(title: title)),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: title.status.label,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
        child: Icon(
          title.status.icon,
          size: 14,
          color: title.status == WatchStatus.queroVer ? Colors.white : primary,
        ),
      ),
    );
  }
}
