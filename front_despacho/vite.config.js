import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

export default defineConfig({
  plugins: [react()],
  server: {
    host: true, // <-- Permite recibir el tráfico externo
    port: 5173, // <-- Fija el puerto interno
    proxy: {
      '/api': {
        target: 'https://qic534o8o0.execute-api.us-east-1.amazonaws.com',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  }
})

