import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Publicado em https://octaviokonzen.github.io/Pocketdex/
export default defineConfig({
  base: '/Pocketdex/',
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'node',
  },
})
