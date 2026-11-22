import 'package:flutter/material.dart';

import '../theme.dart';
import 'channel_models.dart';
import 'channel_repository.dart';

class JournalistSignupPage extends StatefulWidget {
  final ChannelRepository repo;
  const JournalistSignupPage({super.key, required this.repo});
  @override
  State<JournalistSignupPage> createState() => _JournalistSignupPageState();
}

class _JournalistSignupPageState extends State<JournalistSignupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _outlet = TextEditingController();
  final _phone = TextEditingController();
  final _pressId = TextEditingController();
  bool pledge = false;

  @override
  void dispose() {
    for (final c in [_name, _outlet, _phone, _pressId]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().length < 2) ? 'هذا الحقل مطلوب' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!pledge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الموافقة على ميثاق النشر أولاً')),
      );
      return;
    }
    await widget.repo.registerJournalist(Journalist(
      name: _name.text.trim(),
      outlet: _outlet.text.trim(),
      phone: _phone.text.trim(),
      pressId: _pressId.text.trim(),
    ));
    await widget.repo.setSubscribed(true);
    if (mounted) Navigator.pop(context, true);
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: context.surfaceCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التسجيل كصحفي')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [ink, teal]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(children: [
              Icon(Icons.campaign, color: Colors.white, size: 34),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'انضم إلى مراسلي غزة الآن وانشر أخبارك مباشرة في القناة لتصل إلى جميع المشتركين فوراً.',
                  style: TextStyle(color: Colors.white, height: 1.6, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          TextFormField(controller: _name, validator: _required, decoration: _deco('الاسم الكامل', Icons.person_outline)),
          const SizedBox(height: 12),
          TextFormField(controller: _outlet, validator: _required, decoration: _deco('المؤسسة الإعلامية / مستقل', Icons.apartment)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            validator: _required,
            keyboardType: TextInputType.phone,
            decoration: _deco('رقم الهاتف', Icons.phone_outlined),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _pressId, decoration: _deco('رقم البطاقة الصحفية (اختياري)', Icons.badge_outlined)),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: pledge,
            onChanged: (v) => setState(() => pledge = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('أتعهد بنشر معلومات دقيقة، وذكر المصدر، وعدم نشر محتوى يعرّض الأشخاص للخطر.',
                style: TextStyle(fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _submit,
            icon: const Icon(Icons.how_to_reg),
            label: const Text('تسجيل والبدء بالنشر', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.noteFill, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'يظهر حسابك بعلامة "بانتظار التوثيق" حتى تراجع إدارة التحرير بياناتك وتمنحك علامة الصحفي الموثّق.',
              style: TextStyle(fontSize: 12, height: 1.5, color: context.titleColor),
            ),
          ),
        ]),
      ),
    );
  }
}
