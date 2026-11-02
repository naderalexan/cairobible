import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cairo Bible — قارئ الكتاب المقدس",
  description: "قارئ دافئ للكتاب المقدس، يعمل دون اتصال ويضم ترجمة سميث وفاندايك العربية.",
  applicationName: "Cairo Bible",
  manifest: "/manifest.webmanifest",
  icons: { icon: "/icons/cairo-bible.svg", apple: "/icons/cairo-bible.svg" },
};

export const viewport: Viewport = {
  themeColor: "#F3E8DC",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
