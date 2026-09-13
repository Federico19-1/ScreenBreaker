import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/news_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// The news section: recent articles about personal health, screen time and
/// attention issues caused by phones and TVs.
///
/// Content comes from Google News' public RSS search (see [NewsService]) and
/// opens in the system browser when tapped. The first story is featured with
/// a large hero image; every card leads with its story image (when the feed
/// provides one) and a clear publication date chip.
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
        title: Row(
          children: [
            AppLogo(size: 26),
            const SizedBox(width: 10),
            const Text('Screen-time news'),
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
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == articles.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                // The newest story gets the big featured treatment.
                final featured = index == 0;
                return _ArticleCard(
                  article: article,
                  featured: featured,
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

// ---------------------------------------------------------------------------
// Article card
// ---------------------------------------------------------------------------

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.onTap,
    this.featured = false,
  });

  final NewsArticle article;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.imageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: appCardDecoration(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Story image (or branded gradient when the feed has none).
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: _ArticleImage(
                  url: imageUrl,
                  featured: featured,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta row: source pill + clear date chip.
                    Row(
                      children: [
                        if (article.source != null &&
                            article.source!.isNotEmpty) ...[
                          _SourcePill(label: article.source!),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        _DateChip(
                          label: article.dateLabel,
                          relative: _relativeTime(article.published),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      maxLines: featured ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.iceWhite,
                        fontSize: featured ? 18 : 16,
                        fontWeight: featured ? FontWeight.w800 : FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (article.snippet != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        article.snippet!,
                        maxLines: featured ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.iceDim,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "3h ago" style hint shown next to the calendar date.
  static String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '';
  }
}

// ---------------------------------------------------------------------------
// Image / fallback
// ---------------------------------------------------------------------------

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.url, required this.featured});
  final String? url;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final height = featured ? 190.0 : 150.0;

    // Branded fallback when the feed offers no image (or it fails to load).
    Widget fallback = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 44,
          color: AppColors.iceWhite.withValues(alpha: 0.7),
        ),
      ),
    );

    if (url == null) return fallback;

    return Image.network(
      url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          color: AppColors.surfaceHigh,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Source pill / date chip
// ---------------------------------------------------------------------------

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.techMagenta.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.techMagenta,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.relative});
  final String label;
  final String relative;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.purpleDim.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 11, color: AppColors.iceDim),
          const SizedBox(width: 5),
          Text(
            relative.isEmpty ? label : '$label · $relative',
            style: TextStyle(
              color: AppColors.iceWhite,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error state
// ---------------------------------------------------------------------------

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
              style: TextStyle(
                color: AppColors.iceWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.iceDim, height: 1.5),
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
