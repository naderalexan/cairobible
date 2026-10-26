import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Still — NIV Bible",
  description: "A quiet, offline-ready NIV Bible reader.",
  applicationName: "Still NIV",
  manifest: "/manifest.webmanifest",
  icons: { icon: "/icons/still.svg", apple: "/icons/still.svg" },
};

export const viewport: Viewport = {
  themeColor: "#f6f4ed",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
