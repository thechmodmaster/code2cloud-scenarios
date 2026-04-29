/**
 * Code-to-Cloud Vulnerable Test Fixture — REST API Scenario
 *
 * Purpose: Test scenario for C2C security mapping validation
 * Contains: Intentional vulnerabilities:
 *   - ajv@6.12.2 (CVE-2020-15366 — Prototype Pollution via crafted JSON schema)
 *   - lodash@4.17.15 (CVE-2020-8203 — Prototype Pollution via _.merge)
 * WARNING: FOR TESTING ONLY - DO NOT USE IN PRODUCTION
 *
 * // INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
 */

'use strict';

const express = require('express');
const Ajv = require('ajv');
// INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
// lodash@4.17.15 is vulnerable to Prototype Pollution (CVE-2020-8203)
const _ = require('lodash');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3001;

// --- AJV Setup (CVE-2020-15366) ---
// INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
// ajv@6.12.2 is vulnerable to Prototype Pollution via crafted JSON schema
const ajv = new Ajv({ allErrors: true, removeAdditional: 'all' });

const userSchema = {
  type: 'object',
  properties: {
    username: { type: 'string', minLength: 1, maxLength: 64 },
    email: { type: 'string', format: 'email' },
    role: { type: 'string', enum: ['viewer', 'editor', 'admin'] }
  },
  required: ['username', 'email'],
  additionalProperties: false
};

const configSchema = {
  type: 'object',
  properties: {
    theme: { type: 'string', enum: ['light', 'dark'] },
    notifications: { type: 'boolean' },
    locale: { type: 'string', pattern: '^[a-z]{2}-[A-Z]{2}$' }
  },
  additionalProperties: false
};

const validateUser = ajv.compile(userSchema);
const validateConfig = ajv.compile(configSchema);

// --- In-memory store ---
let users = {};

// --- Routes ---

// GET / — Service info
app.get('/', (req, res) => {
  res.json({
    app: 'c2c-vuln-api',
    version: '1.0.0',
    purpose: 'Code-to-Cloud vulnerability mapping test fixture — REST API',
    warning: 'CONTAINS INTENTIONAL VULNERABILITIES - FOR TESTING ONLY',
    vulnerabilities: {
      ajv: { version: '6.12.2', cve: 'CVE-2020-15366', type: 'Prototype Pollution' },
      lodash: { version: '4.17.15', cve: 'CVE-2020-8203', type: 'Prototype Pollution' }
    }
  });
});

// GET /health — Health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', uptime: process.uptime() });
});

// POST /api/users — Create user (uses ajv validation)
// INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
app.post('/api/users', (req, res) => {
  const valid = validateUser(req.body);
  if (!valid) {
    return res.status(400).json({
      error: 'Validation failed',
      details: validateUser.errors
    });
  }

  const id = `user_${Date.now()}`;
  // INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
  // _.merge is the vulnerable function in lodash@4.17.15 (CVE-2020-8203)
  // An attacker can craft __proto__ payloads to pollute Object.prototype
  users[id] = _.merge({}, { id, createdAt: new Date().toISOString() }, req.body);

  res.status(201).json(users[id]);
});

// GET /api/users — List users
app.get('/api/users', (req, res) => {
  res.json({ count: Object.keys(users).length, users: Object.values(users) });
});

// PUT /api/users/:id/config — Update user config (uses ajv + lodash)
// INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
app.put('/api/users/:id/config', (req, res) => {
  const { id } = req.params;
  if (!users[id]) {
    return res.status(404).json({ error: 'User not found' });
  }

  const valid = validateConfig(req.body);
  if (!valid) {
    return res.status(400).json({
      error: 'Config validation failed',
      details: validateConfig.errors
    });
  }

  // INTENTIONAL VULNERABILITY - FOR C2C TESTING ONLY
  // Deep merge user config using vulnerable lodash@4.17.15
  users[id] = _.merge(users[id], { config: req.body });
  res.json(users[id]);
});

// --- Start ---
app.listen(PORT, () => {
  console.log(`[C2C Test] Vulnerable API running on port ${PORT}`);
  console.log(`[C2C Test] WARNING: Contains intentional vulnerabilities for testing`);
  console.log(`[C2C Test] CVEs: CVE-2020-15366 (ajv@6.12.2), CVE-2020-8203 (lodash@4.17.15)`);
});
