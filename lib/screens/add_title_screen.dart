import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../data/tmdb_service.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';

class AddTitleScreen extends ConsumerStatefulWidget {
  const AddTitleScreen({super.key});

  @override
  ConsumerState<AddTitleScreen> createState() => _AddTitleScreenState();
}

class _AddTitleScreenState extends ConsumerState<AddTitleScreen> {
  final _tmdb = TmdbService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<TmdbSearchResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _tmdb.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addFromTmdb(TmdbSearchResult r) async {
    final category = await _pickCategory(r.mediaType);
    if (category == null) return;

    final profile = ref.read(profileProvider).profile;
    if (profile == null) return;

    await ref.read(titlesProvider.notifier).addTitle({
      'tmdb_id': r.id,
      'media_type': r.mediaType,
      'category': category.value,
      'title': r.title,
      'original_title': r.originalTitle,
      'poster_path': r.posterPath,
      'backdrop_path': r.backdropPath,
      'overview': r.overview,
      'release_year': r.releaseYear,
      'genres': r.genres,
      'status': WatchStatus.queroVer.value,
      'recommended_by': null,
      'added_by': profile.name,
    });

    if (mounted) Navigator.of(context).pop();
  }

  Future<TitleCategory?> _pickCategory(String mediaType) async {
    final suggestion = mediaType == 'movie' ? TitleCategory.filme : TitleCategory.serie;
    return showModalBottomSheet<TitleCategory>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SectionTitle('Isso é...'),
                ),
              ),
              for (final c in TitleCategory.values)
                ListTile(
                  leading: Icon(c.icon),
                  title: Text(c.label),
                  trailing: c == suggestion
                      ? Icon(Icons.star_rounded, size: 20, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(c),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = _tmdb.isConfigured;
    final scheme = Theme.of(context).colorScheme;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar título')),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Nome do filme, série ou desenho...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: _onChanged,
                ),
              ),
              if (!configured)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Colors.amber.withValues(alpha: 0.15),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'TMDB_API_KEY não configurada no .env — a busca automática não vai funcionar até você '
                        'colocar sua chave da TMDB (themoviedb.org/settings/api).',
                      ),
                    ),
                  ),
                ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Erro: $_error', style: TextStyle(color: scheme.error)),
                ),
              Expanded(
                child: _results.isEmpty && !_loading && _error == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasQuery ? Icons.search_off_rounded : Icons.movie_filter_rounded,
                                size: 52,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                hasQuery ? 'Nenhum resultado' : 'Busque pelo nome em português ou inglês',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _results.length,
                        itemBuilder: (context, index) => _ResultTile(
                          result: _results[index],
                          onTap: () => _addFromTmdb(_results[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final TmdbSearchResult result;
  final VoidCallback onTap;
  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = result;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 84,
                    child: r.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w154${r.posterPath}',
                            fit: BoxFit.cover,
                          )
                        : ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (r.originalTitle != null && r.originalTitle != r.title)
                        Text(
                          r.originalTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, fontStyle: FontStyle.italic),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (r.releaseYear != null) r.releaseYear.toString(),
                          r.mediaType == 'movie' ? 'Filme' : 'Série',
                        ].join(' • '),
                        style: TextStyle(color: scheme.secondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(gradient: context.nx.gradient, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
