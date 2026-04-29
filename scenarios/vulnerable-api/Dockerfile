# C2C Test Scenario: Vulnerable API with ajv@6.12.2 (CVE-2020-15366) and lodash@4.17.15 (CVE-2020-8203)
#
# Purpose: Container image with intentional vulnerabilities for C2C security mapping validation
# WARNING: FOR TESTING ONLY - DO NOT USE IN PRODUCTION
#
# INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
#
# Vulnerability Surface:
#   1. npm packages: ajv@6.12.2 (CVE-2020-15366 — Prototype Pollution)
#   2. npm packages: lodash@4.17.15 (CVE-2020-8203 — Prototype Pollution)
#   3. npm packages: express@4.17.1 (known CVEs in version range)
#
# C2C Mapping Points:
#   - OCI labels link container to source repo for correlation
#   - Baked-in dependencies ensure reproducible vulnerability state
#   - Same CVEs detectable at build time, image scan time, and runtime

FROM node:18-slim

# OCI Image Labels for Code-to-Cloud correlation
LABEL org.opencontainers.image.source="https://github.com/thechmodmaster/code2cloud-scenarios"
LABEL org.opencontainers.image.description="Code-to-Cloud vulnerable REST API test scenario - INTENTIONAL VULNERABILITIES FOR TESTING"
LABEL org.opencontainers.image.title="c2c-vuln-api"
LABEL org.opencontainers.image.vendor="code2cloud-test"
LABEL org.opencontainers.image.version="1.0.0"
LABEL c2c.test.primary-cve="CVE-2020-15366"
LABEL c2c.test.secondary-cve="CVE-2020-8203"
LABEL c2c.test.purpose="security-mapping-validation"

WORKDIR /app

# Copy package.json first for layer caching
COPY app/package.json ./

# Install dependencies with exact versions (bakes vulnerable deps into the image layer)
RUN npm install --production && \
    npm cache clean --force

# Copy application code
COPY app/server.js ./

# Expose API port (3001 — different from vulnerable-container which uses 3000)
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Run the application (non-root omitted intentionally for test simplicity)
CMD ["node", "server.js"]
