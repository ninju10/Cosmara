# ============================================================
# COSMARA Space Exploration Website
# Serves static HTML/CSS via nginx (Alpine-based, ~23MB image)
# ============================================================

FROM nginx:alpine

# Set metadata labels for CI/CD
LABEL maintainer="your-email@example.com"
LABEL description="COSMARA Space Exploration Website"
LABEL version="1.0"

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy website files into nginx serve directory
COPY index.html /usr/share/nginx/html/index.html
COPY styles.css /usr/share/nginx/html/styles.css

# Create nginx configuration for better performance and caching
RUN echo 'server { \
    listen 80 default_server; \
    listen [::]:80 default_server; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ { \
        expires 30d; \
        add_header Cache-Control "public, immutable"; \
    } \
    location / { \
        try_files $uri $uri/ =404; \
    } \
    error_page 404 /index.html; \
}' > /etc/nginx/conf.d/default.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Expose port 80
EXPOSE 80

# Create non-root user for security (nginx runs as nginx by default)
# This is already done in the base image

# nginx runs in the foreground by default in the official image
CMD ["nginx", "-g", "daemon off;"]
