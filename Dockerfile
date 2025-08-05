# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage using 11notes/nginx
FROM 11notes/nginx:1.28.0

# Copy built application to nginx webroot
COPY --from=builder /app/build /nginx/var

# Copy configuration and auth setup scripts
COPY scripts/generate-config.sh /usr/local/bin/generate-config.sh
COPY scripts/setup-nginx.sh /usr/local/bin/setup-nginx.sh

# Make scripts executable
USER root
RUN chmod +x /usr/local/bin/generate-config.sh /usr/local/bin/setup-nginx.sh
USER docker

# Expose configurable port (default 3000 for 11notes/nginx)
ARG NGINX_PORT=3000
ENV NGINX_PORT=${NGINX_PORT}
EXPOSE ${NGINX_PORT}

# Setup nginx config, generate frontend config, and start nginx
CMD ["/bin/sh", "-c", "/usr/local/bin/setup-nginx.sh && /usr/local/bin/generate-config.sh && nginx"]