import type { NextConfig } from "next";

const proxyTarget = process.env.TOASTER_API_PROXY_TARGET ?? "http://127.0.0.1:3001";

const nextConfig: NextConfig = {
  async rewrites() {
    return [{ source: "/api/backend/:path*", destination: `${proxyTarget}/:path*` }];
  },
};

export default nextConfig;
