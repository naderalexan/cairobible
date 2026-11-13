import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "License — Cairo Bible",
  description: "MIT License for the Cairo Bible codebase.",
};

export default function LicensePage() {
  return (
    <main className="legal-page" lang="en" dir="ltr">
      <nav className="legal-nav" aria-label="Cairo Bible links">
        <Link href="/">Cairo Bible</Link>
        <Link href="/privacy">Privacy</Link>
        <Link href="/support">Support</Link>
        <Link href="/copyright">Copyright</Link>
      </nav>
      <header className="legal-header">
        <p className="legal-eyebrow">CAIRO BIBLE · CODE</p>
        <h1>MIT License</h1>
        <p>Copyright © 2026 Cairo Bible</p>
      </header>

      <article className="legal-copy" lang="en" dir="ltr">
        <p>Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:</p>
        <p>The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.</p>
        <p>THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.</p>
        <p>This license applies to the Cairo Bible codebase. Scripture and other third-party materials remain subject to their respective notices and licenses.</p>
      </article>
      <footer className="legal-footer">
        <Link href="/copyright">Copyright and source acknowledgements</Link>
      </footer>
    </main>
  );
}
