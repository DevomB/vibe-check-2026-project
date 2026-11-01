import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import type { ReactNode } from "react";
import "./globals.css";

// The fonts ship with the app (src/app/fonts, SIL Open Font License), so building it needs no
// network. Bodoni Moda, the serif of classic playing cards, sets titles, results and card ranks;
// Libre Franklin sets everything you read.
const display = localFont({
  src: [
    { path: "./fonts/bodoni-moda-latin.woff2", style: "normal" },
    { path: "./fonts/bodoni-moda-italic-latin.woff2", style: "italic" },
  ],
  weight: "400 900",
  variable: "--font-display",
  display: "swap",
});

const text = localFont({
  src: "./fonts/libre-franklin-latin.woff2",
  weight: "100 900",
  variable: "--font-text",
  display: "swap",
});

export const metadata: Metadata = {
  title: "FoldProof",
  description: "Heads-up no-limit Texas Hold'em against one bot you build with one slider, Risk.",
};

export const viewport: Viewport = {
  themeColor: "#0e1613",
  colorScheme: "dark",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${text.variable}`}>
      <body>{children}</body>
    </html>
  );
}
