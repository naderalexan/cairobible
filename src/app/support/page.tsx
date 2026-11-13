import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Support — Cairo Bible",
  description: "Get help with the Cairo Bible iOS app.",
};

export default function SupportPage() {
  return (
    <main className="legal-page" lang="en" dir="ltr">
      <nav className="legal-nav" aria-label="Cairo Bible links">
        <Link href="/">Cairo Bible</Link>
        <Link href="/privacy">Privacy</Link>
        <Link href="/copyright">Copyright</Link>
        <Link href="/license">License</Link>
      </nav>
      <header className="legal-header">
        <p className="legal-eyebrow">CAIRO BIBLE · IOS APP</p>
        <h1>Support</h1>
        <p>We’re here to help with the Cairo Bible app.</p>
      </header>

      <section className="legal-copy" lang="en" dir="ltr">
        <h2>Contact us</h2>
        <p>Email <a href="mailto:hi@cairolove.site?subject=Cairo%20Bible%20iOS%20Support">hi@cairolove.site</a> and tell us what happened. If you can, include your iPhone model and iOS version. Please don’t include passwords or other sensitive information.</p>

        <h2>Common questions</h2>
        <h3>Can I read without an internet connection?</h3>
        <p>Arabic Smith &amp; Van Dyck (SVD) is included in the app and can be read offline. NIV chapters require an internet connection unless they are already in the app’s temporary chapter cache.</p>

        <h3>Why can’t I open an NIV chapter?</h3>
        <p>NIV access depends on the availability of the Bible service and the applicable content permissions. Check your internet connection and try again later.</p>

        <h3>How do I manage daily reminders?</h3>
        <p>Use the reminder controls in the app. If reminders do not appear, make sure notifications are allowed for Cairo Bible in iOS Settings.</p>

        <p className="legal-contact"><a className="legal-button" href="mailto:hi@cairolove.site?subject=Cairo%20Bible%20iOS%20Support">Email support</a></p>
      </section>

      <hr className="legal-divider" />

      <section className="legal-copy" lang="ar" dir="rtl">
        <h2>الدعم</h2>
        <p>راسلنا على <a href="mailto:hi@cairolove.site?subject=Cairo%20Bible%20iOS%20Support" dir="ltr">hi@cairolove.site</a> واشرح ما حدث. إن أمكن، اذكر طراز iPhone وإصدار iOS. يُرجى عدم إرسال كلمات المرور أو أي معلومات حساسة.</p>

        <h2>أسئلة شائعة</h2>
        <h3>هل يمكنني القراءة دون اتصال بالإنترنت؟</h3>
        <p>ترجمة فان دايك العربية (SVD) مضمّنة في التطبيق ويمكن قراءتها دون اتصال. تتطلب إصحاحات NIV اتصالًا بالإنترنت، إلا إذا كانت محفوظة مؤقتًا في التطبيق.</p>

        <h3>لماذا لا أستطيع فتح إصحاح من NIV؟</h3>
        <p>يعتمد الوصول إلى NIV على توفر خدمة الكتاب المقدس وأذونات المحتوى اللازمة. تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى لاحقًا.</p>

        <h3>كيف أدير التذكيرات اليومية؟</h3>
        <p>استخدم إعدادات التذكير في التطبيق. إذا لم تظهر التذكيرات، فتأكد من السماح بإشعارات Cairo Bible ضمن إعدادات iOS.</p>

        <p className="legal-contact"><a className="legal-button" href="mailto:hi@cairolove.site?subject=Cairo%20Bible%20iOS%20Support">راسل الدعم</a></p>
      </section>

      <footer className="legal-footer">
        <Link href="/privacy">Privacy Policy · سياسة الخصوصية</Link>
      </footer>
    </main>
  );
}
