import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// =====================================================================
// Configuración de Vite
// El proxy de desarrollo replica el comportamiento de Nginx en producción:
// el backend Spring Boot espera el prefijo /api (@RequestMapping("api/v1/..."))
// por lo que NO se reescribe la ruta (sin "rewrite").
// En local: levantar Despachos en :8080 y (opcional) Ventas en :8081.
// =====================================================================
export default defineConfig({
  plugins: [react()],
  server: {
    host: true,       // Permite recibir tráfico externo
    port: 5173,       // Fija el puerto interno del dev server
    proxy: {
      // El orden importa: la ruta más específica primero
      '/api/v1/ventas': {
        target: 'http://localhost:8081',
        changeOrigin: true,
      },
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
})
