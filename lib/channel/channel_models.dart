/// Data models for the Telegram-style news channel.
library;

enum JournalistStatus { pending, verified }

class Journalist {
  final String name, outlet, phone, pressId;
  final JournalistStatus status;
  const Journalist({
    required this.name,
    required this.outlet,
    required this.phone,
    required this.pressId,
    this.status = JournalistStatus.pending,
  });

  Map<String, dynamic> toJson() =>
      {'name': name, 'outlet': outlet, 'phone': phone, 'pressId': pressId, 'status': status.name};

  factory Journalist.fromJson(Map<String, dynamic> j) => Journalist(
        name: j['name'] as String,
        outlet: j['outlet'] as String,
        phone: j['phone'] as String? ?? '',
        pressId: j['pressId'] as String? ?? '',
        status: j['status'] == 'verified' ? JournalistStatus.verified : JournalistStatus.pending,
      );
}

class ChannelPost {
  final String id, authorName, outlet, text, region;
  final bool urgent, verifiedAuthor, sample;
  final DateTime createdAt;
  final int views;

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
  });

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
