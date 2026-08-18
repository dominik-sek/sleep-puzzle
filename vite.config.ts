import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    tailwindcss(),
  ],
  optimizeDeps: {
    include: ['dayjs', 'dayjs/locale/pl'],
  },
  server: {
    // skipProxy makes asset URLs absolute (localhost:3036), so serving the app
    // through the Cloudflare tunnel makes every asset request cross-origin
    cors: {
      origin: [
        /^https?:\/\/localhost(:\d+)?$/,
        /^https:\/\/sleep-puzzle\.dominiksek\.pl$/,
      ],
    },
  },
})
