import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Cairo Bible",
  description: "Privacy information for the Cairo Bible iOS app.",
};

export default function PrivacyPage() {
  return (
    <main className="legal-page" lang="en" dir="ltr">
      <nav className="legal-nav" aria-label="Cairo Bible links">
        <Link href="/">Cairo Bible</Link>
        <Link href="/support">Support</Link>
      </nav>
      <header className="legal-header">
        <p className="legal-eyebrow">CAIRO BIBLE · IOS APP</p>
        <h1>Privacy Policy</h1>
        <p>Draft for review · November 7, 2026</p>
      </header>
      <aside className="legal-draft-note">
        Draft only: confirm API and hosting log retention before publishing this as the official policy.
      </aside>

      <article className="legal-copy" lang="en" dir="ltr">
        <p>This policy describes the Cairo Bible iOS app. The app does not require an account.</p>

        <h2>Information on your device</h2>
        <p>Your language, translation, display preferences, and reminder settings are saved on your device. Optional daily reminders are scheduled as local iOS notifications. Arabic Smith &amp; Van Dyck (SVD) scripture is included in the app and can be read offline. NIV chapters you open are cached on your device for up to 29 days.</p>

        <h2>Information sent to our service</h2>
        <p>Reading SVD does not require a network request. When you request an NIV chapter that is not available in your local cache, the app sends the selected book and chapter to our Bible service at <span dir="ltr">api.bible.cairolove.site</span>. Like other internet services, the service and its hosting providers receive connection information, such as your IP address, needed to handle the request.</p>
        <p>If NIV access is enabled, our service may retrieve licensed scripture from API.Bible. API.Bible credentials are kept on our server; the app does not send them. We do not create a user profile or account from your reading requests.</p>

        <h2>Tracking and sharing</h2>
        <p>The iOS app contains no advertising or analytics SDKs and does not use cross-app tracking. We do not sell personal information. Service providers may process connection information to operate and protect the service.</p>

        <h2>Your choices</h2>
        <p>You can turn off reminders in the app or in iOS notification settings. Removing the app deletes its locally stored preferences and chapter cache. For privacy questions, contact <a href="mailto:hi@cairolove.site">hi@cairolove.site</a>.</p>

        <h2>Changes</h2>
        <p>We will update this page if our privacy practices change. The date above indicates when this draft was prepared.</p>
      </article>

      <hr className="legal-divider" />

      <article className="legal-copy" lang="ar" dir="rtl">
        <h2>سياسة الخصوصية</h2>
        <p>توضح هذه السياسة طريقة تعامل تطبيق Cairo Bible لنظام iOS مع المعلومات. لا يتطلب التطبيق إنشاء حساب.</p>

        <h2>المعلومات المحفوظة على جهازك</h2>
        <p>يحفظ التطبيق لغتك والترجمة وتفضيلات العرض وإعدادات التذكير على جهازك. وتُجدول التذكيرات اليومية الاختيارية كإشعارات محلية في iOS. ترجمة فان دايك العربية (SVD) مضمّنة في التطبيق ويمكن قراءتها دون اتصال. تُحفظ إصحاحات NIV التي تفتحها على جهازك لمدة تصل إلى 29 يومًا.</p>

        <h2>المعلومات المرسلة إلى خدمتنا</h2>
        <p>لا يحتاج قراءة ترجمة فان دايك إلى اتصال بالشبكة. عند طلب إصحاح NIV غير موجود في النسخة المحفوظة على جهازك، يرسل التطبيق اسم السفر ورقم الإصحاح إلى خدمة الكتاب المقدس لدينا على <span dir="ltr">api.bible.cairolove.site</span>. وتتلقى الخدمة ومزوّدو الاستضافة معلومات الاتصال المعتادة، مثل عنوان IP، اللازمة لمعالجة الطلب.</p>
        <p>إذا فُعّل الوصول إلى NIV، فقد تسترجع خدمتنا النص المرخّص من API.Bible. تبقى بيانات اعتماد API.Bible على خادمنا ولا يرسلها التطبيق. لا ننشئ حسابًا أو ملفًا شخصيًا للمستخدم استنادًا إلى طلبات القراءة.</p>

        <h2>التتبّع والمشاركة</h2>
        <p>لا يتضمن تطبيق iOS أدوات إعلانات أو تحليلات، ولا يستخدم التتبّع بين التطبيقات. لا نبيع المعلومات الشخصية. وقد يعالج مزوّدو الخدمة معلومات الاتصال لتشغيل الخدمة وحمايتها.</p>

        <h2>خياراتك</h2>
        <p>يمكنك إيقاف التذكيرات من التطبيق أو من إعدادات الإشعارات في iOS. يؤدي حذف التطبيق إلى إزالة تفضيلاتك ونسخ الإصحاحات المحفوظة محليًا. للاستفسارات المتعلقة بالخصوصية، راسلنا على <a href="mailto:hi@cairolove.site" dir="ltr">hi@cairolove.site</a>.</p>

        <h2>التغييرات</h2>
        <p>سنحدّث هذه الصفحة عند تغيير ممارسات الخصوصية. يوضح التاريخ أعلاه موعد إعداد هذه المسودة.</p>
      </article>
      <footer className="legal-footer">
        <Link href="/support">Contact support · تواصل مع الدعم</Link>
      </footer>
    </main>
  );
}
