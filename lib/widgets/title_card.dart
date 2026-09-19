import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';

class TitleCard extends StatelessWidget {
  final TitleModel title;
  final VoidCallback onTap;

  const TitleCard({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: title.posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl: title.posterUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _placeholder(scheme),
                      placeholder: (context, url) => _placeholder(scheme),
                    )
                  : _placeholder(scheme),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                title.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  Icon(title.status.icon, size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title.status == WatchStatus.assistindo && title.currentSeason != null
                          ? '${title.status.label} · T${title.currentSeason} E${title.currentEpisode ?? 1}'
                          : title.status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant, size: 36),
      );
}
