import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'channel_models.dart';
import 'channel_repository.dart';
import 'journalist_signup_page.dart';

const channelRegions = ['قطاع غزة', 'شمال غزة', 'مدينة غزة', 'دير البلح', 'خانيونس', 'رفح'];

/// Telegram-style channel: newest message at the bottom, readers subscribe,
/// registered journalists post updates that appear instantly.
class ChannelPage extends StatelessWidget {
  final ChannelRepository repo;
  final VoidCallback onOpenLive;
  const ChannelPage({super.key, required this.repo, required this.onOpenLive});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChannelPost>>(
      stream: repo.watchPosts(),
      initialData: repo.posts,
      builder: (context, snap) {
        final posts = snap.data ?? const <ChannelPost>[];
        final journalist = repo.journalist;
        return Scaffold(
          backgroundColor: context.isDark ? const Color(0xFF0B1A1E) : const Color(0xFFE4EEF0),
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 12,
            title: Row(children: [
              ClipOval(child: Image.asset('assets/images/logo.png', width: 40, height: 40)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('قناة غزة الآن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  Text('${_formatCount(repo.subscriberCount)} مشترك',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            ]),
            actions: [
              IconButton(tooltip: 'البث المباشر', onPressed: onOpenLive, icon: const Icon(Icons.live_tv)),
              if (repo.subscribed)
                IconButton(
                  tooltip: repo.muted ? 'تفعيل الإشعارات' : 'كتم الإشعارات',
                  onPressed: () => repo.setMuted(!repo.muted),
                  icon: Icon(repo.muted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined),
                ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'join') await _openSignup(context);
                  if (v == 'leave') await repo.setSubscribed(false);
                  if (v == 'signout') await repo.signOutJournalist();
                },
                itemBuilder: (_) => [
                  if (journalist == null) const PopupMenuItem(value: 'join', child: Text('التسجيل كصحفي')),
                  if (journalist != null) const PopupMenuItem(value: 'signout', child: Text('تسجيل خروج الصحفي')),
                  if (repo.subscribed) const PopupMenuItem(value: 'leave', child: Text('إلغاء الاشتراك')),
                ],
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: posts.isEmpty
                  ? const Center(child: Text('لا توجد منشورات بعد', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      reverse: true, // newest at the bottom, like Telegram
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: posts.length,
                      itemBuilder: (_, i) => _PostBubble(
                        post: posts[i],
                        canDelete: journalist != null && !posts[i].sample && posts[i].authorName == journalist.name,
                        onDelete: () => repo.deletePost(posts[i].id),
                      ),
                    ),
            ),
            _BottomBar(repo: repo, onSignup: () => _openSignup(context)),
          ]),
        );
      },
    );
  }

  Future<void> _openSignup(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => JournalistSignupPage(repo: repo)),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تسجيلك كصحفي. يمكنك النشر الآن، وسيظهر حسابك "بانتظار التوثيق" حتى تراجع الإدارة بياناتك.'),
        duration: Duration(seconds: 5),
      ));
    }
  }
}

String _formatCount(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)} ألف' : '$n';

class _PostBubble extends StatelessWidget {
  final ChannelPost post;
  final bool canDelete;
  final VoidCallback onDelete;
  const _PostBubble({required this.post, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bubble = context.isDark ? const Color(0xFF14292F) : Colors.white;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .86),
        child: GestureDetector(
          onLongPress: () => _actions(context),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: post.urgent ? Color.alphaBlend(urgent.withValues(alpha: .07), bubble) : bubble,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(16),
                topEnd: Radius.circular(16),
                bottomEnd: Radius.circular(16),
                bottomStart: Radius.circular(4),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text(
                    post.outlet.isEmpty ? post.authorName : '${post.authorName} • ${post.outlet}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: teal, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                post.verifiedAuthor
                    ? const Tooltip(message: 'صحفي موثّق', child: Icon(Icons.verified, color: teal, size: 15))
                    : const Tooltip(message: 'بانتظار التوثيق', child: Icon(Icons.schedule, color: Colors.orange, size: 15)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (post.urgent) const _Tag('عاجل', urgent, Colors.white),
                _Tag(post.region, teal.withValues(alpha: .12), teal),
                if (post.sample) _Tag('مثال', Colors.grey.withValues(alpha: .18), Colors.grey),
              ]),
              const SizedBox(height: 6),
              Text(post.text, style: const TextStyle(fontSize: 15, height: 1.6)),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.visibility_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 3),
                Text('${post.views}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 10),
                Text('${clockTime(post.createdAt)} • ${relativeTime(post.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _actions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('نسخ النص'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: post.text));
              Navigator.pop(sheet);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النص')));
            },
          ),
          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: urgent),
              title: const Text('حذف المنشور', style: TextStyle(color: urgent)),
              onTap: () {
                Navigator.pop(sheet);
                onDelete();
              },
            ),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Tag(this.label, this.bg, this.fg);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

class _BottomBar extends StatelessWidget {
  final ChannelRepository repo;
  final VoidCallback onSignup;
  const _BottomBar({required this.repo, required this.onSignup});

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? const Color(0xFF0F2328) : Colors.white;
    final journalist = repo.journalist;
    Widget child;
    if (journalist != null) {
      child = _Composer(repo: repo, journalist: journalist);
    } else if (!repo.subscribed) {
      child = Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: teal, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => repo.setSubscribed(true),
            icon: const Icon(Icons.add_alert),
            label: const Text('اشتراك في القناة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        TextButton.icon(onPressed: onSignup, icon: const Icon(Icons.badge_outlined), label: const Text('هل أنت صحفي؟ انضم كمراسل')),
      ]);
    } else {
      child = Row(children: [
        Expanded(
          child: TextButton.icon(
            onPressed: () => repo.setMuted(!repo.muted),
            icon: Icon(repo.muted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined),
            label: Text(repo.muted ? 'تفعيل الإشعارات' : 'كتم الإشعارات'),
          ),
        ),
        Expanded(
          child: TextButton.icon(onPressed: onSignup, icon: const Icon(Icons.badge_outlined), label: const Text('انضم كصحفي')),
        ),
      ]);
    }
    return Material(
      color: bg,
      elevation: 6,
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: child)),
    );
  }
}

class _Composer extends StatefulWidget {
  final ChannelRepository repo;
  final Journalist journalist;
  const _Composer({required this.repo, required this.journalist});
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  String region = channelRegions.first;
  bool isUrgent = false;
  bool sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    final j = widget.journalist;
    await widget.repo.publish(ChannelPost(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      authorName: j.name,
      outlet: j.outlet,
      text: body,
      region: region,
      urgent: isUrgent,
      verifiedAuthor: j.status == JournalistStatus.verified,
      createdAt: DateTime.now(),
    ));
    _text.clear();
    if (mounted) setState(() {
      sending = false;
      isUrgent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.edit_note, size: 18, color: teal),
        const SizedBox(width: 4),
        Expanded(
          child: Text('تنشر باسم: ${widget.journalist.name}',
              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        PopupMenuButton<String>(
          initialValue: region,
          onSelected: (v) => setState(() => region = v),
          itemBuilder: (_) => [for (final r in channelRegions) PopupMenuItem(value: r, child: Text(r))],
          child: Chip(
            avatar: const Icon(Icons.location_on, size: 16, color: teal),
            label: Text(region, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
          ),
        ),
        const SizedBox(width: 6),
        FilterChip(
          label: const Text('عاجل', style: TextStyle(fontSize: 12)),
          selected: isUrgent,
          onSelected: (v) => setState(() => isUrgent = v),
          selectedColor: urgent.withValues(alpha: .2),
          checkmarkColor: urgent,
          visualDensity: VisualDensity.compact,
          side: BorderSide.none,
        ),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _text,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'اكتب الخبر لنشره في القناة...',
              filled: true,
              fillColor: context.softFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: isUrgent ? urgent : teal),
          onPressed: sending ? null : _send,
          tooltip: 'نشر',
          icon: const Icon(Icons.send),
        ),
      ]),
    ]);
  }
}
