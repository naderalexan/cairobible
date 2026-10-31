import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cairo Bible — Bible reader",
  description: "A warm, offline-ready Bible reader for NIV and Arabic SVD.",
  applicationName: "Cairo Bible",
  manifest: "/manifest.webmanifest",
  icons: { icon: "/icons/cairo-bible.svg", apple: "/icons/cairo-bible.svg" },
};

export const viewport: Viewport = {
  themeColor: "#F3E8DC",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
