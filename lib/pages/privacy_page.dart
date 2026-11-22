import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const sections = [
    ('البيانات التي نجمعها', 'لا يطلب التطبيق إنشاء حساب ولا يجمع اسمك أو موقعك. الأخبار المحفوظة والإعدادات تُخزَّن على جهازك فقط.'),
    ('قناة المراسلين', 'بيانات تسجيل الصحفي (الاسم، المؤسسة، الهاتف، رقم البطاقة) تُحفظ على الجهاز في هذا الإصدار ولا تُرسل لأي خادم.'),
    ('الإعلانات', 'يعرض التطبيق إعلانات Google AdMob. قد تستخدم Google معرّف الإعلانات في جهازك لعرض إعلانات مناسبة. يمكنك إعادة ضبط هذا المعرّف أو إيقاف الإعلانات المخصّصة من إعدادات Google في جهازك. في الدول التي يشترط قانونها الموافقة، يُطلب إذنك عند أول تشغيل.'),
    ('مصادر الأخبار', 'يجلب التطبيق الأخبار من الموجزات العامة لمؤسسات إعلامية ومن واجهة NewsData.io، ويفتح الخبر الكامل على موقع المصدر الذي له سياسة خصوصية خاصة به.'),
    ('الأطفال', 'التطبيق غير موجّه للأطفال دون 13 عاماً.'),
    ('التواصل', 'لأي استفسار حول الخصوصية: ${AppConfig.privacyContactEmail}'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سياسة الخصوصية')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text('آخر تحديث: نوفمبر 2026', style: TextStyle(color: context.titleColor.withValues(alpha: .6))),
          const SizedBox(height: 14),
          for (final s in sections) ...[
            Text(s.$1, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.titleColor)),
            const SizedBox(height: 6),
            Text(s.$2, style: const TextStyle(height: 1.8)),
            const SizedBox(height: 16),
          ],
        ]),
      );
}
