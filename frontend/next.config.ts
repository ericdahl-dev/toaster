import type { NextConfig } from "next";

/** /api/backend → Rails is handled in src/middleware.ts so X-Forwarded-Host reaches Puma. */
const nextConfig: NextConfig = {};

export default nextConfig;
