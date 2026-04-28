#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# C2C Test Scenario - Azure Infrastructure Cleanup
# ============================================================================
# This script DELETES all Azure resources created for code2cloud-scenarios.
# This is a DESTRUCTIVE operation that removes:
# - Resource Group (which cascades to all contained resources)
# - AKS cluster
# - ACR
# - Managed Identity
# - All role assignments
# - All federated credentials
#
# Use with caution! This is meant for test environment cleanup.
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration
# ============================================================================

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-2484489b-da82-4300-9f01-406602c2efbc}"
PREFIX="${RESOURCE_PREFIX:-c2cscenario}"
RESOURCE_GROUP="${PREFIX}-rg"

echo -e "${RED}============================================================================${NC}"
echo -e "${RED}C2C Test Scenario - Azure Infrastructure Cleanup${NC}"
echo -e "${RED}============================================================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will DELETE all resources in:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Subscription:   $SUBSCRIPTION_ID"
echo ""
echo -e "${RED}This includes:${NC}"
echo "  - AKS Cluster (c2cscenario-aks)"
echo "  - Azure Container Registry (c2cscenarioacr)"
echo "  - Managed Identity (c2cscenario-github-identity)"
echo "  - All role assignments"
echo "  - All federated credentials"
echo "  - All other resources in the resource group"
echo ""

# Check prerequisites
if ! command -v az &> /dev/null; then
    echo -e "${RED}ERROR: Azure CLI (az) is not installed!${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}ERROR: Not logged into Azure CLI!${NC}"
    echo "Run: az login"
    exit 1
fi

# Set subscription
echo -e "${YELLOW}Setting Azure subscription...${NC}"
az account set --subscription "$SUBSCRIPTION_ID"
echo -e "${GREEN}✓ Subscription set${NC}"
echo ""

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${YELLOW}Resource group '$RESOURCE_GROUP' does not exist. Nothing to clean up.${NC}"
    exit 0
fi

# List resources that will be deleted
echo -e "${YELLOW}Resources in '$RESOURCE_GROUP':${NC}"
az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Type:type}" -o table
echo ""

# Final confirmation
echo -e "${RED}============================================================================${NC}"
echo -e "${RED}THIS ACTION CANNOT BE UNDONE!${NC}"
echo -e "${RED}============================================================================${NC}"
echo ""
read -p "$(echo -e ${RED}Type 'DELETE' to confirm deletion: ${NC})" CONFIRM

if [[ "$CONFIRM" != "DELETE" ]]; then
    echo -e "${YELLOW}Cleanup cancelled. No resources were deleted.${NC}"
    exit 0
fi
echo ""

# ============================================================================
# Delete Resource Group
# ============================================================================

echo -e "${YELLOW}Deleting resource group '$RESOURCE_GROUP'...${NC}"
echo -e "${YELLOW}This will take several minutes. Deletion is running in the background.${NC}"

az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait

echo ""
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}CLEANUP INITIATED${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo ""
echo -e "${GREEN}Resource group deletion has been started in the background.${NC}"
echo ""
echo -e "${BLUE}What was deleted:${NC}"
echo "  ✓ Resource Group: $RESOURCE_GROUP"
echo "  ✓ AKS Cluster: c2cscenario-aks"
echo "  ✓ Azure Container Registry: c2cscenarioacr"
echo "  ✓ Managed Identity: c2cscenario-github-identity"
echo "  ✓ All role assignments"
echo "  ✓ All federated credentials"
echo ""
echo -e "${YELLOW}Monitor deletion progress:${NC}"
echo "  az group show --name $RESOURCE_GROUP"
echo ""
echo -e "${YELLOW}The resource group will be fully deleted in 5-10 minutes.${NC}"
echo -e "${YELLOW}You will receive an error when the group no longer exists (this is expected).${NC}"
echo ""
echo -e "${BLUE}Don't forget to:${NC}"
echo "  - Remove GitHub Actions secrets (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID)"
echo "  - Remove any kubectl contexts: kubectl config delete-context c2cscenario-aks"
echo ""
echo -e "${GREEN}Cleanup script completed successfully!${NC}"
