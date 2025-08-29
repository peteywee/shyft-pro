/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // If you use App Router (app/), this is already default in Next 13+.
  // experimental: { appDir: true },

  // If you’re using middleware or edge APIs, you can opt into edge runtime defaults here.
  // experimental: { runtime: 'nodejs' },

  // Example headers/rewrites (uncomment if you need):
  // async headers() { return []; },
  // async rewrites() { return []; },
};

export default nextConfig;
