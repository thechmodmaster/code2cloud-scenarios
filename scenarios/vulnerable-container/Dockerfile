# Code-to-Cloud Vulnerable Test Fixture - Dockerfile
#
# Purpose: Container image with intentional vulnerabilities for C2C security mapping validation
# WARNING: FOR TESTING ONLY - DO NOT USE IN PRODUCTION
#
# Vulnerability Surface:
# 1. Base Image: node:16-alpine (Node.js 16 is EOL with known CVEs)
# 2. npm packages: ajv@6.12.2 (CVE-2020-15366), express@4.17.1 (known CVEs)
# 3. Transitive dependencies with known vulnerabilities
#
# C2C Mapping Points:
# - OCI labels link container to source repo for correlation
# - Baked-in package-lock.json ensures reproducible vulnerability state
# - Same CVEs detectable at build time, image scan time, and runtime

# Use EOL Node.js 16 on Alpine (adds base image vulnerabilities)
FROM node:16-alpine

# OCI Image Labels for Code-to-Cloud correlation
# These labels enable scanners to link this image back to source code
LABEL org.opencontainers.image.source="https://github.com/thechmodmaster/code2cloud-scenarios"
LABEL org.opencontainers.image.description="Code-to-Cloud vulnerable test scenario - INTENTIONAL VULNERABILITIES FOR TESTING"
LABEL org.opencontainers.image.title="c2c-vuln-app"
LABEL org.opencontainers.image.vendor="code2cloud-test"
LABEL org.opencontainers.image.version="1.0.0"
LABEL c2c.test.primary-cve="CVE-2020-15366"
LABEL c2c.test.purpose="security-mapping-validation"

# Set working directory
WORKDIR /app

# Copy package.json first for layer caching optimization
# This ensures npm install runs only when dependencies change
COPY app/package.json ./

# Install dependencies with exact versions (creates package-lock.json)
# This bakes the vulnerable dependency tree into the image layer
# Scanners will detect these in the image filesystem
RUN npm install --production && \
    npm cache clean --force

# Copy application code
# Done after npm install to optimize Docker layer caching
COPY app/server.js ./

# Expose application port
EXPOSE 3000

# Health check for container orchestration
# Ensures the app is responsive when deployed
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Run the application
# Non-root user would be security best practice, but intentionally omitted
# to maintain simplified test scenario
CMD ["node", "server.js"]
