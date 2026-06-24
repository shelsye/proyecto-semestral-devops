# =========================================================
# Etapa 1: Build - compila la app React con Node.js
# =========================================================
FROM node:20-alpine AS builder
WORKDIR /app

# Copiamos los archivos de empaquetado primero para aprovechar el cache del pipeline
COPY package*.json ./
RUN npm ci

# Copiamos el resto del código del Frontend
COPY . .

# Compilamos la aplicación generando la carpeta estática /app/dist
RUN npm run build

# =========================================================
# Etapa 2: Serve - sirve el build con Nginx ultra-ligero
# Solo contiene los archivos estáticos compilados
# =========================================================
FROM nginx:stable-alpine

# Copiamos el build estático generado en la etapa anterior al directorio de Nginx
COPY --from=builder /app/dist /usr/share/nginx/html

# Copiamos tu archivo nginx.conf para el manejo correcto de rutas en React
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponemos el puerto estándar web
EXPOSE 80

# Comando para iniciar Nginx en primer plano dentro del contenedor de AWS
CMD ["nginx", "-g", "daemon off;"]