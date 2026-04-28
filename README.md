# Code-to-Cloud Test Scenarios

⚠️ **WARNING: INTENTIONALLY VULNERABLE CODE**  
This repository contains **INTENTIONALLY VULNERABLE** dependencies for security testing purposes only.  
**DO NOT USE IN PRODUCTION.** These scenarios are designed to test Microsoft Defender for Cloud's Code-to-Cloud security mapping capabilities.

---

## Overview

**Purpose:** Test Code-to-Cloud security mapping and vulnerability correlation across the full DevSecOps pipeline.

**What it demonstrates:**
- Repository → GitHub Actions workflow → Docker image → Azure Container Registry → AKS deployment → vulnerability assessment
- End-to-end correlation from source code dependencies to running containers
- Vulnerability detection and traceability across the software supply chain

**Use case:** Validates that Microsoft Defender for Cloud can:
1. Discover GitHub repositories via connector
2. Map GitHub Actions workflows to container images
3. Track images from ACR to AKS workloads
4. Correlate vulnerabilities from source (package.json) to runtime (deployed containers)

### Correlation Chain Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  GitHub Repository (thechmodmaster/code2cloud-scenarios)            │
│  └─ package.json: ajv@6.12.2 (CVE-2020-15366)                       │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  GitHub Actions Workflow (c2c-vuln-container-build.yml)             │
│  └─ OIDC Authentication → Azure                                     │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Docker Build                                                        │
│  └─ Base: node:16-alpine + npm install ajv@6.12.2                   │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Azure Container Registry (c2cscenarioacr.azurecr.io)               │
│  └─ Image: c2cscenario/vuln-app:latest + digest                     │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  AKS Deployment (c2cscenario-aks)                                   │
│  └─ Namespace: c2c-scenarios                                        │
│  └─ Workload: vuln-app                                              │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Microsoft Defender for Cloud - Vulnerability Assessment            │
│  └─ CVE-2020-15366 (ajv@6.12.2 Prototype Pollution)                 │
│  └─ Traceable from repo → workflow → image → workload               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before getting started, ensure you have:

- **Azure CLI** (`az`) installed and authenticated (`az login`)
- **kubectl** installed (Kubernetes CLI)
- **GitHub CLI** (`gh`) installed (optional, for managing secrets)
- **Bash shell** (WSL, Git Bash, or Linux/macOS terminal)
- An **Azure subscription** with Owner or Contributor + User Access Administrator permissions
- A **GitHub repository** (fork or clone of `thechmodmaster/code2cloud-scenarios`)
- Permissions to configure GitHub repository secrets

---

## Architecture

| Component | Configuration |
|-----------|---------------|
| **GitHub Repo** | `thechmodmaster/code2cloud-scenarios` |
| **Azure Subscription** | Code2Cloud (`2484489b-da82-4300-9f01-406602c2efbc`) |
| **Tenant Domain** | `7d45cbc7657f85d6a9.onmicrosoft.com` |
| **Region** | East US |
| **Resource Group** | `c2cscenario-rg` |
| **ACR** | `c2cscenarioacr` (login: `c2cscenarioacr.azurecr.io`) |
| **AKS Cluster** | `c2cscenario-aks` |
| **Managed Identity** | `c2cscenario-github-identity` |
| **Image** | `c2cscenarioacr.azurecr.io/c2cscenario/vuln-app` |
| **K8s Namespace** | `c2c-scenarios` |
| **Test Vulnerability** | ajv@6.12.2 (CVE-2020-15366 - Prototype Pollution) |

---

## Setup

### Step 1: Deploy Azure Resources

The deployment script creates all required Azure infrastructure:

```bash
# Navigate to the repository root
cd code2cloud-scenarios

# Make the script executable
chmod +x infra/deploy-azure.sh

# Run the deployment
./infra/deploy-azure.sh
```

**What gets created:**
- ✅ Resource Group: `c2cscenario-rg`
- ✅ Azure Container Registry: `c2cscenarioacr` (Standard SKU)
- ✅ AKS Cluster: `c2cscenario-aks` (1 node, Standard_DS2_v2)
- ✅ Managed Identity: `c2cscenario-github-identity`
- ✅ Federated Credential: Configured for GitHub Actions OIDC (repo: `thechmodmaster/code2cloud-scenarios`)
- ✅ Role Assignments:
  - `AcrPush` on ACR (for image push)
  - `Azure Kubernetes Service Cluster User Role` on AKS (for deployment)

**Important:** Save the output from the script — you'll need the **Client ID** and **Tenant ID** for the next step.

---

### Step 2: Configure GitHub Repository Secrets

After the deployment script completes, configure these secrets in your GitHub repository:

| Secret Name | Value | Where to Get It |
|-------------|-------|-----------------|
| `AZURE_CLIENT_ID` | Managed Identity Client ID | Output from `deploy-azure.sh` script |
| `AZURE_TENANT_ID` | Azure Tenant ID | Output from `deploy-azure.sh` script |
| `AZURE_SUBSCRIPTION_ID` | `2484489b-da82-4300-9f01-406602c2efbc` | Fixed value (Code2Cloud subscription) |

#### Option A: Using GitHub CLI

```bash
# Set secrets using values from the deployment script output
gh secret set AZURE_CLIENT_ID --body "<client-id-from-script>"
gh secret set AZURE_TENANT_ID --body "<tenant-id-from-script>"
gh secret set AZURE_SUBSCRIPTION_ID --body "2484489b-da82-4300-9f01-406602c2efbc"
```

#### Option B: Using GitHub Web UI

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the values from the deployment script output

---

### Step 3: Run the Workflow

Trigger the vulnerable container build and deploy workflow:

#### Option A: Using GitHub CLI

```bash
gh workflow run c2c-vuln-container-build.yml
```

#### Option B: Using GitHub Web UI

1. Go to your repository on GitHub
2. Navigate to **Actions**
3. Select **C2C Vulnerable Container Build & Deploy**
4. Click **Run workflow** → **Run workflow**

**What the workflow does:**
1. Authenticates to Azure using OIDC (Workload Identity Federation)
2. Builds a Docker image containing ajv@6.12.2 (vulnerable)
3. Pushes the image to ACR with a unique digest
4. Updates the AKS deployment with the new image digest
5. Outputs correlation metadata (commit SHA, image digest, timestamps)

---

### Step 4: Create GitHub Connector in Microsoft Defender for Cloud

After the workflow completes successfully:

1. Open the **Azure Portal**
2. Navigate to **Microsoft Defender for Cloud**
3. Go to **Environment settings** → **Add environment** → **GitHub**
4. Follow the connector setup wizard:
   - Authenticate to GitHub
   - Select the repository: `thechmodmaster/code2cloud-scenarios`
   - Grant required permissions (read repository metadata, workflows, packages)
5. Wait for the connector to sync (typically 5-15 minutes)

---

## Verifying the Test Scenario

### Where to Find Image URI and Digest

The workflow generates correlation metadata that you'll need for verification:

**Locations:**
1. **GitHub Actions** → Select the workflow run → **Summary** tab (see "Correlation Summary")
2. **Workflow logs** → Expand the step "Print Correlation Summary"
3. **Azure CLI:**
   ```bash
   az acr repository show-tags --name c2cscenarioacr --repository c2cscenario/vuln-app --detail --output table
   ```

**Example output:**
```
Image URI: c2cscenarioacr.azurecr.io/c2cscenario/vuln-app@sha256:abc123...
Commit SHA: 1a2b3c4d
Build Time: 2024-01-15T10:30:00Z
```

---

### Verify Image Exists in ACR

```bash
# Show repository details
az acr repository show \
  --name c2cscenarioacr \
  --repository c2cscenario/vuln-app

# List all image manifests with details
az acr repository show-manifests \
  --name c2cscenarioacr \
  --repository c2cscenario/vuln-app \
  --detail \
  --output table
```

**Expected output:** You should see at least one manifest with tags (e.g., `latest`, `<commit-sha>`, `run-<run-id>`) and a digest starting with `sha256:`.

---

### Verify Image is Deployed to AKS

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group c2cscenario-rg \
  --name c2cscenario-aks

# Check pods in the c2c-scenarios namespace
kubectl get pods -n c2c-scenarios

# Describe the deployment to see the image
kubectl describe deployment vuln-app -n c2c-scenarios

# Check pod details (including image digest)
kubectl get pods -n c2c-scenarios -l app=vuln-app -o jsonpath='{.items[0].spec.containers[0].image}'
```

**Expected output:** 
- Pods should be in `Running` state
- Image should match: `c2cscenarioacr.azurecr.io/c2cscenario/vuln-app@sha256:...` (with digest, not `latest`)

---

### Code-to-Cloud Verification Checklist

After creating the GitHub connector in Microsoft Defender for Cloud, verify these correlations:

#### Repository Discovery
- [ ] Repository `thechmodmaster/code2cloud-scenarios` appears in Code-to-Cloud views
- [ ] Repository metadata is accurate (commit history, contributors)
- [ ] `package.json` with `ajv@6.12.2` is visible in source code view

#### Pipeline Mapping
- [ ] GitHub Actions workflow `c2c-vuln-container-build.yml` is discovered
- [ ] Workflow runs are visible with timestamps and commit SHAs
- [ ] Workflow → image mapping shows the correlation (workflow produced image X)

#### Container Image Correlation
- [ ] Container image `c2cscenarioacr.azurecr.io/c2cscenario/vuln-app` is visible
- [ ] Image digest matches the workflow output (verify exact `sha256:...` hash)
- [ ] Image tags include commit SHA and build run ID
- [ ] Image metadata shows creation timestamp and size

#### Azure Container Registry
- [ ] ACR `c2cscenarioacr` is discovered as a cloud resource
- [ ] Repository `c2cscenario/vuln-app` appears within the ACR
- [ ] Image → ACR association is clear

#### Vulnerability Assessment
- [ ] **CVE-2020-15366** (ajv Prototype Pollution) is detected
- [ ] Vulnerability severity is correctly reported (Medium/High)
- [ ] Affected package `ajv@6.12.2` is identified
- [ ] Remediation guidance suggests upgrading to `ajv@6.12.3` or later
- [ ] Vulnerability is **traceable** from:
  - Source: `package.json` in GitHub repo
  - Build: GitHub Actions workflow
  - Artifact: Container image in ACR
  - Runtime: AKS workload

#### AKS Workload Mapping
- [ ] AKS cluster `c2cscenario-aks` is discovered
- [ ] Namespace `c2c-scenarios` is visible
- [ ] Deployment `vuln-app` appears in workload views
- [ ] Workload → container image mapping is correct (shows same digest)
- [ ] Kubernetes workload references the vulnerable image
- [ ] Pod status is healthy (Running)

#### End-to-End Correlation
- [ ] You can trace from **repository** → **workflow** → **image** → **AKS workload**
- [ ] Vulnerability appears in **all relevant views** (repo, image, workload)
- [ ] Timeline shows the progression (commit → build → push → deploy)
- [ ] Security posture reflects the intentional vulnerability

---

## Vulnerability Details

### Test Vulnerability: ajv@6.12.2

| Package | Version | CVE | Type | Severity | CVSS |
|---------|---------|-----|------|----------|------|
| ajv | 6.12.2 | [CVE-2020-15366](https://nvd.nist.gov/vuln/detail/CVE-2020-15366) | Prototype Pollution | Medium/High | 5.6 |
| node | 16.x (EOL) | Multiple | Various | Various | N/A |

**About CVE-2020-15366:**
- **Vulnerability:** Prototype pollution via the `ajv.validate()` function
- **Impact:** An attacker can inject properties into `Object.prototype`, potentially leading to Denial of Service or other attacks
- **Remediation:** Upgrade to `ajv@6.12.3` or later
- **Why included:** This vulnerability is well-documented, has a clear CVE, and is easily detectable by security scanners — making it ideal for testing correlation flows

**Additional vulnerabilities:**
- Node.js 16.x is End-of-Life (EOL) and contains multiple vulnerabilities — this adds realism to the test scenario

**Note:** These vulnerabilities are **intentionally included** for testing purposes. Do not deploy this scenario to production environments.

---

## Cleanup

To delete all Azure resources created by this scenario:

```bash
# Make cleanup script executable
chmod +x infra/cleanup-azure.sh

# Run cleanup (deletes resource group and all resources)
./infra/cleanup-azure.sh
```

**What gets deleted:**
- Resource Group `c2cscenario-rg` and everything in it:
  - ACR (and all images)
  - AKS cluster
  - Managed Identity
  - Virtual network, disks, and other resources created by AKS

**Note:** This does **not** delete the GitHub connector. To remove the connector, go to Microsoft Defender for Cloud → Environment settings → GitHub → Remove connector.

---

## File Structure

```
code2cloud-scenarios/
├── README.md                                    # This file
├── .github/
│   └── workflows/
│       └── c2c-vuln-container-build.yml         # Build & deploy workflow
├── scenarios/
│   └── vulnerable-container/
│       ├── Dockerfile                           # Container image with ajv@6.12.2
│       ├── package.json                         # Node.js dependencies
│       ├── server.js                            # Simple Express server
│       └── k8s/
│           ├── namespace.yaml                   # Kubernetes namespace
│           └── deployment.yaml                  # Deployment + Service
└── infra/
    ├── deploy-azure.sh                          # Creates Azure resources
    └── cleanup-azure.sh                         # Deletes resource group
```

---

## Contributing / Extending

### Adding More Vulnerability Scenarios

To create additional test scenarios:

1. **Create a new scenario directory:**
   ```bash
   mkdir -p scenarios/new-scenario/k8s
   ```

2. **Define the vulnerability:**
   - Choose a package with a known CVE
   - Update `package.json` (or equivalent dependency file)
   - Document the CVE and expected behavior

3. **Create Dockerfile:**
   - Base image with the vulnerable dependency
   - Minimal application (just enough to run)

4. **Create K8s manifests:**
   - Deployment with labels indicating the scenario
   - Service (if needed)
   - Add annotations for traceability

5. **Create or update workflow:**
   - Build and push to ACR
   - Deploy to AKS
   - Tag with scenario name

6. **Document:**
   - Update README with scenario details
   - Add to verification checklist

### Suggested Additional Scenarios

- **Log4Shell (Log4j):** Java application with log4j 2.14.1
- **Spring4Shell:** Spring Framework 5.3.17
- **Python Dependency:** Flask with known vulnerability
- **Multi-stage build:** Testing image layer correlation
- **Helm chart:** Testing Helm-based deployments

---

## Troubleshooting

### Workflow fails with authentication error
- Verify GitHub secrets are set correctly
- Check that the Managed Identity federated credential matches the repository name
- Ensure the Azure subscription ID is correct

### Image push fails
- Verify the Managed Identity has `AcrPush` role on the ACR
- Check ACR firewall settings (ensure GitHub Actions IP ranges are allowed)

### AKS deployment fails
- Verify the Managed Identity has the correct AKS role
- Check if the namespace `c2c-scenarios` exists
- Ensure AKS cluster is running and healthy

### Vulnerability not detected
- Wait 15-30 minutes for Defender for Cloud to scan the image
- Verify the GitHub connector is active and syncing
- Check that the image digest in AKS matches the one in ACR

---

## License

MIT License - See LICENSE file for details.

**REMINDER:** This repository contains intentionally vulnerable code for testing purposes only. Use at your own risk.
