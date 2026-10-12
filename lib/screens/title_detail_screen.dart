import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_theme.dart';
import '../data/titles_repository.dart';
import '../data/tmdb_service.dart';
import '../models/audience.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/tv_models.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';
import 'episodes_section.dart';

RatingModel? _findRating(List<RatingModel> ratings, Profile owner) {
  for (final r in ratings) {
    if (r.owner == owner.name) return r;
  }
  return null;
}

class TitleDetailScreen extends ConsumerWidget {
  final TitleModel initialTitle;
  const TitleDetailScreen({super.key, required TitleModel title}) : initialTitle = title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(titlesProvider).valueOrNull?.firstWhere(
              (t) => t.id == initialTitle.id,
              orElse: () => initialTitle,
            ) ??
        initialTitle;
    final ratingsAsync = ref.watch(ratingsForTitleProvider(title.id));
    final profile = ref.watch(profileProvider).profile;
    final scheme = Theme.of(context).colorScheme;
    final heroImage = title.backdropUrl ?? title.posterUrl;

    return Scaffold(
      body: AppBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              backgroundColor: context.nx.base,
              leading: GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                GlassIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Remover',
                  onPressed: () => _confirmDelete(context, ref),
                ),
                const SizedBox(width: 6),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: heroImage == null
                    ? Container(color: scheme.surfaceContainerHigh)
                    : ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 1],
                          colors: [Colors.black, Colors.transparent],
                        ).createShader(rect),
                        child: CachedNetworkImage(
                          imageUrl: heroImage,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title.posterUrl != null) ...[
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 24),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: SizedBox(
                                    width: 108,
                                    height: 162,
                                    child: CachedNetworkImage(imageUrl: title.posterUrl!, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title.title, style: Theme.of(context).textTheme.headlineSmall),
                                  if (title.originalTitle != null && title.originalTitle != title.title)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        title.originalTitle!,
                                        style: TextStyle(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (title.releaseYear != null) _MetaPill('${title.releaseYear}'),
                            _MetaPill(title.category.label, icon: title.category.icon, highlight: true),
                            for (final g in title.genres.take(3)) _MetaPill(g),
                          ],
                        ),
                        if (title.tmdbId != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _TrailerButton(tmdbId: title.tmdbId!, mediaType: title.mediaType),
                              if (title.mediaType == 'movie') _CollectionButton(title: title, profile: profile),
                            ],
                          ),
                          if (title.mediaType == 'tv') _AirInfoLine(tmdbId: title.tmdbId!),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: _StatusSelector(title: title, profile: profile),
                          ),
                        ),
                        if (title.status == WatchStatus.queroVer ||
                            title.status == WatchStatus.assistindo ||
                            title.status == WatchStatus.assistidoJuntos)
                          _AudienceSelector(title: title, profile: profile),
                        if (title.status == WatchStatus.assistindo && title.mediaType == 'tv')
                          ProgressCard(key: ValueKey(title.id), title: title, profile: profile),
                        if (title.status == WatchStatus.recomendo && title.recommendedBy != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              children: [
                                Icon(Icons.campaign_rounded, size: 18, color: scheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Indicação de ${title.recommendedBy == 'heitor' ? 'Heitor' : 'Leticia'}',
                                  style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        if (title.overview != null && title.overview!.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionTitle('Sinopse'),
                                const SizedBox(height: 10),
                                Text(
                                  title.overview!,
                                  style: TextStyle(
                                    color: scheme.onSurface.withValues(alpha: 0.85),
                                    height: 1.5,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (title.tmdbId != null) ...[
                          const SizedBox(height: 28),
                          _WhereToWatch(tmdbId: title.tmdbId!, mediaType: title.mediaType),
                        ],
                        if (title.mediaType == 'tv' && title.status != WatchStatus.queroVer) ...[
                          const SizedBox(height: 28),
                          GlassCard(
                            child: EpisodesSection(key: ValueKey('eps-${title.id}'), title: title, profile: profile),
                          ),
                        ],
                        const SizedBox(height: 28),
                        const SectionTitle('Avaliações'),
                        const SizedBox(height: 12),
                        ratingsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('Erro ao carregar avaliações: $e'),
                          data: (ratings) => Column(
                            children: [
                              for (final p in Profile.values)
                                _RatingCard(
                                  titleId: title.id,
                                  owner: p,
                                  existing: _findRating(ratings, p),
                                  editable: profile == p,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Adicionado por ${title.addedBy == 'heitor' ? 'Heitor' : 'Leticia'} em '
                            '${DateFormat('dd/MM/yyyy').format(title.createdAt)}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover título?'),
        content: Text('Isso vai apagar "${initialTitle.title}" e as avaliações de vocês dois.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(titlesProvider.notifier).deleteTitle(initialTitle.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _MetaPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool highlight;
  const _MetaPill(this.text, {this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlight ? scheme.secondary : scheme.onSurface.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _StatusSelector extends ConsumerWidget {
  final TitleModel title;
  final Profile? profile;
  const _StatusSelector({required this.title, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in WatchStatus.values)
          ChoicePill(
            icon: s.icon,
            label: s.label,
            selected: title.status == s,
            onTap: () async {
              final recommendedBy = s == WatchStatus.recomendo ? profile?.name : null;
              final newRecommendation = s == WatchStatus.recomendo && title.status != s;
              await ref.read(titlesProvider.notifier).updateStatus(
                    title.id,
                    s.value,
                    recommendedBy: recommendedBy,
                  );
              if (newRecommendation && profile != null) {
                // Sem await: o aviso segue em segundo plano.
                PushService.notifyRecommendation(titleId: title.id, from: profile!);
              }
            },
          ),
      ],
    );
  }
}

class _WhereToWatch extends ConsumerWidget {
  final int tmdbId;
  final String mediaType;
  const _WhereToWatch({required this.tmdbId, required this.mediaType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(watchProvidersProvider((tmdbId: tmdbId, mediaType: mediaType))).valueOrNull;
    if (providers == null || providers.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget group(String label, List<WatchProvider> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: muted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in list.take(8))
                  Tooltip(
                    message: p.name,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: p.logoUrl == null
                          ? _MetaPill(p.name)
                          : CachedNetworkImage(imageUrl: p.logoUrl!, width: 44, height: 44),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Onde assistir'),
            group('Streaming', providers.stream),
            group('Alugar', providers.rent),
            group('Comprar', providers.buy),
            const SizedBox(height: 8),
            Text('Dados: JustWatch', style: TextStyle(color: muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _RatingCard extends ConsumerStatefulWidget {
  final String titleId;
  final Profile owner;
  final RatingModel? existing;
  final bool editable;

  const _RatingCard({
    required this.titleId,
    required this.owner,
    required this.existing,
    required this.editable,
  });

  @override
  ConsumerState<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends ConsumerState<_RatingCard> {
  late final TitlesRepository _repo = ref.read(titlesRepositoryProvider);
  late double _rating;
  late TextEditingController _commentController;
  DateTime? _watchedAt;
  bool _saving = false;
  bool _dirty = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 0;
    _commentController = TextEditingController(text: widget.existing?.comment ?? '');
    _watchedAt = widget.existing?.watchedAt;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Não perde o que foi digitado se a pessoa sair da tela sem tocar fora.
    if (_dirty) _persist();
    _commentController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _persist() {
    _dirty = false;
    final comment = _commentController.text.trim();
    return _repo.upsertRating(RatingModel(
      id: widget.existing?.id ?? '',
      titleId: widget.titleId,
      owner: widget.owner.name,
      rating: _rating == 0 ? null : _rating,
      comment: comment.isEmpty ? null : comment,
      watchedAt: _watchedAt,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    await _persist();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchedAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _watchedAt = picked);
      _scheduleSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.owner.seedColor;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Card do parceiro sempre mostra o que veio do banco (ao vivo).
    final shownRating = widget.editable ? _rating : (widget.existing?.rating ?? 0);
    final otherComment = widget.existing?.comment ?? '';
    final otherWatchedAt = widget.existing?.watchedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        borderColor: color.withValues(alpha: widget.editable ? 0.55 : 0.18),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(profile: widget.owner, radius: 14),
              const SizedBox(width: 10),
              Text(widget.owner.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (widget.editable) ...[
                const SizedBox(width: 8),
                Text('você', style: TextStyle(color: muted, fontSize: 12)),
              ],
              const Spacer(),
              if (widget.editable && _saving)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 10),
          IgnorePointer(
            ignoring: !widget.editable,
            child: Opacity(
              opacity: widget.editable ? 1 : 0.7,
              child: KeyedSubtree(
                key: ValueKey(shownRating),
                child: RatingBar.builder(
                initialRating: shownRating,
                minRating: 0,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 30,
                unratedColor: Colors.white24,
                itemBuilder: (context, _) => Icon(Icons.star_rounded, color: color),
                onRatingUpdate: (value) {
                  setState(() => _rating = value);
                  _scheduleSave();
                },
                ),
              ),
            ),
          ),
          if (widget.editable) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Escreva um comentário...', isDense: true),
              onChanged: (_) => _scheduleSave(),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      _watchedAt == null ? 'Quando assistiu?' : DateFormat('dd/MM/yyyy').format(_watchedAt!),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (otherComment.isNotEmpty || otherWatchedAt != null) ...[
            const SizedBox(height: 8),
            if (otherComment.isNotEmpty) Text(otherComment),
            if (otherWatchedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(otherWatchedAt),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
          ],
        ],
        ),
      ),
    );
  }
}

class _AudienceSelector extends ConsumerWidget {
  final TitleModel title;
  final Profile? profile;
  const _AudienceSelector({required this.title, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = profile ?? Profile.leticia;
    final isWish = title.status == WatchStatus.queroVer;
    final isDone = title.status == WatchStatus.assistidoJuntos;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isWish ? 'Quem quer ver?' : (isDone ? 'Quem viu?' : 'Quem está assistindo?'),
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in Audience.values)
                  ChoicePill(
                    label: a.labelFor(me),
                    icon: a == Audience.juntos ? Icons.favorite_rounded : Icons.person_rounded,
                    selected: title.audience == a,
                    onTap: () => ref.read(titlesProvider.notifier).updateAudience(title.id, a.value),
                  ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AirInfoLine extends ConsumerWidget {
  final int tmdbId;
  const _AirInfoLine({required this.tmdbId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(tvAirInfoProvider(tmdbId)).valueOrNull;
    if (info == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    String? text;
    if (info.nextAirDate != null) {
      text = 'Próximo episódio: T${info.nextSeason ?? 1} · E${info.nextEpisode ?? 1} '
          'em ${DateFormat('dd/MM/yyyy').format(info.nextAirDate!)}';
    } else if (info.ended) {
      text = 'Série finalizada';
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 16, color: scheme.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))),
        ],
      ),
    );
  }
}

class _TrailerButton extends ConsumerWidget {
  final int tmdbId;
  final String mediaType;
  const _TrailerButton({required this.tmdbId, required this.mediaType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(trailerKeyProvider((tmdbId: tmdbId, mediaType: mediaType))).valueOrNull;
    if (key == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () => launchUrl(
        Uri.https('www.youtube.com', '/watch', {'v': key}),
        mode: LaunchMode.externalApplication,
      ),
      icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
      label: const Text('Trailer'),
    );
  }
}

class _CollectionButton extends ConsumerWidget {
  final TitleModel title;
  final Profile? profile;
  const _CollectionButton({required this.title, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _CollectionSheet(title: title, profile: profile),
      ),
      icon: const Icon(Icons.collections_bookmark_outlined, size: 20),
      label: const Text('Ver saga'),
    );
  }
}

class _CollectionSheet extends ConsumerStatefulWidget {
  final TitleModel title;
  final Profile? profile;
  const _CollectionSheet({required this.title, required this.profile});

  @override
  ConsumerState<_CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends ConsumerState<_CollectionSheet> {
  late final Future<TmdbCollection?> _future = ref.read(tmdbServiceProvider).fetchCollection(widget.title.tmdbId!);

  Future<void> _add(TmdbSearchResult r) async {
    final profile = widget.profile;
    if (profile == null) return;
    await ref.read(titlesProvider.notifier).addTitle({
      'tmdb_id': r.id,
      'media_type': 'movie',
      'category': widget.title.category.value,
      'title': r.title,
      'original_title': r.originalTitle,
      'poster_path': r.posterPath,
      'backdrop_path': r.backdropPath,
      'overview': r.overview,
      'release_year': r.releaseYear,
      'genres': r.genres,
      'status': WatchStatus.queroVer.value,
      'audience': Audience.juntos.value,
      'added_by': profile.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inCatalog = {
      for (final t in ref.watch(titlesProvider).valueOrNull ?? const <TitleModel>[])
        if (t.tmdbId != null && t.mediaType == 'movie') t.tmdbId!,
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: FutureBuilder<TmdbCollection?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
            }
            final collection = snap.data;
            if (collection == null) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Este filme não faz parte de uma saga.', textAlign: TextAlign.center),
              );
            }
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                SectionTitle(collection.name),
                const SizedBox(height: 12),
                for (final part in collection.parts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: part.posterPath == null
                          ? const SizedBox(width: 40, height: 60)
                          : CachedNetworkImage(
                              imageUrl: 'https://image.tmdb.org/t/p/w154${part.posterPath}',
                              width: 40,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                    ),
                    title: Text(part.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: part.releaseYear == null ? null : Text('${part.releaseYear}'),
                    trailing: inCatalog.contains(part.id)
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : IconButton(
                            tooltip: 'Adicionar ao catálogo',
                            icon: Icon(Icons.add_circle_rounded, color: scheme.primary),
                            onPressed: () => _add(part),
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
