import type { NextConfig } from "next";

// Keep `next build` off the network, so it works on bad venue Wi-Fi. Fonts are system fonts
// (src/app/layout.tsx). Telemetry would send usage data; set before the build reads it.
process.env.NEXT_TELEMETRY_DISABLED ??= "1";

const config: NextConfig = {
  reactStrictMode: true,
  experimental: {
    // On by default in Next 16: `next build` asks the npm registry for security advisories.
    agentUpgrade: false,
  },
};

export default config;
