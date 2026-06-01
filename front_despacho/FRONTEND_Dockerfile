# =========================================================
# Etapa 1: Build - compila la app React con Node.js
# =========================================================
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# =========================================================
# Etapa 2: Serve - sirve el build con Nginx ultra-ligero
# Solo contiene los archivos estáticos compilados
# =========================================================
FROM nginx:stable-alpine

# SEGURIDAD: nginx:stable-alpine ya corre como usuario no-root
# en el proceso worker. El proceso master necesita root para
# abrir el puerto 80, pero los workers corren como 'nginx'.
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
