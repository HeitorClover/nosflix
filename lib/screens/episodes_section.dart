import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_theme.dart';
import '../data/titles_repository.dart';
import '../models/audience.dart';
import '../models/episode_comment_model.dart';
import '../models/pick_model.dart';
import '../models/title_model.dart';
import '../models/tv_models.dart';
import '../models/watch_status.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';

int _lastSeason(List<TvSeason> seasons) => seasons.map((s) => s.number).reduce((a, b) => a > b ? a : b);

/// "Onde paramos": contador de temporada/episódio, botão de avançar e
/// atalho para comentar o episódio atual.
class ProgressCard extends ConsumerStatefulWidget {
  final TitleModel title;
  final Profile? profile;
  const ProgressCard({super.key, required this.title, required this.profile});

  @override
  ConsumerState<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends ConsumerState<ProgressCard> {
  late int _season;
  late int _episode;

  @override
  void initState() {
    super.initState();
    _season = widget.title.currentSeason ?? 1;
    _episode = widget.title.currentEpisode ?? 1;
  }

  Future<void> _goTo(int season, int episode) async {
    setState(() {
      _season = season;
      _episode = episode;
    });
    await ref.read(titlesProvider.notifier).updateProgress(widget.title.id, season: season, episode: episode);
  }

  void _changeSeason(int delta, List<TvSeason> seasons) {
    var next = (_season + delta).clamp(1, 999);
    if (seasons.isNotEmpty) next = next.clamp(1, _lastSeason(seasons));
    if (next != _season) _goTo(next, 1);
  }

  void _changeEpisode(int delta, List<TvSeason> seasons) {
    var next = (_episode + delta).clamp(1, 9999);
    final max = episodeCountOf(seasons, _season);
    if (max != null && max > 0) next = next.clamp(1, max);
    if (next != _episode) _goTo(_season, next);
  }

  Future<void> _watchedThis(List<TvSeason> seasons) async {
    final next = nextEpisode(seasons, _season, _episode);
    if (next != null) {
      await _goTo(next.season, next.episode);
      // Quem assiste sozinho(a) avisa o outro de onde parou.
      final me = widget.profile;
      if (me != null && widget.title.audience == AudienceX.solo(me)) {
        PushService.notifyProgress(titleId: widget.title.id, from: me);
      }
      return;
    }
    // Era o último episódio da série.
    await ref.read(titlesProvider.notifier).updateStatus(widget.title.id, WatchStatus.assistidoJuntos.value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fim da série! Movida para "Já vimos juntos".')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tmdbId = widget.title.tmdbId;
    final seasons = tmdbId == null ? const <TvSeason>[] : ref.watch(tvSeasonsProvider(tmdbId)).valueOrNull ?? const [];
    final maxEpisode = episodeCountOf(seasons, _season);
    final knowsEpisodes = maxEpisode != null && maxEpisode > 0;
    final isLast = seasons.isNotEmpty && nextEpisode(seasons, _season, _episode) == null;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.22), scheme.primary.withValues(alpha: 0.05)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 18, color: scheme.secondary),
              const SizedBox(width: 8),
              Text('Onde paramos', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.secondary)),
              const Spacer(),
              _MainToggle(title: widget.title, profile: widget.profile),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Stepper(
                  label: 'Temporada',
                  value: _season,
                  onChange: (d) => _changeSeason(d, seasons),
                  canIncrease: seasons.isEmpty || _season < _lastSeason(seasons),
                ),
              ),
              Container(width: 1, height: 64, color: Colors.white12),
              Expanded(
                child: _Stepper(
                  label: knowsEpisodes ? 'Episódio (de $maxEpisode)' : 'Episódio',
                  value: _episode,
                  onChange: (d) => _changeEpisode(d, seasons),
                  canIncrease: !knowsEpisodes || _episode < maxEpisode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _watchedThis(seasons),
                  icon: Icon(isLast ? Icons.flag_rounded : Icons.skip_next_rounded),
                  label: Text(isLast ? 'Terminamos a série' : 'Vimos! Próximo'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.profile == null
                    ? null
                    : () => showEpisodeSheet(
                          context,
                          title: widget.title,
                          profile: widget.profile!,
                          season: _season,
                          episode: _episode,
                        ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Comentar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int delta) onChange;
  final bool canIncrease;
  const _Stepper({required this.label, required this.value, required this.onChange, required this.canIncrease});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: value > 1 ? () => onChange(-1) : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_rounded, color: canIncrease ? scheme.primary : null),
              onPressed: canIncrease ? () => onChange(1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Lista de episódios por temporada, mostrando quem já comentou cada um.
class EpisodesSection extends ConsumerStatefulWidget {
  final TitleModel title;
  final Profile? profile;
  const EpisodesSection({super.key, required this.title, required this.profile});

  @override
  ConsumerState<EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends ConsumerState<EpisodesSection> {
  late int _season = widget.title.currentSeason ?? 1;

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final tmdbId = title.tmdbId;
    final comments = ref.watch(episodeCommentsProvider(title.id)).valueOrNull ?? const <EpisodeCommentModel>[];
    final seasons = tmdbId == null ? const <TvSeason>[] : ref.watch(tvSeasonsProvider(tmdbId)).valueOrNull ?? const [];
    final episodesAsync = tmdbId == null || seasons.isEmpty
        ? null
        : ref.watch(tvEpisodesProvider((tmdbId: tmdbId, season: _season)));
    final tmdbEpisodes = episodesAsync?.valueOrNull ?? const <TvEpisode>[];

    final seasonNumbers = seasons.isNotEmpty
        ? seasons.map((s) => s.number).toList()
        : ({...comments.map((c) => c.season), title.currentSeason ?? 1}.toList()..sort());

    // Sem dados da TMDB, lista só os episódios que têm comentário (+ o atual).
    final episodeNumbers = tmdbEpisodes.isNotEmpty
        ? tmdbEpisodes.map((e) => e.number).toList()
        : ({
            ...comments.where((c) => c.season == _season).map((c) => c.episode),
            if (_season == (title.currentSeason ?? 1)) title.currentEpisode ?? 1,
          }.toList()
          ..sort());
    final names = {for (final e in tmdbEpisodes) e.number: e.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Episódios'),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final n in seasonNumbers)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoicePill(label: 'T$n', selected: _season == n, onTap: () => setState(() => _season = n)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (episodesAsync != null && episodesAsync.isLoading && tmdbEpisodes.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else
          for (final ep in episodeNumbers)
            _EpisodeTile(
              number: ep,
              name: names[ep],
              comments: comments.where((c) => c.season == _season && c.episode == ep).toList(),
              onTap: widget.profile == null
                  ? null
                  : () => showEpisodeSheet(
                        context,
                        title: title,
                        profile: widget.profile!,
                        season: _season,
                        episode: ep,
                        episodeName: names[ep],
                      ),
            ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final int number;
  final String? name;
  final List<EpisodeCommentModel> comments;
  final VoidCallback? onTap;
  const _EpisodeTile({required this.number, required this.name, required this.comments, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text('$number', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(name ?? 'Episódio $number', maxLines: 2, overflow: TextOverflow.ellipsis)),
            for (final p in Profile.values)
              if (comments.any((c) => c.owner == p.name))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: CircleAvatar(radius: 5, backgroundColor: p.seedColor),
                ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: comments.isEmpty ? 'Comentar este episódio' : 'Ver e editar comentários',
              visualDensity: VisualDensity.compact,
              onPressed: onTap,
              icon: Badge(
                isLabelVisible: comments.isNotEmpty,
                label: Text('${comments.length}'),
                child: Icon(
                  comments.isEmpty ? Icons.add_comment_outlined : Icons.chat_bubble_rounded,
                  color: comments.isEmpty ? scheme.onSurfaceVariant : scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showEpisodeSheet(
  BuildContext context, {
  required TitleModel title,
  required Profile profile,
  required int season,
  required int episode,
  String? episodeName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EpisodeSheet(
      title: title,
      profile: profile,
      season: season,
      episode: episode,
      episodeName: episodeName,
    ),
  );
}

class _EpisodeSheet extends ConsumerStatefulWidget {
  final TitleModel title;
  final Profile profile;
  final int season;
  final int episode;
  final String? episodeName;
  const _EpisodeSheet({
    required this.title,
    required this.profile,
    required this.season,
    required this.episode,
    required this.episodeName,
  });

  @override
  ConsumerState<_EpisodeSheet> createState() => _EpisodeSheetState();
}

class _EpisodeSheetState extends ConsumerState<_EpisodeSheet> {
  late final TitlesRepository _repo = ref.read(titlesRepositoryProvider);
  final _controller = TextEditingController();
  Timer? _debounce;
  String _saved = '';
  bool _seeded = false;
  bool _revealed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _flush();
    _controller.dispose();
    super.dispose();
  }

  void _flush() {
    final text = _controller.text.trim();
    if (!_seeded || text == _saved) return;
    final isNew = _saved.isEmpty && text.isNotEmpty;
    _saved = text;
    final titleId = widget.title.id;
    final profile = widget.profile;
    final season = widget.season;
    final episode = widget.episode;
    _repo
        .saveEpisodeComment(titleId: titleId, owner: profile.name, season: season, episode: episode, comment: text)
        .then((_) {
      // Só avisa no primeiro comentário do episódio, pra não virar spam.
      if (isNew) PushService.notifyEpisodeComment(titleId: titleId, from: profile, season: season, episode: episode);
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _flush);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.title;
    final comments = ref.watch(episodeCommentsProvider(title.id)).valueOrNull;
    final here = (comments ?? const <EpisodeCommentModel>[])
        .where((c) => c.season == widget.season && c.episode == widget.episode);
    final mine = here.where((c) => c.owner == widget.profile.name).firstOrNull;

    // Preenche o campo uma vez, quando o comentário existente chegar.
    if (!_seeded && comments != null) {
      _seeded = true;
      _saved = mine?.comment ?? '';
      _controller.text = _saved;
    }

    final other = Profile.values.firstWhere((p) => p != widget.profile);
    final theirs = here.where((c) => c.owner == other.name).firstOrNull;
    final hidden = theirs != null &&
        !_revealed &&
        isSpoilerHidden(
          status: title.status,
          currentSeason: title.currentSeason,
          currentEpisode: title.currentEpisode,
          season: widget.season,
          episode: widget.episode,
          viewerInAudience: title.audience.profile == null || title.audience.profile == widget.profile,
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'T${widget.season} · E${widget.episode}',
              style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w700),
            ),
            Text(widget.episodeName ?? title.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                ProfileAvatar(profile: widget.profile, radius: 12),
                const SizedBox(width: 8),
                Text('Seu comentário', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: _seeded,
              minLines: 2,
              maxLines: 6,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'O que achou deste episódio?'),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                ProfileAvatar(profile: other, radius: 12),
                const SizedBox(width: 8),
                Text(other.displayName, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            if (theirs == null)
              Text('Ainda sem comentário.', style: TextStyle(color: scheme.onSurfaceVariant))
            else if (hidden)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _revealed = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Expanded(child: Text('Escondido pra não dar spoiler. Toque pra ver mesmo assim.')),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: other.seedColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(theirs.comment),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estrela "Principal": marca esta série como a principal de quem está logado.
class _MainToggle extends ConsumerWidget {
  final TitleModel title;
  final Profile? profile;
  const _MainToggle({required this.title, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = profile;
    if (me == null) return const SizedBox.shrink();
    // Série só do outro não pode ser a sua principal.
    final owner = title.audience.profile;
    if (owner != null && owner != me) return const SizedBox.shrink();

    final mains = ref.watch(mainTitlesProvider).valueOrNull ?? const <PickModel>[];
    final isMain = mains.any((m) => m.owner == me.name && m.titleId == title.id);
    final repo = ref.read(titlesRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      onPressed: () => isMain
          ? repo.clearMainTitle(me.name)
          : repo.setMainTitle(owner: me.name, titleId: title.id),
      icon: Icon(isMain ? Icons.star_rounded : Icons.star_border_rounded, size: 20, color: scheme.secondary),
      label: Text(isMain ? 'Principal' : 'Tornar principal'),
    );
  }
}
