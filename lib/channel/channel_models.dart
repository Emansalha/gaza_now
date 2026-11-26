/// Data models for the Telegram-style news channel.
library;

enum JournalistStatus { pending, verified }

class Journalist {
  final String name, outlet, phone, pressId, region, bio;
  final JournalistStatus status;
  const Journalist({
    required this.name,
    required this.outlet,
    required this.phone,
    required this.pressId,
    this.region = 'قطاع غزة',
    this.bio = '',
    this.status = JournalistStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'outlet': outlet,
        'phone': phone,
        'pressId': pressId,
        'region': region,
        'bio': bio,
        'status': status.name,
      };

  factory Journalist.fromJson(Map<String, dynamic> j) => Journalist(
        name: j['name'] as String,
        outlet: j['outlet'] as String,
        phone: j['phone'] as String? ?? '',
        pressId: j['pressId'] as String? ?? '',
        region: j['region'] as String? ?? 'قطاع غزة',
        bio: j['bio'] as String? ?? '',
        status: j['status'] == 'verified' ? JournalistStatus.verified : JournalistStatus.pending,
      );
}

class ChannelPost {
  final String id, authorName, outlet, text, region;
  final bool urgent, verifiedAuthor, sample;
  final DateTime createdAt;
  final int views;

  /// Link to a live broadcast (YouTube, Facebook, TikTok, Instagram…), if this post is a live.
  final String? liveUrl;
  final bool liveEnded;
  bool get isLive => liveUrl != null && !liveEnded;

  const ChannelPost({
    required this.id,
    required this.authorName,
    required this.outlet,
    required this.text,
    required this.region,
    required this.createdAt,
    this.urgent = false,
    this.verifiedAuthor = false,
    this.sample = false,
    this.views = 0,
    this.liveUrl,
    this.liveEnded = false,
  });

  ChannelPost endLive() => ChannelPost(
        id: id,
        authorName: authorName,
        outlet: outlet,
        text: text,
        region: region,
        createdAt: createdAt,
        urgent: urgent,
        verifiedAuthor: verifiedAuthor,
        sample: sample,
        views: views,
        liveUrl: liveUrl,
        liveEnded: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'outlet': outlet,
        'text': text,
        'region': region,
        'urgent': urgent,
        'verifiedAuthor': verifiedAuthor,
        'sample': sample,
        'createdAt': createdAt.toIso8601String(),
        'views': views,
        'liveUrl': liveUrl,
        'liveEnded': liveEnded,
      };

  factory ChannelPost.fromJson(Map<String, dynamic> j) => ChannelPost(
        id: j['id'] as String,
        authorName: j['authorName'] as String,
        outlet: j['outlet'] as String? ?? '',
        text: j['text'] as String,
        region: j['region'] as String? ?? 'قطاع غزة',
        urgent: j['urgent'] as bool? ?? false,
        verifiedAuthor: j['verifiedAuthor'] as bool? ?? false,
        sample: j['sample'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        views: j['views'] as int? ?? 0,
        liveUrl: j['liveUrl'] as String?,
        liveEnded: j['liveEnded'] as bool? ?? false,
      );
}

/// "منذ 5 دقائق" style relative time in Arabic.
String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'الآن';
  if (d.inMinutes < 60) return 'منذ ${d.inMinutes} د';
  if (d.inHours < 24) return 'منذ ${d.inHours} س';
  return 'منذ ${d.inDays} يوم';
}

String clockTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Accepts links from the common live platforms (https only).
String? validateLiveUrl(String raw) {
  final u = Uri.tryParse(raw.trim());
  if (u == null || u.scheme != 'https' || u.host.isEmpty) return 'أدخل رابطاً كاملاً يبدأ بـ https://';
  return null;
}

String livePlatformName(String url) {
  final h = Uri.tryParse(url)?.host ?? '';
  if (h.contains('youtu')) return 'YouTube';
  if (h.contains('facebook') || h.contains('fb.')) return 'Facebook';
  if (h.contains('tiktok')) return 'TikTok';
  if (h.contains('instagram')) return 'Instagram';
  if (h.contains('x.com') || h.contains('twitter')) return 'X';
  return h.replaceFirst('www.', '');
}
