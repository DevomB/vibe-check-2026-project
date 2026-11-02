import type { Metadata } from "next";
import { KuhnApp } from "@/components/KuhnApp";

export const metadata: Metadata = {
  title: "FoldProof · Kuhn poker",
  description: "Kuhn poker against a bot that plays a proven Nash equilibrium.",
};

export default function KuhnPage() {
  return <KuhnApp />;
}
