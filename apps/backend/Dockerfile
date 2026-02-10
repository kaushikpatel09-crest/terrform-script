FROM node:18-alpine

WORKDIR /app

# Copy package.json (package-lock.json may be absent in the workspace)
COPY package.json ./

# Install dependencies (use npm install when package-lock.json is not present)
RUN npm install --only=production --no-audit --no-fund

# Copy application code
COPY server.js .

# Expose port 8080
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/health || exit 1

# Start application
CMD ["node", "server.js"]
