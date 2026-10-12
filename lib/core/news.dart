import '../models/title_model.dart';
import '../models/tv_models.dart';
import '../models/watch_status.dart';

/// Novidade de uma série que o casal acompanha (episódio ou temporada nova).
class NewsItem {
  final TitleModel title;
  final String text;
  final DateTime date;
  final bool upcoming;
  const NewsItem({required this.title, required this.text, required this.date, required this.upcoming});
}

String _day(DateTime date, DateTime today) {
  final diff = DateTime(date.year, date.month, date.day).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'hoje';
  if (diff == 1) return 'amanhã';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return 'em $d/$m';
}

/// Novidade de [title] com base nos dados da TMDB, ou `null` se não há nada
/// relevante: só conta episódio nos próximos 45 dias ou temporada lançada nos
/// últimos 30 dias que ainda não foi vista.
NewsItem? newsFor(TitleModel title, TvAirInfo info, DateTime now) {
  if (title.mediaType != 'tv') return null;
  if (title.status != WatchStatus.assistindo && title.status != WatchStatus.assistidoJuntos) return null;
  final today = DateTime(now.year, now.month, now.day);

  final next = info.nextAirDate;
  if (next != null) {
    final days = DateTime(next.year, next.month, next.day).difference(today).inDays;
    if (days >= 0 && days <= 45) {
      final s = info.nextSeason ?? 1;
      final e = info.nextEpisode ?? 1;
      final text = e == 1 ? 'Temporada $s estreia ${_day(next, now)}' : 'T$s · E$e ${_day(next, now)}';
      return NewsItem(title: title, text: text, date: next, upcoming: true);
    }
  }

  final last = info.lastAirDate;
  final watchedSeason = title.currentSeason;
  if (last != null && watchedSeason != null && info.lastSeason > watchedSeason) {
    final ago = today.difference(DateTime(last.year, last.month, last.day)).inDays;
    if (ago >= 0 && ago <= 30) {
      return NewsItem(title: title, text: 'Temporada ${info.lastSeason} no ar', date: last, upcoming: false);
    }
  }
  return null;
}
