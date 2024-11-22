import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  eslint: {
    ignoreDuringBuilds: true
  },
  experimental: {
    after: true,
  },
  env: {
    INKEEP_TELEMETRY_DISABLED: process.env.INKEEP_TELEMETRY_DISABLED
  }
};

export default nextConfig;
