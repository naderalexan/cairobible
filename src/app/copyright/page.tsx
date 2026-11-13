import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Copyright — Cairo Bible",
  description: "Copyright and source acknowledgements for Cairo Bible scripture and app materials.",
};

export default function CopyrightPage() {
  return (
    <main className="legal-page" lang="en" dir="ltr">
      <nav className="legal-nav" aria-label="Cairo Bible links">
        <Link href="/">Cairo Bible</Link>
        <Link href="/privacy">Privacy</Link>
        <Link href="/support">Support</Link>
      </nav>
      <header className="legal-header">
        <p className="legal-eyebrow">CAIRO BIBLE · SCRIPTURE &amp; APP</p>
        <h1>Copyright</h1>
        <p>Copyright notices and source acknowledgements for the content and materials used by Cairo Bible.</p>
      </header>

      <article className="legal-copy" lang="en" dir="ltr">
        <h2>Arabic Smith &amp; Van Dyck (SVD)</h2>
        <p>The Arabic Van Dyck Bible text is sourced from <a href="https://ebible.org/Scriptures/details.php?id=arb-vd">eBible.org</a>, which lists this translation as public domain and credits the Syrian Mission and American Bible Society. The text is provided in Cairo Bible for reading; the source and its credits remain acknowledged here.</p>

        <h2>New International Version (NIV)</h2>
        <p>NIV scripture is not bundled with Cairo Bible. If NIV access is enabled, the applicable copyright notice supplied with each chapter is displayed alongside that chapter. NIV and related marks are the property of their respective rights holders. Access depends on the required content permissions.</p>

        <h2>Cairo Bible app and design materials</h2>
        <p>Unless otherwise noted, the Cairo Bible app code, name, and original design materials are © 2026 Cairo Bible. Montserrat and Yellowtail font license notices are included with the font files in the app.</p>

        <h2>Questions</h2>
        <p>For copyright questions, contact <a href="mailto:hi@cairolove.site?subject=Cairo%20Bible%20Copyright">hi@cairolove.site</a>.</p>
      </article>

      <hr className="legal-divider" />

      <article className="legal-copy" lang="ar" dir="rtl">
        <h2>حقوق النشر</h2>
        <p>توضح هذه الصفحة مصادر النصوص والتنويهات المتعلقة بحقوق النشر للمواد المستخدمة في Cairo Bible.</p>

        <h2>الترجمة العربية فان دايك (SVD)</h2>
        <p>نص الكتاب المقدس العربي فان دايك مصدره <a href="https://ebible.org/Scriptures/details.php?id=arb-vd" dir="ltr">eBible.org</a>، الذي يذكر أن هذه الترجمة ضمن الملكية العامة، وينسبها إلى الإرسالية السورية وجمعية الكتاب المقدس الأمريكية. نقرّ بالمصدر وأصحاب الفضل المذكورين فيه.</p>

        <h2>الترجمة الدولية الجديدة (NIV)</h2>
        <p>لا يتضمن Cairo Bible نص NIV ضمن ملفاته. إذا فُعّل الوصول إلى NIV، يظهر تنويه حقوق النشر المرفق بكل إصحاح بجواره. ترجمة NIV والعلامات المرتبطة بها ملك لأصحاب الحقوق المعنيين، ويعتمد الوصول إليها على الأذونات اللازمة.</p>

        <h2>تطبيق Cairo Bible ومواد التصميم</h2>
        <p>ما لم يُذكر خلاف ذلك، فإن الشيفرة واسم Cairo Bible ومواد التصميم الأصلية © 2026 Cairo Bible. تتضمن ملفات الخطين Montserrat وYellowtail إشعارات الترخيص الخاصة بهما.</p>

        <h2>الاستفسارات</h2>
        <p>للاستفسار عن حقوق النشر، راسلنا على <a href="mailto:hi@cairolove.site?subject=Cairo%20Bible%20Copyright" dir="ltr">hi@cairolove.site</a>.</p>
      </article>
      <footer className="legal-footer">
        <Link href="/support">Contact support · تواصل مع الدعم</Link>
      </footer>
    </main>
  );
}
