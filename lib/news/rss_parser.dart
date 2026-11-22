import 'package:xml/xml.dart';

import 'news_models.dart';

/// Parses RSS 2.0, RSS 1.0 (RDF) and Atom feeds into [Article]s.
List<Article> parseFeed(String body, NewsSource source) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(body);
  } catch (_) {
    return const [];
  }
  final items = doc.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'item' || e.name.local == 'entry');

  final out = <Article>[];
  for (final item in items) {
    final title = cleanText(_text(item, 'title') ?? '');
    var link = _text(item, 'link') ?? '';
    if (link.isEmpty) {
      // Atom: <link href="..."/>
      link = _child(item, 'link')?.getAttribute('href') ?? item.getAttribute('rdf:about') ?? '';
    }
    if (title.isEmpty || !link.startsWith('http')) continue;

    final rawDesc = _text(item, 'description') ?? _text(item, 'summary') ?? '';
    final encoded = _text(item, 'encoded') ?? _text(item, 'content') ?? '';
    final summary = cleanText(rawDesc.isNotEmpty ? rawDesc : encoded);
    final date = parseFeedDate(
          _text(item, 'pubDate') ?? _text(item, 'date') ?? _text(item, 'published') ?? _text(item, 'updated'),
        ) ??
        DateTime.now();

    out.add(Article(
      link: link.trim(),
      title: title,
      summary: summary.length > 600 ? '${summary.substring(0, 600)}…' : summary,
      sourceId: source.id,
      published: date,
      imageUrl: _image(item, '$rawDesc $encoded'),
      category: cleanText(_text(item, 'category') ?? _text(item, 'subject') ?? ''),
    ));
  }
  return out;
}

XmlElement? _child(XmlElement e, String local) {
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

String? _text(XmlElement e, String local) {
  final c = _child(e, local);
  if (c == null) return null;
  final t = c.innerText.trim();
  return t.isEmpty ? null : t;
}

String? _image(XmlElement item, String html) {
  for (final c in item.childElements) {
    final local = c.name.local;
    final url = c.getAttribute('url');
    if ((local == 'thumbnail' || local == 'content') && url != null && url.startsWith('http')) {
      return _upgrade(url);
    }
    if (local == 'enclosure' && url != null) {
      final type = c.getAttribute('type') ?? 'image';
      if (type.startsWith('image')) return _upgrade(url);
    }
    if (local == 'image') {
      final t = c.innerText.trim();
      if (t.startsWith('http')) return _upgrade(t);
      final nested = _text(c, 'url');
      if (nested != null && nested.startsWith('http')) return _upgrade(nested);
    }
  }
  final m = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  return m == null ? null : _upgrade(m.group(1)!);
}

/// Ask for larger thumbnails where the outlet's URL scheme allows it.
String _upgrade(String url) {
  final u = url.replaceAll('&amp;', '&');
  if (u.contains('ichef.bbci.co.uk')) return u.replaceFirst(RegExp(r'/ws/\d+/'), '/ws/800/');
  return u;
}

final _entities = <String, String>{
  '&amp;': '&',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
  '&hellip;': '…',
  '&laquo;': '«',
  '&raquo;': '»',
};

String cleanText(String s) {
  var t = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
  _entities.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
const _zones = {'GMT': 0, 'UT': 0, 'UTC': 0, 'Z': 0, 'EST': -5, 'EDT': -4, 'CST': -6, 'CDT': -5, 'PST': -8, 'PDT': -7};

/// ISO-8601 or RFC-822 ("Sun, 22 Nov 2026 17:25:12 +0300").
DateTime? parseFeedDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final iso = DateTime.tryParse(s.trim());
  if (iso != null) return iso.toUtc();
  final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Z]{1,4})?')
      .firstMatch(s);
  if (m == null) return null;
  final month = _months[m.group(2)!.toLowerCase()];
  if (month == null) return null;
  var year = int.parse(m.group(3)!);
  if (year < 100) year += 2000;
  var t = DateTime.utc(year, month, int.parse(m.group(1)!), int.parse(m.group(4)!), int.parse(m.group(5)!),
      int.tryParse(m.group(6) ?? '0') ?? 0);
  final z = m.group(7);
  if (z != null) {
    if (z.startsWith('+') || z.startsWith('-')) {
      final sign = z.startsWith('-') ? -1 : 1;
      final mins = int.parse(z.substring(1, 3)) * 60 + int.parse(z.substring(3, 5));
      t = t.subtract(Duration(minutes: sign * mins));
    } else {
      t = t.subtract(Duration(hours: _zones[z] ?? 0));
    }
  }
  return t;
}
