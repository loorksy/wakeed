module.exports = {
  apps: [
    {
      name: 'wakeed-import',
      cwd: '/var/www/wakeed.lork.cloud',
      script: 'server/index.js',
      interpreter: 'node',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production',
        PORT: 3030,
        WAKEED_BASE_URL: 'https://server1.wakeed.app',
        WAKEED_BUILD_NUMBER: '12000',
        WEB_DIST: '/var/www/wakeed.lork.cloud/web/dist',
      },
    },
  ],
};
