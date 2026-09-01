import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/news_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// The news section: recent articles about personal health, screen time and
/// attention issues caused by phones and TVs.
///
/// Content comes from Google News' public RSS search (see [NewsService]) and
/// opens in the system browser when tapped.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<NewsArticle>> _future;

  @override
  void initState() {
    super.initState();
    _future = NewsService.fetchLatest();
  }

  Future<void> _reload() async {
    setState(() {
      _future = NewsService.fetchLatest();
    });
    await _future;
  }

  Future<void> _open(NewsArticle article) async {
    final uri = Uri.tryParse(article.link);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this article in the browser'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this article in the browser'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 26),
            SizedBox(width: 10),
            Text('Screen-time news'),
          ],
        ),
      ),
      body: FutureBuilder<List<NewsArticle>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final articles = snapshot.data ?? const <NewsArticle>[];
          if (articles.isEmpty) {
            return _NewsMessage(
              icon: Icons.wifi_off,
              title: 'News unavailable',
              message:
                  'Could not load the latest articles.\n'
                  'Check your internet connection and try again.',
              onRetry: _reload,
            );
          }
          return RefreshIndicator(
            color: AppColors.neonPurple,
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: articles.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == articles.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Powered by Google News · tap an article to open it',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.iceDim,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                final article = articles[index];
                return _ArticleCard(
                  article: article,
                  onTap: () => _open(article),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTap});
  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 16,
                    color: AppColors.techMagenta,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _byline(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.techMagenta,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(
                  color: AppColors.iceWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (article.snippet != null) ...[
                const SizedBox(height: 8),
                Text(
                  article.snippet!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.iceDim,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _byline() {
    final parts = <String>[
      if (article.source != null && article.source!.isNotEmpty)
        article.source!,
      if (article.published != null) _relativeTime(article.published!),
    ];
    return parts.join(' · ');
  }

  static String _relativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}';
  }
}

class _NewsMessage extends StatelessWidget {
  const _NewsMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.iceDim),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.iceWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.iceDim, height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
