import 'package:flutter/material.dart';

/// A trusted outlet whose public RSS feed the app reads.
class NewsSource {
  final String id, name, feedUrl, homepage, description;
  final Color color;
  const NewsSource({
    required this.id,
    required this.name,
    required this.feedUrl,
    required this.homepage,
    required this.description,
    required this.color,
  });
}

/// Feeds verified to return Arabic RSS (checked 26 Nov 2026).
const newsSources = <NewsSource>[
  NewsSource(
    id: 'aljazeera',
    name: 'الجزيرة نت',
    feedUrl: 'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9',
    homepage: 'https://www.aljazeera.net',
    description: 'شبكة إخبارية عربية دولية مقرها الدوحة، لها مراسلون داخل قطاع غزة.',
    color: Color(0xFFC8962B),
  ),
  NewsSource(
    id: 'arab48',
    name: 'عرب 48',
    feedUrl: 'https://www.arab48.com/rss',
    homepage: 'https://www.arab48.com',
    description: 'موقع إخباري فلسطيني يغطي الشأن الفلسطيني وغزة يومياً.',
    color: Color(0xFF1E7B4F),
  ),
  NewsSource(
    id: 'alquds',
    name: 'القدس العربي',
    feedUrl: 'https://www.alquds.co.uk/feed/',
    homepage: 'https://www.alquds.co.uk',
    description: 'صحيفة عربية يومية مستقلة مقرها لندن، تغطية واسعة لفلسطين.',
    color: Color(0xFF8E2C2C),
  ),
  NewsSource(
    id: 'un',
    name: 'أخبار الأمم المتحدة',
    feedUrl: 'https://news.un.org/feed/subscribe/ar/news/all/rss.xml',
    homepage: 'https://news.un.org/ar/',
    description: 'الخدمة الإخبارية الرسمية للأمم المتحدة: تقارير الأونروا ومنظمة الصحة العالمية والوضع الإنساني.',
    color: Color(0xFF009EDB),
  ),
  NewsSource(
    id: 'bbc',
    name: 'بي بي سي عربي',
    feedUrl: 'https://feeds.bbci.co.uk/arabic/middleeast/rss.xml',
    homepage: 'https://www.bbc.com/arabic',
    description: 'القسم العربي في هيئة الإذاعة البريطانية، تغطية الشرق الأوسط.',
    color: Color(0xFFB80000),
  ),
  NewsSource(
    id: 'france24',
    name: 'فرانس 24',
    feedUrl: 'https://www.france24.com/ar/%D8%A7%D9%84%D8%B4%D8%B1%D9%82-%D8%A7%D9%84%D8%A3%D9%88%D8%B3%D8%B7/rss',
    homepage: 'https://www.france24.com/ar/',
    description: 'القناة الفرنسية الدولية بالعربية، قسم الشرق الأوسط.',
    color: Color(0xFF0A6EB4),
  ),
  NewsSource(
    id: 'aa',
    name: 'الأناضول',
    feedUrl: 'https://www.aa.com.tr/ar/rss/default?cat=guncel',
    homepage: 'https://www.aa.com.tr/ar',
    description: 'وكالة أنباء دولية لها مكتب ومراسلون في فلسطين.',
    color: Color(0xFF1B4F9C),
  ),
  NewsSource(
    id: 'skynews',
    name: 'سكاي نيوز عربية',
    feedUrl: 'https://www.skynewsarabia.com/rss',
    homepage: 'https://www.skynewsarabia.com',
    description: 'قناة إخبارية عربية مقرها أبوظبي.',
    color: Color(0xFF2B8C8C),
  ),
  NewsSource(
    id: 'cnn',
    name: 'CNN بالعربية',
    feedUrl: 'https://arabic.cnn.com/api/v1/rss/middle_east/rss.xml',
    homepage: 'https://arabic.cnn.com',
    description: 'النسخة العربية من شبكة CNN، قسم الشرق الأوسط.',
    color: Color(0xFFCC0000),
  ),
  NewsSource(
    id: 'dw',
    name: 'DW عربية',
    feedUrl: 'https://rss.dw.com/rdf/rss-ar-all',
    homepage: 'https://www.dw.com/ar',
    description: 'الخدمة العربية في مؤسسة دويتشه فيله الألمانية.',
    color: Color(0xFF05B2FC),
  ),
];

/// Pseudo-source for stories that come through the NewsData.io API.
const apiSource = NewsSource(
  id: 'api',
  name: 'وكالات (NewsData)',
  feedUrl: '',
  homepage: 'https://newsdata.io',
  description: 'أخبار عربية من مئات المواقع الإخبارية عبر واجهة NewsData.io البرمجية، مع اسم الناشر الأصلي.',
  color: Color(0xFF6A4FB3),
);

NewsSource sourceById(String id) => id == 'api'
    ? apiSource
    :
    newsSources.firstWhere((s) => s.id == id, orElse: () => newsSources.first);

/// Words that mark a story as about Gaza / Palestine.
const gazaKeywords = [
  'غزة', 'غزّة', 'فلسطين', 'الفلسطيني', 'فلسطيني', 'رفح', 'خان يونس', 'خانيونس', 'دير البلح',
  'جباليا', 'النصيرات', 'بيت لاهيا', 'بيت حانون', 'الأونروا', 'الضفة الغربية', 'القدس', 'المغازي', 'البريج',
];

/// Governorates of the Gaza Strip and the place names that point to each.
const governorateKeywords = <String, List<String>>{
  'شمال غزة': ['شمال غزة', 'جباليا', 'بيت لاهيا', 'بيت حانون'],
  'مدينة غزة': ['مدينة غزة', 'الشجاعية', 'الشيخ رضوان', 'حي الرمال', 'الزيتون', 'التفاح'],
  'دير البلح': ['دير البلح', 'النصيرات', 'المغازي', 'البريج', 'الزوايدة', 'وسط القطاع', 'وسط غزة'],
  'خانيونس': ['خانيونس', 'خان يونس', 'المواصي'],
  'رفح': ['رفح', 'معبر كرم أبو سالم'],
};

class Article {
  final String link, title, summary, sourceId;
  final String? imageUrl, category;

  /// Original publisher name for API stories (e.g. "العربي الجديد").
  final String? publisher;
  final DateTime published;

  const Article({
    required this.link,
    required this.title,
    required this.summary,
    required this.sourceId,
    required this.published,
    this.imageUrl,
    this.category,
    this.publisher,
  });

  String get id => link;
  String get sourceName => publisher ?? source.name;
  NewsSource get source => sourceById(sourceId);
  String get _text => '$title $summary';

  bool get isGaza => gazaKeywords.any(_text.contains);
  bool matchesGovernorate(String g) => (governorateKeywords[g] ?? [g]).any(_text.contains);

  /// Breaking-style headline (outlets often prefix with "عاجل").
  bool get isBreaking => title.contains('عاجل');

  Article copyWith({String? imageUrl}) => Article(
        link: link,
        title: title,
        summary: summary,
        sourceId: sourceId,
        published: published,
        imageUrl: imageUrl ?? this.imageUrl,
        category: category,
        publisher: publisher,
      );

  Map<String, dynamic> toJson() => {
        'link': link,
        'title': title,
        'summary': summary,
        'sourceId': sourceId,
        'published': published.toIso8601String(),
        'imageUrl': imageUrl,
        'category': category,
        'publisher': publisher,
      };

  factory Article.fromJson(Map<String, dynamic> j) => Article(
        link: j['link'] as String,
        title: j['title'] as String,
        summary: j['summary'] as String? ?? '',
        sourceId: j['sourceId'] as String,
        published: DateTime.tryParse(j['published'] as String? ?? '') ?? DateTime.now(),
        imageUrl: j['imageUrl'] as String?,
        category: j['category'] as String?,
        publisher: j['publisher'] as String?,
      );
}

/// "منذ 5 د" style relative time.
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t.toLocal());
  if (d.isNegative || d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) return 'منذ ${d.inMinutes} د';
  if (d.inHours < 24) return 'منذ ${d.inHours} س';
  if (d.inDays < 7) return 'منذ ${d.inDays} يوم';
  final l = t.toLocal();
  return '${l.year}/${l.month}/${l.day}';
}
