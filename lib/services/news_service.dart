import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';

/// A single health/screen-time news item.
class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.link,
    this.source,
    this.published,
    this.snippet,
  });

  final String title;
  final String link;

  /// Publisher name, e.g. "BBC" (may be null for some feeds).
  final String? source;

  final DateTime? published;

  /// Short plain-text description when the feed provides one.
  final String? snippet;
}

/// Fetches recent news about personal health, screen time, and attention
/// issues caused by phones and TVs.
///
/// Uses Google News' public RSS search endpoint (no API key required), runs a
/// few targeted queries in parallel, merges and de-duplicates the results, and
/// returns them newest-first. Results are cached in memory for a few minutes
/// so the home screen and the news screen don't hammer the network.
class NewsService {
  NewsService._();

  static const List<String> _queries = [
    'screen time health effects',
    'phone addiction attention span',
    'digital wellbeing children screens',
    'too much screen time sleep',
    'television screen time attention',
  ];

  static const int _maxArticles = 30;
  static const Duration _cacheDuration = Duration(minutes: 15);
  static const Duration _requestTimeout = Duration(seconds: 15);

  static List<NewsArticle>? _cache;
  static DateTime _cacheAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// The most recent articles across all queries, newest first.
  static Future<List<NewsArticle>> fetchLatest() async {
    if (_cache != null &&
        DateTime.now().difference(_cacheAt) < _cacheDuration) {
      return _cache!;
    }

    try {
      final results = await Future.wait(
        _queries.map(_fetchQuery),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => const <List<NewsArticle>>[],
      );

      final byLink = <String, NewsArticle>{};
      for (final article in results.expand((list) => list)) {
        if (article.link.isEmpty || byLink.containsKey(article.link)) continue;
        byLink[article.link] = article;
      }

      final merged = byLink.values.toList()
        ..sort((a, b) {
          final at = a.published;
          final bt = b.published;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });

      _cache = merged.take(_maxArticles).toList();
      _cacheAt = DateTime.now();
      return _cache!;
    } on Exception {
      // Network failure / parse failure → report as empty; the UI shows an
      // error state with a retry button.
      return const [];
    }
  }

  static Future<List<NewsArticle>> _fetchQuery(String query) async {
    try {
      final uri = Uri.parse(
        'https://news.google.com/rss/search?q='
        '${Uri.encodeQueryComponent(query)}&hl=en&gl=US&ceid=US:en',
      );
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return const [];

      final feed = RssFeed.parse(response.body);
      return feed.items.map(_toArticle).whereType<NewsArticle>().toList();
    } on Exception {
      return const [];
    }
  }

  static NewsArticle? _toArticle(RssItem item) {
    final title = item.title?.trim() ?? '';
    final link = item.link?.trim() ?? '';
    if (title.isEmpty || link.isEmpty) return null;

    return NewsArticle(
      title: title,
      link: link,
      source: item.source?.value,
      published: _parseDate(item),
      snippet: _stripHtml(item.description),
    );
  }

  /// Best-effort date parsing: prefers the Dublin-Core ISO 8601 date (Google
  /// News provides it on many items), then falls back to the RFC 822 pubDate.
  static DateTime? _parseDate(RssItem item) {
    final iso = item.dc?.date?.trim();
    if (iso != null && iso.isNotEmpty) {
      final parsed = DateTime.tryParse(iso);
      if (parsed != null) return parsed;
    }
    return _parseRfc822(item.pubDate);
  }

  /// Parses "Tue, 01 Sep 2026 17:15:00 GMT"-style dates.
  static DateTime? _parseRfc822(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(
      r"^(?:\w{3},\s*)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+"
      r"(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([A-Za-z]{1,5}|[+-]\d{4})?$",
    ).firstMatch(raw.trim());
    if (match == null) return null;

    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final month = months[match.group(2)!.toLowerCase()];
    if (month == null) return null;

    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.tryParse(match.group(6) ?? '') ?? 0;
    var utc = DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      hour,
      minute,
      second,
    );

    final tz = match.group(7);
    if (tz != null && tz.isNotEmpty) {
      final offsetMatch = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(tz);
      if (offsetMatch != null) {
        final sign = offsetMatch.group(1) == '-' ? -1 : 1;
        final offsetHours = int.parse(offsetMatch.group(2)!);
        final offsetMinutes = int.parse(offsetMatch.group(3)!);
        utc = utc.subtract(
          Duration(
            hours: sign * offsetHours,
            minutes: sign * offsetMinutes,
          ),
        );
      }
    }
    // Convert to local time so "3h ago" reads naturally.
    return utc.toLocal();
  }

  /// Removes HTML tags and collapses whitespace from the RSS description.
  static String? _stripHtml(String? html) {
    if (html == null || html.isEmpty) return null;
    final noTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final cleaned = noTags
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length > 220 ? '${cleaned.substring(0, 220)}…' : cleaned;
  }
}
