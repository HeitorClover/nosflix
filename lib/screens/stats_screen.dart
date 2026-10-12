import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/achievements.dart';
import '../core/memories.dart';
import '../core/stats.dart';
import '../core/theme/app_theme.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = ref.watch(titlesProvider).valueOrNull ?? const [];
    final ratings = ref.watch(allRatingsProvider).valueOrNull ?? const [];
    final stats = computeStats(titles, ratings);
    final comments = ref.watch(allEpisodeCommentsProvider).valueOrNull ?? const [];
    final memories = memoriesNear(titles, ratings, DateTime.now());
    final achievements = computeAchievements(titles, ratings, comments);
    final scheme = Theme.of(context).colorScheme;
    final years = stats.watchedByYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Nós dois')),
      body: AppBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + kToolbarHeight + 12, 20, 40),
          children: [
            if (memories.isNotEmpty) ...[
              _MemoriesSection(memories: memories),
              const SizedBox(height: 28),
            ],
            _AchievementsSection(achievements: achievements),
            const SizedBox(height: 28),
            _YearReviewSection(titles: titles, ratings: ratings),
            if (yearsWithWatches(ratings).isNotEmpty) const SizedBox(height: 28),
            const SectionTitle('Catálogo'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in WatchStatus.values)
                  _StatTile(icon: s.icon, label: s.label, value: '${stats.byStatus[s]}'),
              ],
            ),
            if (years.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionTitle('Assistidos por ano'),
              const SizedBox(height: 12),
              for (final y in years)
                _Row(left: '$y', right: '${stats.watchedByYear[y]} título${stats.watchedByYear[y] == 1 ? '' : 's'}'),
            ],
            if (stats.averageByOwner.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionTitle('Nota média de cada um'),
              const SizedBox(height: 12),
              for (final p in Profile.values)
                if (stats.averageByOwner[p.name] != null)
                  _Row(
                    left: p.displayName,
                    right: '${stats.averageByOwner[p.name]!.toStringAsFixed(1)} ★',
                    color: p.seedColor,
                  ),
            ],
            if (stats.topGenres.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionTitle('Gêneros favoritos'),
              const SizedBox(height: 12),
              for (final g in stats.topGenres) _Row(left: g.key, right: '${g.value}'),
            ],
            if (stats.topRated.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionTitle('Melhor avaliados'),
              const SizedBox(height: 12),
              for (final t in stats.topRated) _Row(left: t.title.title, right: '${t.average.toStringAsFixed(1)} ★'),
            ],
            if (titles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'Cadastre títulos pra ver as estatísticas de vocês.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.secondary),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String left;
  final String right;
  final Color? color;
  const _Row({required this.left, required this.right, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(left, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(right, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

const _months = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

class _MemoriesSection extends StatelessWidget {
  final List<Memory> memories;
  const _MemoriesSection({required this.memories});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Neste dia'),
        const SizedBox(height: 12),
        for (final m in memories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              radius: 22,
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 46,
                      height: 68,
                      child: m.title.posterUrl == null
                          ? ColoredBox(color: scheme.surfaceContainerHigh)
                          : CachedNetworkImage(imageUrl: m.title.posterUrl!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.yearsAgo == 1 ? 'Há 1 ano' : 'Há ${m.yearsAgo} anos',
                          style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        Text(m.title.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(DateFormat('dd/MM/yyyy').format(m.watchedAt),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _YearReviewSection extends StatefulWidget {
  final List<TitleModel> titles;
  final List<RatingModel> ratings;
  const _YearReviewSection({required this.titles, required this.ratings});

  @override
  State<_YearReviewSection> createState() => _YearReviewSectionState();
}

class _YearReviewSectionState extends State<_YearReviewSection> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final years = yearsWithWatches(widget.ratings);
    if (years.isEmpty) return const SizedBox.shrink();
    final year = years.contains(_year) ? _year! : years.first;
    final review = yearInReview(widget.titles, widget.ratings, year);
    final scheme = Theme.of(context).colorScheme;

    Widget line(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.secondary),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Expanded(child: Text(value, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Retrospectiva'),
        const SizedBox(height: 12),
        if (years.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final y in years)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoicePill(label: '$y', selected: y == year, onTap: () => setState(() => _year = y)),
                  ),
              ],
            ),
          ),
        if (years.length > 1) const SizedBox(height: 10),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$year', style: Theme.of(context).textTheme.headlineSmall),
              Text(
                '${review.titleCount} título${review.titleCount == 1 ? '' : 's'} assistido${review.titleCount == 1 ? '' : 's'}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              if (review.busiestMonth != null) line(Icons.calendar_month_rounded, 'Mês mais movimentado', _months[review.busiestMonth! - 1]),
              if (review.topGenre != null) line(Icons.theater_comedy_rounded, 'Gênero do ano', review.topGenre!),
              if (review.bestRated != null)
                line(Icons.star_rounded, 'Melhor nota', '${review.bestRated!.title} (${review.bestRating!.toStringAsFixed(1)})'),
              if (review.first != null) line(Icons.flag_rounded, 'Primeiro do ano', review.first!.title),
              if (review.last != null && review.last!.id != review.first?.id)
                line(Icons.flag_circle_rounded, 'Mais recente', review.last!.title),
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  final List<Achievement> achievements;
  const _AchievementsSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Conquistas · $unlocked/${achievements.length}'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final width = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in achievements) SizedBox(width: width, child: _AchievementTile(a)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  const _AchievementTile(this.achievement);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = achievement;
    final color = a.unlocked ? scheme.primary : scheme.onSurfaceVariant;
    return SizedBox(
      width: 158,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(12),
        borderColor: a.unlocked ? scheme.primary.withValues(alpha: 0.7) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(a.unlocked ? a.icon : Icons.lock_outline_rounded, color: color, size: 22),
                const Spacer(),
                Text('${a.current.clamp(0, a.target)}/${a.target}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(a.title, style: TextStyle(fontWeight: FontWeight.w800, color: a.unlocked ? null : scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(a.description, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, height: 1.25)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: a.progress, minHeight: 4, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
