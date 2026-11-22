import 'package:flutter_test/flutter_test.dart';
import 'package:gaza_now/news/news_models.dart';
import 'package:gaza_now/news/rss_parser.dart';

NewsSource src(String id) => sourceById(id);

void main() {
  test('BBC: CDATA title, media:thumbnail, GMT date, larger thumbnail', () {
    const xml = '''<?xml version="1.0"?><rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
      <item><title><![CDATA[غزة: تحديث إنساني]]></title>
      <description><![CDATA[وصف &amp; تفاصيل]]></description>
      <link>https://www.bbc.com/arabic/articles/x1?at_medium=RSS</link>
      <pubDate>Sun, 22 Nov 2026 17:25:12 GMT</pubDate>
      <media:thumbnail width="240" height="135" url="https://ichef.bbci.co.uk/ace/ws/240/a.jpg"/></item>
    </channel></rss>''';
    final a = parseFeed(xml, src('bbc')).single;
    expect(a.title, 'غزة: تحديث إنساني');
    expect(a.summary, 'وصف & تفاصيل');
    expect(a.imageUrl, 'https://ichef.bbci.co.uk/ace/ws/800/a.jpg');
    expect(a.published, DateTime.utc(2026, 11, 22, 17, 25, 12));
    expect(a.isGaza, isTrue);
  });

  test('Al Jazeera: +0300 offset, no image', () {
    const xml = '''<rss><channel><item>
      <link>https://www.aljazeera.net/news/1</link><title>خبر من رفح</title>
      <description><![CDATA[نص]]></description><pubDate>Sun, 22 Nov 2026 17:47:05 +0300</pubDate>
      <category>أخبار</category></item></channel></rss>''';
    final a = parseFeed(xml, src('aljazeera')).single;
    expect(a.published, DateTime.utc(2026, 11, 22, 14, 47, 5));
    expect(a.imageUrl, isNull);
    expect(a.matchesGovernorate('رفح'), isTrue);
  });

  test('UN: enclosure image', () {
    const xml = '''<rss><channel><item><title>غزة - أطفال</title>
      <link>https://news.un.org/feed/view/ar/story/2026/11/1145749</link>
      <enclosure url="https://global.un.org/img.jpg" length="4" type="image/jpeg"/>
      <pubDate>Fri, 20 Nov 2026 12:00:00 +0000</pubDate></item></channel></rss>''';
    expect(parseFeed(xml, src('un')).single.imageUrl, 'https://global.un.org/img.jpg');
  });

  test('Anadolu: <image> text element', () {
    const xml = '''<rss><channel><item><title>القدس</title>
      <link>https://www.aa.com.tr/ar/x</link><pubDate>Sun, 22 Nov 2026 21:01:32 +0300</pubDate>
      <image>https://cdnuploads.aa.com.tr/a.jpg</image></item></channel></rss>''';
    expect(parseFeed(xml, src('aa')).single.imageUrl, 'https://cdnuploads.aa.com.tr/a.jpg');
  });

  test('DW: RDF items with dc:date', () {
    const xml = '''<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <item rdf:about="https://www.dw.com/ar/a-1"><title>عنوان</title><link>https://www.dw.com/ar/a-1</link>
      <description>وصف</description><dc:date>2026-11-22T17:42:00Z</dc:date></item></rdf:RDF>''';
    final a = parseFeed(xml, src('dw')).single;
    expect(a.published, DateTime.utc(2026, 11, 22, 17, 42));
  });

  test('Broken XML returns nothing instead of throwing', () {
    expect(parseFeed('<html>not a feed', src('bbc')), isEmpty);
  });
}
