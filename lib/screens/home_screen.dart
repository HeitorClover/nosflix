import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_theme.dart';
import '../core/news.dart';
import '../data/titles_repository.dart';
import '../models/audience.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';
import '../widgets/title_card.dart';
import 'add_title_screen.dart';
import 'movie_night_screen.dart';
import 'notifications_screen.dart';
import 'stats_screen.dart';
import 'title_detail_screen.dart';

enum _HomeFilter {
  all(Icons.apps_rounded),
  wishTogether(Icons.bookmark_add_outlined),
  myWishes(Icons.bookmark_outline_rounded),
  otherWishes(Icons.bookmark_outline_rounded),
  watchingTogether(Icons.play_circle_outline),
  watchingMe(Icons.person_rounded),
  watchingOther(Icons.person_outline_rounded),
  watchedTogether(Icons.favorite),
  watchedMe(Icons.person_rounded),
  watchedOther(Icons.person_outline_rounded),
  recommendedByMe(Icons.campaign_outlined),
  recommendedToMe(Icons.card_giftcard_rounded);

  final IconData icon;
  const _HomeFilter(this.icon);

  String labelFor(Profile me) {
    final other = me == Profile.heitor ? Profile.leticia : Profile.heitor;
    return switch (this) {
      _HomeFilter.all => 'Tudo',
      _HomeFilter.wishTogether => 'Ver juntos',
      _HomeFilter.myWishes => 'Meus desejos',
      _HomeFilter.otherWishes => 'Desejos de ${other.displayName}',
      _HomeFilter.watchingTogether => 'Assistindo juntos',
      _HomeFilter.watchingMe => 'Só eu assisto',
      _HomeFilter.watchingOther => '${other.displayName} assiste',
      _HomeFilter.watchedTogether => 'Já vimos juntos',
      _HomeFilter.watchedMe => 'Só eu vi',
      _HomeFilter.watchedOther => '${other.displayName} viu',
      _HomeFilter.recommendedByMe => 'Recomendei',
      _HomeFilter.recommendedToMe => 'Pra mim',
    };
  }

  bool matches(TitleModel t, Profile me) {
    final other = me == Profile.heitor ? Profile.leticia : Profile.heitor;
    final wish = t.status == WatchStatus.queroVer;
    final watching = t.status == WatchStatus.assistindo;
    final done = t.status == WatchStatus.assistidoJuntos;
    return switch (this) {
      _HomeFilter.all => true,
      _HomeFilter.wishTogether => wish && t.audience == Audience.juntos,
      _HomeFilter.myWishes => wish && t.audience == AudienceX.solo(me),
      _HomeFilter.otherWishes => wish && t.audience == AudienceX.solo(other),
      _HomeFilter.watchingTogether => watching && t.audience == Audience.juntos,
      _HomeFilter.watchingMe => watching && t.audience == AudienceX.solo(me),
      _HomeFilter.watchingOther => watching && t.audience == AudienceX.solo(other),
      _HomeFilter.watchedTogether => done && t.audience == Audience.juntos,
      _HomeFilter.watchedMe => done && t.audience == AudienceX.solo(me),
      _HomeFilter.watchedOther => done && t.audience == AudienceX.solo(other),
      _HomeFilter.recommendedByMe => t.status == WatchStatus.recomendo && t.recommendedBy == me.name,
      _HomeFilter.recommendedToMe => t.status == WatchStatus.recomendo && t.recommendedBy != me.name,
    };
  }
}

enum _Sort {
  recent('Mais recentes', Icons.schedule_rounded),
  rating('Melhor nota', Icons.star_rounded),
  alphabetical('A–Z', Icons.sort_by_alpha_rounded),
  year('Ano', Icons.calendar_month_rounded);

  final String label;
  final IconData icon;
  const _Sort(this.label, this.icon);
}

double _averageRating(String titleId, List<RatingModel> ratings) {
  final values = [
    for (final r in ratings)
      if (r.titleId == titleId && r.rating != null) r.rating!,
  ];
  return values.isEmpty ? -1 : values.reduce((a, b) => a + b) / values.length;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeFilter _filter = _HomeFilter.all;
  TitleCategory? _category;
  _Sort _sort = _Sort.recent;
  PushStatus _pushStatus = PushStatus.unsupported;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _pushStatus = PushService.status();
    final profile = ref.read(profileProvider).profile;
    if (profile != null) PushService.syncIfGranted(profile);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAlerts() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (mounted) setState(() => _pushStatus = PushService.status());
  }

  void _open(TitleModel title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TitleDetailScreen(title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).profile ?? Profile.leticia;
    final titlesAsync = ref.watch(titlesProvider);

    final all = titlesAsync.valueOrNull ?? const <TitleModel>[];

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _NavBar(
        onAdd: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTitleScreen())),
        onNight: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MovieNightScreen())),
        onStats: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
        onAlerts: _openAlerts,
      ),
      body: AppBackground(
        photo: BackdropPhoto.home,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                profile: profile,
                pushStatus: _pushStatus,
                onBell: _openAlerts,
                onSwitch: () => ref.read(profileProvider.notifier).signOut(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        radius: 20,
                        padding: EdgeInsets.zero,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar no catálogo...',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _FilterButton(
                      active: _category != null || _sort != _Sort.recent,
                      onTap: _openFilters,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 62,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    for (final f in _HomeFilter.values) _pill(f, all),
                  ],
                ),
              ),
              if (TitlesRepository.lastFetchWasOffline)
                const _OfflineBanner(),
              Expanded(
                child: titlesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => _ErrorState(
                    message: err.toString(),
                    onRetry: () => ref.read(titlesProvider.notifier).refresh(),
                  ),
                  data: _buildContent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilters() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SectionTitle('Ordenar por'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in _Sort.values)
                      ChoicePill(
                        label: o.label,
                        icon: o.icon,
                        selected: _sort == o,
                        onTap: () {
                          setState(() => _sort = o);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionTitle('Categoria'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoicePill(
                      label: 'Todas',
                      selected: _category == null,
                      onTap: () {
                        setState(() => _category = null);
                        setSheet(() {});
                      },
                    ),
                    for (final c in TitleCategory.values)
                      ChoicePill(
                        label: c.label,
                        icon: c.icon,
                        selected: _category == c,
                        onTap: () {
                          setState(() => _category = c);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(_HomeFilter filter, List<TitleModel> all) {
    final me = ref.read(profileProvider).profile ?? Profile.leticia;
    final count = filter == _HomeFilter.all ? null : all.where((t) => filter.matches(t, me)).length;
    if (count == 0 && _filter != filter && filter != _HomeFilter.wishTogether && filter != _HomeFilter.watchingTogether && filter != _HomeFilter.watchedTogether) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoicePill(
        label: count == null || count == 0 ? filter.labelFor(me) : '${filter.labelFor(me)} · $count',
        icon: filter.icon,
        selected: _filter == filter,
        onTap: () => setState(() => _filter = filter),
      ),
    );
  }

  Widget _buildContent(List<TitleModel> titles) {
    final me = ref.read(profileProvider).profile ?? Profile.leticia;
    var filtered = titles
        .where((t) => _filter.matches(t, me) && (_category == null || t.category == _category))
        .toList();
    final hasQuery = _query.trim().isNotEmpty;
    if (hasQuery) {
      final q = _query.trim().toLowerCase();
      filtered = filtered
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.originalTitle?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (filtered.isEmpty) return const _EmptyState();

    final ratings = ref.watch(allRatingsProvider).valueOrNull ?? const <RatingModel>[];
    switch (_sort) {
      case _Sort.recent:
        break; // já vem por updated_at desc
      case _Sort.rating:
        final scores = {for (final t in filtered) t.id: _averageRating(t.id, ratings)};
        filtered.sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
      case _Sort.alphabetical:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Sort.year:
        filtered.sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));
    }

    int audienceOrder(TitleModel t) => t.audience == Audience.juntos ? 0 : (t.audience == AudienceX.solo(me) ? 1 : 2);
    final watching = titles.where((t) => t.status == WatchStatus.assistindo).toList()
      ..sort((a, b) => audienceOrder(a).compareTo(audienceOrder(b)));
    final mainPicks = ref.watch(mainTitlesProvider).valueOrNull ?? const [];
    final mainId = mainPicks.where((m) => m.owner == me.name).firstOrNull?.titleId;
    final mainTitle = titles
        .where((t) => t.id == mainId && t.status == WatchStatus.assistindo && (t.audience.profile ?? me) == me)
        .firstOrNull;
    final news = ref.watch(newsProvider).valueOrNull ?? const <NewsItem>[];
    final showNews = _filter == _HomeFilter.all && !hasQuery && news.isNotEmpty;
    final showContinue = _filter == _HomeFilter.all && !hasQuery && watching.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => ref.read(titlesProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (mainTitle != null && _filter == _HomeFilter.all && !hasQuery)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: _MainCard(title: mainTitle, onTap: () => _open(mainTitle)),
              ),
            ),
          if (showNews)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SectionTitle('Novidades'),
                  ),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: news.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _NewsCard(item: news[i], onTap: () => _open(news[i].title)),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          if (showContinue)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SectionTitle('Continue assistindo'),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: watching.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _ContinueCard(title: watching[i], onTap: () => _open(watching[i])),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: SectionTitle('Catálogo'),
                  ),
                ],
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final avg = _averageRating(filtered[index].id, ratings);
                  return TitleCard(
                    title: filtered[index],
                    rating: avg < 0 ? null : avg,
                    onTap: () => _open(filtered[index]),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Profile profile;
  final PushStatus pushStatus;
  final VoidCallback onBell;
  final VoidCallback onSwitch;
  const _Header({
    required this.profile,
    required this.pushStatus,
    required this.onBell,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wordmark(
                size: 36,
                gradient: LinearGradient(colors: [Colors.white, profile.lightColor]),
              ),
              const SizedBox(height: 4),
              Text(
                'Oi, ${profile.displayName}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          if (pushStatus != PushStatus.unsupported)
            IconButton(
              tooltip: switch (pushStatus) {
                PushStatus.on => 'Notificações ativadas',
                PushStatus.blocked => 'Notificações bloqueadas',
                _ => 'Ativar notificações',
              },
              icon: Icon(
                switch (pushStatus) {
                  PushStatus.on => Icons.notifications_active_rounded,
                  PushStatus.blocked => Icons.notifications_off_outlined,
                  _ => Icons.notifications_none_rounded,
                },
                color: pushStatus == PushStatus.on ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: onBell,
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Trocar perfil',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onSwitch,
                child: ProfileAvatar(profile: profile, radius: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final TitleModel title;
  final VoidCallback onTap;
  const _ContinueCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = title.backdropUrl ?? title.posterUrl;
    final progress = progressLabel(title);
    return SizedBox(
      width: 250,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
              else
                ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1],
                    colors: [Colors.transparent, Color(0xF2000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 60,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress ?? 'Assistindo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (title.audience.profile != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: ProfileAvatar(profile: title.audience.profile!, radius: 13),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(gradient: context.nx.gradient, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.local_movies_rounded, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'Nada por aqui ainda',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Toque em "Adicionar" pra cadastrar o primeiro título!',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text('Não deu pra carregar: $message', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Filtros e ordem',
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        borderColor: active ? scheme.primary : null,
        onTap: onTap,
        child: Icon(Icons.tune_rounded, color: active ? scheme.primary : null),
      ),
    );
  }
}

/// Barra de navegação flutuante. Fundo quase opaco e borda na cor do perfil,
/// pra não se confundir com o conteúdo que passa por baixo.
class _NavBar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onNight;
  final VoidCallback onStats;
  final VoidCallback onAlerts;
  const _NavBar({required this.onAdd, required this.onNight, required this.onStats, required this.onAlerts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(scheme.surfaceContainerHigh, Colors.black, 0.35)!.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.45), width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 28, offset: const Offset(0, 8)),
                  BoxShadow(color: scheme.primary.withValues(alpha: 0.18), blurRadius: 24),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _NavItem(icon: Icons.home_rounded, label: 'Início', selected: true, onTap: () {})),
                    Expanded(child: _NavItem(icon: Icons.theaters_rounded, label: 'Noite', selected: false, onTap: onNight)),
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: context.nx.gradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.6),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                    Expanded(child: _NavItem(icon: Icons.favorite_rounded, label: 'Nós', selected: false, onTap: onStats)),
                    Expanded(
                      child: _NavItem(icon: Icons.notifications_rounded, label: 'Avisos', selected: false, onTap: onAlerts),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.82);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;
  const _NewsCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final poster = item.title.posterUrl;
    return SizedBox(
      width: 250,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 42,
                height: 62,
                child: poster == null
                    ? ColoredBox(color: scheme.surfaceContainerHigh)
                    : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(item.upcoming ? Icons.event_rounded : Icons.new_releases_rounded, size: 14, color: scheme.secondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: scheme.secondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text('Sem conexão: mostrando o último catálogo salvo.', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Destaque da série principal de quem está logado, no topo da home.
class _MainCard extends StatelessWidget {
  final TitleModel title;
  final VoidCallback onTap;
  const _MainCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = title.backdropUrl ?? title.posterUrl;
    final progress = progressLabel(title);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
              else
                ColoredBox(color: scheme.surfaceContainerHigh),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.25, 1],
                    colors: [Colors.transparent, context.nx.base.withValues(alpha: 0.95)],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(gradient: context.nx.gradient, borderRadius: BorderRadius.circular(999)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Sua principal', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 70,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    if (progress != null)
                      Text(
                        'Parou em $progress',
                        style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: context.nx.gradient, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ),
              Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: onTap))),
            ],
          ),
        ),
      ),
    );
  }
}
