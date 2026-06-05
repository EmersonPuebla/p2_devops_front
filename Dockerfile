# =========================================================
# ETAPA 1: Construcción (Node.js)
# =========================================================
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# =========================================================
# ETAPA 2: Servidor de Producción (Nginx - Multi-stage)
# =========================================================
FROM nginx:stable-alpine AS runner

WORKDIR /usr/share/nginx/html

# Limpiar archivos estáticos por defecto
RUN rm -rf ./*

# Copiar los archivos compilados de Vite
COPY --from=builder /app/dist .

# --- Configuración de Seguridad: Usuario No-Root ---
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S nginxuser -G appgroup

# Cambiar permisos de las carpetas necesarias para Nginx
RUN chown -R nginxuser:appgroup /usr/share/nginx/html /var/cache/nginx /var/run /var/log/nginx

# 1. Borrar configuraciones por defecto que causan conflictos de permisos/duplicados
RUN rm -f /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf

# 2. Crear una configuración de Nginx limpia, optimizada y 100% NO-ROOT
RUN echo 'worker_processes auto;' > /etc/nginx/nginx.conf && \
    echo 'pid /tmp/nginx.pid;' >> /etc/nginx/nginx.conf && \
    echo 'events { worker_connections 1024; }' >> /etc/nginx/nginx.conf && \
    echo 'http {' >> /etc/nginx/nginx.conf && \
    echo '    include /etc/nginx/mime.types;' >> /etc/nginx/nginx.conf && \
    echo '    default_type application/octet-stream;' >> /etc/nginx/nginx.conf && \
    echo '    server {' >> /etc/nginx/nginx.conf && \
    echo '        listen 8080;' >> /etc/nginx/nginx.conf && \
    echo '        server_name localhost;' >> /etc/nginx/nginx.conf && \
    echo '        location / {' >> /etc/nginx/nginx.conf && \
    echo '            root /usr/share/nginx/html;' >> /etc/nginx/nginx.conf && \
    echo '            index index.html index.htm;' >> /etc/nginx/nginx.conf && \
    echo '            try_files $uri $uri/ /index.html;' >> /etc/nginx/nginx.conf && \
    echo '        }' >> /etc/nginx/nginx.conf && \
    echo '    }' >> /etc/nginx/nginx.conf && \
    echo '}' >> /etc/nginx/nginx.conf

# Cambiar el dueño del nuevo archivo de configuración al usuario seguro
RUN chown nginxuser:appgroup /etc/nginx/nginx.conf

# Cambiar al usuario sin privilegios
USER nginxuser

# Exponer el puerto configurado en el archivo limpio
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
