import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/movie_night.dart';
import '../core/theme/app_theme.dart';
import '../models/pick_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';
import 'title_detail_screen.dart';

/// Noite de cinema: sorteio da lista "ver juntos" e votação (3 escolhas cada um).
class MovieNightScreen extends ConsumerStatefulWidget {
  const MovieNightScreen({super.key});

  @override
  ConsumerState<MovieNightScreen> createState() => _MovieNightScreenState();
}

class _MovieNightScreenState extends ConsumerState<MovieNightScreen> {
  String? _mediaType; // null = tudo, 'movie', 'tv'
  TitleModel? _shown;
  bool _spinning = false;
  bool _landed = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Passa rápido por alguns títulos e para em um (sorteado antes, pra ser justo).
  void _spin(List<TitleModel> candidates) {
    final winner = drawOne(candidates);
    if (winner == null || _spinning) return;
    setState(() {
      _spinning = true;
      _landed = false;
    });
    var ticks = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      ticks++;
      if (ticks >= 16) {
        t.cancel();
        setState(() {
          _shown = winner;
          _spinning = false;
          _landed = true;
        });
        return;
      }
      setState(() => _shown = candidates[ticks % candidates.length]);
    });
  }

  void _open(TitleModel title) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TitleDetailScreen(title: title)));
  }

  Future<void> _choosePicks(List<TitleModel> pool, Profile me) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickSheet(pool: pool, me: me),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(profileProvider).profile ?? Profile.leticia;
    final other = me == Profile.heitor ? Profile.leticia : Profile.heitor;
    final titles = ref.watch(titlesProvider).valueOrNull ?? const <TitleModel>[];
    final picks = ref.watch(picksProvider).valueOrNull ?? const <PickModel>[];
    final byId = {for (final t in titles) t.id: t};
    final pool = movieNightPool(titles, mediaType: _mediaType);
    final scheme = Theme.of(context).colorScheme;

    List<TitleModel> picksOf(Profile p) => [
          for (final k in picks)
            if (k.owner == p.name && byId[k.titleId] != null) byId[k.titleId]!,
        ];
    final matches = matchingPicks(picks).map((id) => byId[id]).whereType<TitleModel>().toList();
    final allPicked = {for (final k in picks) k.titleId}.map((id) => byId[id]).whereType<TitleModel>().toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Noite de cinema')),
      body: AppBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + kToolbarHeight + 12, 20, 40),
          children: [
            const SectionTitle('Sortear'),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoicePill(label: 'Tudo', selected: _mediaType == null, onTap: () => setState(() => _mediaType = null)),
                      ChoicePill(
                        label: 'Filmes',
                        icon: Icons.movie_outlined,
                        selected: _mediaType == 'movie',
                        onTap: () => setState(() => _mediaType = 'movie'),
                      ),
                      ChoicePill(
                        label: 'Séries',
                        icon: Icons.tv_outlined,
                        selected: _mediaType == 'tv',
                        onTap: () => setState(() => _mediaType = 'tv'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_shown != null)
                    _DrawnCard(title: _shown!, landed: _landed, onOpen: () => _open(_shown!))
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          pool.isEmpty
                              ? 'Nenhum título na lista "Ver juntos" com esse filtro.'
                              : '${pool.length} título${pool.length == 1 ? '' : 's'} esperando vocês.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: pool.isEmpty || _spinning ? null : () => _spin(pool),
                      icon: const Icon(Icons.casino_rounded),
                      label: Text(_shown == null ? 'Sortear o que vemos hoje' : 'Sortear de novo'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Votação'),
            const SizedBox(height: 4),
            Text(
              'Cada um escolhe até $maxPicksPerPerson títulos da lista "Ver juntos".',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _PicksRow(profile: me, titles: picksOf(me), onTap: _open, onEdit: () => _choosePicks(movieNightPool(titles), me)),
            const SizedBox(height: 12),
            _PicksRow(profile: other, titles: picksOf(other), onTap: _open),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 16),
              GlassCard(
                borderColor: scheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: scheme.primary, size: 18),
                        const SizedBox(width: 8),
                        const Text('Vocês combinaram!', style: TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final t in matches)
                      InkWell(
                        onTap: () => _open(t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(t.title, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: allPicked.isEmpty || _spinning ? null : () => _spin(matches.isNotEmpty ? matches : allPicked),
              icon: const Icon(Icons.casino_rounded),
              label: Text(matches.isNotEmpty ? 'Sortear entre as combinadas' : 'Sortear entre as escolhas'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: picks.isEmpty ? null : () => ref.read(titlesRepositoryProvider).clearPicks(),
              child: const Text('Nova votação'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawnCard extends StatelessWidget {
  final TitleModel title;
  final bool landed;
  final VoidCallback onOpen;
  const _DrawnCard({required this.title, required this.landed, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: landed ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: landed ? scheme.primary : Colors.white12, width: landed ? 1.5 : 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 70,
              height: 105,
              child: title.posterUrl == null
                  ? ColoredBox(color: scheme.surfaceContainerHigh)
                  : CachedNetworkImage(imageUrl: title.posterUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (landed)
                  Text('Hoje vocês vão ver', style: TextStyle(color: scheme.secondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(title.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  [if (title.releaseYear != null) '${title.releaseYear}', title.category.label].join(' · '),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                ),
                if (landed)
                  TextButton(onPressed: onOpen, child: const Text('Abrir')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PicksRow extends StatelessWidget {
  final Profile profile;
  final List<TitleModel> titles;
  final void Function(TitleModel) onTap;
  final VoidCallback? onEdit;
  const _PicksRow({required this.profile, required this.titles, required this.onTap, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(12),
      borderColor: profile.seedColor.withValues(alpha: 0.35),
      child: Row(
        children: [
          ProfileAvatar(profile: profile, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: titles.isEmpty
                ? Text(
                    onEdit == null ? 'Ainda não escolheu' : 'Escolha seus favoritos',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                : Wrap(
                    spacing: 8,
                    children: [
                      for (final t in titles)
                        GestureDetector(
                          onTap: () => onTap(t),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 66,
                              child: t.posterUrl == null
                                  ? ColoredBox(color: scheme.surfaceContainerHigh)
                                  : CachedNetworkImage(imageUrl: t.posterUrl!, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Escolher',
              icon: Icon(titles.isEmpty ? Icons.add_circle_rounded : Icons.edit_rounded, color: scheme.primary),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}

class _PickSheet extends ConsumerWidget {
  final List<TitleModel> pool;
  final Profile me;
  const _PickSheet({required this.pool, required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(picksProvider).valueOrNull ?? const <PickModel>[];
    final mine = {for (final p in picks) if (p.owner == me.name) p.titleId};
    final repo = ref.read(titlesRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Escolha até $maxPicksPerPerson  ·  ${mine.length}/$maxPicksPerPerson', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Flexible(
                child: pool.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Não há títulos na lista "Ver juntos".'),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 120,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: pool.length,
                        itemBuilder: (context, i) {
                          final t = pool[i];
                          final selected = mine.contains(t.id);
                          final full = mine.length >= maxPicksPerPerson;
                          return GestureDetector(
                            onTap: () {
                              if (selected) {
                                repo.removePick(owner: me.name, titleId: t.id);
                              } else if (!full) {
                                repo.addPick(owner: me.name, titleId: t.id);
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: t.posterUrl == null
                                      ? ColoredBox(color: scheme.surfaceContainerHigh)
                                      : CachedNetworkImage(imageUrl: t.posterUrl!, fit: BoxFit.cover),
                                ),
                                if (selected)
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: scheme.primary.withValues(alpha: 0.35),
                                      border: Border.all(color: scheme.primary, width: 2),
                                    ),
                                    child: const Center(child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 30)),
                                  )
                                else if (full)
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: Colors.black.withValues(alpha: 0.55),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
