#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# C2C Test Scenario - Azure Infrastructure Deployment
# ============================================================================
# This script creates ALL Azure resources needed for the code2cloud-scenarios
# test environment. These are ISOLATED TEST RESOURCES separate from production.
#
# Purpose: Deploy infrastructure for testing C2C mapping scenarios
# - ACR for container images
# - AKS cluster for Kubernetes workloads
# - Managed Identity with GitHub OIDC for passwordless authentication
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Step 1: Variables & Prerequisites
# ============================================================================

# Core Configuration (can be overridden via environment variables)
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2484489b-da82-4300-9f01-406602c2efbc}"
TENANT_DOMAIN="${AZURE_TENANT_DOMAIN:-7d45cbc7657f85d6a9.onmicrosoft.com}"
LOCATION="${AZURE_LOCATION:-eastus}"
PREFIX="${RESOURCE_PREFIX:-c2cscenario}"

# Resource Names
RESOURCE_GROUP="${PREFIX}-rg"
ACR_NAME="${PREFIX}acr"
AKS_NAME="${PREFIX}-aks"
IDENTITY_NAME="${PREFIX}-github-identity"
NAMESPACE="c2c-scenarios"

# AKS Configuration
NODE_COUNT="${AKS_NODE_COUNT:-1}"
NODE_SIZE="${AKS_NODE_SIZE:-Standard_B2s}"

# GitHub Configuration
GITHUB_REPO="${GITHUB_REPO:-thechmodmaster/code2cloud-scenarios}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}C2C Test Scenario - Azure Infrastructure Deployment${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Subscription ID:  $SUBSCRIPTION_ID"
echo "  Location:         $LOCATION"
echo "  Resource Group:   $RESOURCE_GROUP"
echo "  ACR Name:         $ACR_NAME"
echo "  AKS Name:         $AKS_NAME"
echo "  Identity Name:    $IDENTITY_NAME"
echo "  GitHub Repo:      $GITHUB_REPO"
echo "  GitHub Branch:    $GITHUB_BRANCH"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}ERROR: Azure CLI (az) is not installed!${NC}"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed!${NC}"
    echo "Install from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check Azure CLI login
if ! az account show &> /dev/null; then
    echo -e "${RED}ERROR: Not logged into Azure CLI!${NC}"
    echo "Run: az login"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Confirmation prompt
read -p "$(echo -e ${YELLOW}Continue with deployment? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi
echo ""

# Set subscription
echo -e "${YELLOW}Setting Azure subscription...${NC}"
az account set --subscription "$SUBSCRIPTION_ID"
echo -e "${GREEN}✓ Subscription set${NC}"
echo ""

# ============================================================================
# Step 2: Resource Group
# ============================================================================

echo -e "${YELLOW}Creating resource group...${NC}"
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${BLUE}Resource group '$RESOURCE_GROUP' already exists, skipping creation${NC}"
else
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "purpose=c2c-testing" "environment=test" \
        --output none
    echo -e "${GREEN}✓ Resource group created: $RESOURCE_GROUP${NC}"
fi
echo ""

# ============================================================================
# Step 3: Azure Container Registry (ACR)
# ============================================================================

echo -e "${YELLOW}Creating Azure Container Registry...${NC}"
if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${BLUE}ACR '$ACR_NAME' already exists, skipping creation${NC}"
else
    az acr create \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --sku Basic \
        --location "$LOCATION" \
        --admin-enabled false \
        --output none
    echo -e "${GREEN}✓ ACR created: $ACR_NAME${NC}"
fi

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)
echo -e "${GREEN}✓ ACR Login Server: $ACR_LOGIN_SERVER${NC}"
echo ""

# ============================================================================
# Step 4: AKS Cluster
# ============================================================================

echo -e "${YELLOW}Creating AKS cluster (this may take 5-10 minutes)...${NC}"
if az aks show --name "$AKS_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${BLUE}AKS cluster '$AKS_NAME' already exists, skipping creation${NC}"
else
    az aks create \
        --name "$AKS_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --node-count "$NODE_COUNT" \
        --node-vm-size "$NODE_SIZE" \
        --enable-managed-identity \
        --attach-acr "$ACR_NAME" \
        --generate-ssh-keys \
        --network-plugin azure \
        --network-policy azure \
        --tags "purpose=c2c-testing" "environment=test" \
        --output none
    echo -e "${GREEN}✓ AKS cluster created: $AKS_NAME${NC}"
fi

# Get AKS credentials
echo -e "${YELLOW}Getting AKS credentials...${NC}"
az aks get-credentials \
    --name "$AKS_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --overwrite-existing \
    --output none
echo -e "${GREEN}✓ AKS credentials configured${NC}"

# Verify kubectl access
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ kubectl can access the cluster${NC}"
else
    echo -e "${RED}WARNING: kubectl cannot access the cluster${NC}"
fi
echo ""

# ============================================================================
# Step 5: User-Assigned Managed Identity for GitHub OIDC
# ============================================================================

echo -e "${YELLOW}Creating Managed Identity for GitHub Actions OIDC...${NC}"
if az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${BLUE}Identity '$IDENTITY_NAME' already exists, retrieving details${NC}"
else
    az identity create \
        --name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "purpose=github-oidc" "repository=$GITHUB_REPO" \
        --output none
    echo -e "${GREEN}✓ Managed Identity created: $IDENTITY_NAME${NC}"
    
    # Wait for identity propagation
    echo -e "${YELLOW}Waiting 30 seconds for identity propagation...${NC}"
    sleep 30
fi

# Get identity details
IDENTITY_PRINCIPAL_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)
IDENTITY_CLIENT_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)

echo -e "${GREEN}✓ Identity Principal ID: $IDENTITY_PRINCIPAL_ID${NC}"
echo -e "${GREEN}✓ Identity Client ID: $IDENTITY_CLIENT_ID${NC}"
echo ""

# ============================================================================
# Step 6: Federated Credential for GitHub Actions OIDC
# ============================================================================

echo -e "${YELLOW}Creating federated credentials for GitHub Actions OIDC...${NC}"

# Federated credential for main branch (push and workflow_dispatch)
FEDCRED_NAME="github-oidc-main"
if az identity federated-credential show \
    --name "$FEDCRED_NAME" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${BLUE}Federated credential '$FEDCRED_NAME' already exists, skipping${NC}"
else
    az identity federated-credential create \
        --name "$FEDCRED_NAME" \
        --identity-name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "repo:$GITHUB_REPO:ref:refs/heads/$GITHUB_BRANCH" \
        --audiences "api://AzureADTokenExchange" \
        --output none
    echo -e "${GREEN}✓ Federated credential created for main branch: $FEDCRED_NAME${NC}"
fi

# Additional federated credential for pull requests (optional but useful for testing)
FEDCRED_PR_NAME="github-oidc-pr"
if az identity federated-credential show \
    --name "$FEDCRED_PR_NAME" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${BLUE}Federated credential '$FEDCRED_PR_NAME' already exists, skipping${NC}"
else
    az identity federated-credential create \
        --name "$FEDCRED_PR_NAME" \
        --identity-name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "repo:$GITHUB_REPO:pull_request" \
        --audiences "api://AzureADTokenExchange" \
        --output none
    echo -e "${GREEN}✓ Federated credential created for pull requests: $FEDCRED_PR_NAME${NC}"
fi
echo ""

# ============================================================================
# Step 7: Role Assignments
# ============================================================================

echo -e "${YELLOW}Assigning roles to managed identity...${NC}"

# Get ACR resource ID
ACR_ID=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)

# Get AKS resource ID
AKS_ID=$(az aks show --name "$AKS_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)

# Role 1: AcrPush on ACR (allows pushing container images)
echo -e "${YELLOW}  Assigning AcrPush role on ACR...${NC}"
if az role assignment list \
    --assignee "$IDENTITY_PRINCIPAL_ID" \
    --scope "$ACR_ID" \
    --role "AcrPush" \
    --query "[].roleDefinitionName" -o tsv | grep -q "AcrPush"; then
    echo -e "${BLUE}  AcrPush role already assigned, skipping${NC}"
else
    az role assignment create \
        --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
        --assignee-principal-type ServicePrincipal \
        --role "AcrPush" \
        --scope "$ACR_ID" \
        --output none
    echo -e "${GREEN}  ✓ AcrPush role assigned${NC}"
fi

# Role 2: Azure Kubernetes Service Cluster User Role (allows getting cluster credentials)
echo -e "${YELLOW}  Assigning AKS Cluster User role...${NC}"
if az role assignment list \
    --assignee "$IDENTITY_PRINCIPAL_ID" \
    --scope "$AKS_ID" \
    --role "Azure Kubernetes Service Cluster User Role" \
    --query "[].roleDefinitionName" -o tsv | grep -q "Azure Kubernetes Service Cluster User Role"; then
    echo -e "${BLUE}  AKS Cluster User role already assigned, skipping${NC}"
else
    az role assignment create \
        --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
        --assignee-principal-type ServicePrincipal \
        --role "Azure Kubernetes Service Cluster User Role" \
        --scope "$AKS_ID" \
        --output none
    echo -e "${GREEN}  ✓ AKS Cluster User role assigned${NC}"
fi

# Role 3: Azure Kubernetes Service RBAC Writer (allows kubectl apply/create/delete)
echo -e "${YELLOW}  Assigning AKS RBAC Writer role...${NC}"
if az role assignment list \
    --assignee "$IDENTITY_PRINCIPAL_ID" \
    --scope "$AKS_ID" \
    --role "Azure Kubernetes Service RBAC Writer" \
    --query "[].roleDefinitionName" -o tsv | grep -q "Azure Kubernetes Service RBAC Writer"; then
    echo -e "${BLUE}  AKS RBAC Writer role already assigned, skipping${NC}"
else
    az role assignment create \
        --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
        --assignee-principal-type ServicePrincipal \
        --role "Azure Kubernetes Service RBAC Writer" \
        --scope "$AKS_ID" \
        --output none
    echo -e "${GREEN}  ✓ AKS RBAC Writer role assigned${NC}"
fi

echo -e "${GREEN}✓ All role assignments completed${NC}"
echo ""

# ============================================================================
# Step 8: Create Kubernetes Namespace
# ============================================================================

echo -e "${YELLOW}Creating Kubernetes namespace...${NC}"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${BLUE}Namespace '$NAMESPACE' already exists, skipping${NC}"
else
    kubectl create namespace "$NAMESPACE"
    echo -e "${GREEN}✓ Namespace created: $NAMESPACE${NC}"
fi
echo ""

# ============================================================================
# Step 9: Output Summary
# ============================================================================

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo ""
echo -e "${BLUE}Azure Resources Created:${NC}"
echo "  Resource Group:       $RESOURCE_GROUP"
echo "  ACR Login Server:     $ACR_LOGIN_SERVER"
echo "  AKS Cluster:          $AKS_NAME"
echo "  Kubernetes Namespace: $NAMESPACE"
echo "  Managed Identity:     $IDENTITY_NAME"
echo ""
echo -e "${BLUE}Identity Details:${NC}"
echo "  Principal ID:         $IDENTITY_PRINCIPAL_ID"
echo "  Client ID:            $IDENTITY_CLIENT_ID"
echo ""
echo -e "${BLUE}Azure Account Details:${NC}"
echo "  Tenant ID:            $TENANT_ID"
echo "  Subscription ID:      $SUBSCRIPTION_ID"
echo ""
echo -e "${YELLOW}============================================================================${NC}"
echo -e "${YELLOW}GITHUB ACTIONS CONFIGURATION${NC}"
echo -e "${YELLOW}============================================================================${NC}"
echo ""
echo -e "${YELLOW}Add these secrets to your GitHub repository:${NC}"
echo -e "${YELLOW}(Settings → Secrets and variables → Actions → New repository secret)${NC}"
echo ""
echo -e "${GREEN}Repository Secrets:${NC}"
echo "  AZURE_CLIENT_ID       = $IDENTITY_CLIENT_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo ""
echo -e "${GREEN}Repository Variables (optional):${NC}"
echo "  ACR_NAME              = $ACR_NAME"
echo "  ACR_LOGIN_SERVER      = $ACR_LOGIN_SERVER"
echo "  AKS_CLUSTER_NAME      = $AKS_NAME"
echo "  AKS_RESOURCE_GROUP    = $RESOURCE_GROUP"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Add the above secrets to GitHub: https://github.com/$GITHUB_REPO/settings/secrets/actions"
echo "  2. Push your workflow to the $GITHUB_BRANCH branch"
echo "  3. Run the GitHub Actions workflow"
echo ""
echo -e "${GREEN}Deployment script completed successfully!${NC}"
