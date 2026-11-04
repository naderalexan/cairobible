import type { Metadata, Viewport } from "next";
import Script from "next/script";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cairo Bible — قارئ الكتاب المقدس",
  description: "قارئ دافئ للكتاب المقدس، يعمل دون اتصال ويضم ترجمة سميث وفاندايك العربية.",
  applicationName: "Cairo Bible",
  manifest: "/manifest.webmanifest",
  icons: { icon: "/icons/cairo-bible-192.png", apple: "/icons/cairo-bible-180.png" },
};

export const viewport: Viewport = {
  themeColor: "#F3E8DC",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ar" dir="rtl">
      <body>
        <Script id="api-bible-fums-queue" strategy="beforeInteractive">
          {`window.fumsData = window.fumsData || []; window.fums = window.fums || function () { window.fumsData.push(arguments); };`}
        </Script>
        {children}
      </body>
    </html>
  );
}
