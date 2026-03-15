import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  base: '/watchwaves/',
  plugins: [
    react(),
    tailwindcss(),
  ],
  server: {
    proxy: {
      '/snapshots-proxy': {
        target: 'https://cdn.skylinewebcams.com',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/snapshots-proxy/, ''),
        headers: {
          Referer: 'https://www.skylinewebcams.com/',
        },
      },
    },
  },
})
