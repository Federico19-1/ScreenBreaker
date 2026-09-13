import 'package:flutter_test/flutter_test.dart';
import 'package:screenbreaker/services/news_service.dart';

void main() {
  group('NewsArticle.dateLabel', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    test('shows Today for a story published today', () {
      final article = NewsArticle(
        title: 't',
        link: 'https://example.com',
        published: today.add(const Duration(hours: 2)),
      );
      expect(article.dateLabel, 'Today');
    });

    test('shows Yesterday for a story published yesterday', () {
      final article = NewsArticle(
        title: 't',
        link: 'https://example.com',
        published: today.subtract(const Duration(days: 1)),
      );
      expect(article.dateLabel, 'Yesterday');
    });

    test('shows a full calendar date for older stories', () {
      final day = today.subtract(const Duration(days: 4));
      final article = NewsArticle(
        title: 't',
        link: 'https://example.com',
        published: day,
      );
      expect(article.dateLabel, matches(RegExp(r'^\d{1,2} \w{3}$')));
    });

    test('includes the year for stories from a previous year', () {
      final article = NewsArticle(
        title: 't',
        link: 'https://example.com',
        published: DateTime(now.year - 1, 3, 5),
      );
      expect(article.dateLabel, '5 Mar ${now.year - 1}');
    });

    test('falls back to a placeholder when the date is unknown', () {
      const article = NewsArticle(title: 't', link: 'https://example.com');
      expect(article.dateLabel, 'Date unavailable');
    });
  });
}
