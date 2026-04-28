/**
 * Code-to-Cloud Vulnerable Test Fixture
 * 
 * Purpose: Test scenario for C2C security mapping validation
 * Contains: Intentional vulnerabilities (ajv@6.12.2 CVE-2020-15366)
 * WARNING: FOR TESTING ONLY - DO NOT USE IN PRODUCTION
 * 
 * This server demonstrates how the same vulnerability can be detected at:
 * - Source code level (package.json dependency)
 * - Container image level (baked into image layers)
 * - Runtime scanner level (Defender, Trivy, Qualys)
 */

const express = require('express');
const Ajv = require('ajv');

const app = express();
const PORT = process.env.PORT || 3000;

// Create an ajv validator instance to ensure the dependency is actually used
// This ensures scanners detect it as an active runtime dependency, not just listed
const ajv = new Ajv({ allErrors: true });

// Simple JSON schema for demonstration
const schema = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    age: { type: 'number' }
  },
  required: ['name']
};

const validate = ajv.compile(schema);

// Root endpoint - returns app information
app.get('/', (req, res) => {
  res.json({
    app: 'c2c-vuln-app',
    version: '1.0.0',
    purpose: 'Code-to-Cloud vulnerability mapping test fixture',
    warning: 'CONTAINS INTENTIONAL VULNERABILITIES - FOR TESTING ONLY',
    vulnerabilities: {
      ajv: {
        version: '6.12.2',
        cve: 'CVE-2020-15366',
        type: 'Prototype Pollution',
        severity: 'Medium',
        fixed_in: '6.12.3+'
      },
      express: {
        version: '4.17.1',
        note: 'Contains known vulnerabilities in this version range'
      }
    },
    status: 'operational'
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Vulnerability information endpoint for test verification
app.get('/vuln-info', (req, res) => {
  res.json({
    test_scenario: 'Code-to-Cloud Security Mapping',
    detection_levels: [
      'Source Code Analysis (package.json)',
      'Container Image Scanning (baked dependencies)',
      'Runtime Vulnerability Scanners (Defender, Trivy, Qualys)'
    ],
    primary_cve: {
      id: 'CVE-2020-15366',
      component: 'ajv',
      version: '6.12.2',
      description: 'Prototype Pollution vulnerability via crafted JSON schema',
      cvss_score: '5.6',
      fix: 'Upgrade to ajv@6.12.3 or higher'
    },
    additional_vulns: {
      runtime: 'Node.js 16 (EOL - End of Life)',
      framework: 'Express 4.17.1 (known CVEs in version range)'
    },
    ajv_validator_active: typeof validate === 'function',
    note: 'This endpoint confirms the vulnerable dependency is loaded and active'
  });
});

// Validation endpoint (demonstrates ajv is actually in use)
app.post('/validate', express.json(), (req, res) => {
  const valid = validate(req.body);
  if (valid) {
    res.json({ valid: true, data: req.body });
  } else {
    res.status(400).json({ valid: false, errors: validate.errors });
  }
});

app.listen(PORT, () => {
  console.log(`[C2C Test] Vulnerable app running on port ${PORT}`);
  console.log(`[C2C Test] WARNING: Contains intentional vulnerabilities for testing`);
  console.log(`[C2C Test] Primary CVE: CVE-2020-15366 (ajv@6.12.2)`);
});
