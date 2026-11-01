import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

// Fonts come from the system (see globals.css), so building the app needs no network.
export const metadata: Metadata = {
  title: "Hold'em",
  description: "Heads-up no-limit Texas Hold'em against one bot you build with two sliders, Risk and Bluff.",
};

export const viewport: Viewport = {
  themeColor: "#0a0e13",
  colorScheme: "dark",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
