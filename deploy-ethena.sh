#!/bin/bash

# Ethena Provider Deployment Script for Foundry
# This script deploys Ethena mock contracts and providers to Arbitrum

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ARBITRUM_RPC=${ARBITRUM_RPC:-"https://arb1.arbitrum.io/rpc"}

echo -e "${BLUE}🚀 Ethena Provider Deployment Script${NC}"
echo "=================================="

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ Error: PRIVATE_KEY environment variable is not set${NC}"
    echo "Please set your private key: export PRIVATE_KEY=your_private_key"
    exit 1
fi

# Check if we're on Arbitrum network
echo -e "${YELLOW}📡 Using RPC: $ARBITRUM_RPC${NC}"

echo -e "\n${BLUE}Step 1: Deploying Mock Contracts${NC}"
echo "=================================="

# Deploy mock contracts
forge script script/DeployEthenaMocks.s.sol --rpc-url $ARBITRUM_RPC --broadcast --verify

# Extract addresses from the output (this is a simplified approach)
echo -e "\n${YELLOW}⚠️  Please note the deployed addresses from the output above${NC}"
echo -e "${YELLOW}You'll need to set these environment variables for the next steps:${NC}"
echo "export MOCK_USDE=<MockUSDe_address>"
echo "export MOCK_ETHENA_STAKING=<MockEthenaStaking_address>"

# Ask user if they want to continue
echo -e "\n${BLUE}Step 2: Deploy EthenaProvider Contracts${NC}"
echo "=================================="
echo -e "${YELLOW}Do you want to continue with EthenaProvider deployment? (y/n)${NC}"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    if [ -z "$MOCK_USDE" ] || [ -z "$MOCK_ETHENA_STAKING" ]; then
        echo -e "${RED}❌ Error: Mock contract addresses not set!${NC}"
        echo "Please set MOCK_USDE and MOCK_ETHENA_STAKING environment variables"
        echo "Example:"
        echo "export MOCK_USDE=0x..."
        echo "export MOCK_ETHENA_STAKING=0x..."
        exit 1
    fi
    
    MOCK_USDE=$MOCK_USDE MOCK_ETHENA_STAKING=$MOCK_ETHENA_STAKING \
    forge script script/DeployEthenaProvider.s.sol --rpc-url $ARBITRUM_RPC --broadcast --verify
    
    echo -e "\n${YELLOW}⚠️  Please note the EthenaProvider addresses from the output above${NC}"
    echo -e "${YELLOW}You'll need to set these environment variables for the next steps:${NC}"
    echo "export ETHENA_PROVIDER_USDT=<EthenaProvider_USDT_address>"
    echo "export ETHENA_PROVIDER_USDC=<EthenaProvider_USDC_address>"
    
    # Ask user if they want to setup with vaults
    echo -e "\n${BLUE}Step 3: Setup with Existing Vaults${NC}"
    echo "=================================="
    echo -e "${YELLOW}Do you want to setup EthenaProvider with existing vaults? (y/n)${NC}"
    read -r response2
    
    if [[ "$response2" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        if [ -z "$ETHENA_PROVIDER_USDT" ] || [ -z "$ETHENA_PROVIDER_USDC" ]; then
            echo -e "${RED}❌ Error: EthenaProvider addresses not set!${NC}"
            echo "Please set ETHENA_PROVIDER_USDT and ETHENA_PROVIDER_USDC environment variables"
            exit 1
        fi
        
        ETHENA_PROVIDER_USDT=$ETHENA_PROVIDER_USDT ETHENA_PROVIDER_USDC=$ETHENA_PROVIDER_USDC \
        forge script script/SetupEthenaProvider.s.sol --rpc-url $ARBITRUM_RPC --broadcast
        
        echo -e "\n${GREEN}✅ Ethena Provider deployment and setup completed successfully!${NC}"
    else
        echo -e "${YELLOW}⏭️  Skipping vault setup${NC}"
    fi
else
    echo -e "${YELLOW}⏭️  Skipping EthenaProvider deployment${NC}"
fi

echo -e "\n${GREEN}🎉 Deployment process completed!${NC}"
echo -e "${BLUE}Summary:${NC}"
echo "- Mock contracts deployed"
echo "- EthenaProvider contracts deployed (if selected)"
echo "- Connected to existing vaults (if selected)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the integration"
echo "2. Monitor vault performance"
echo "3. Update when real Ethena contracts are deployed on Arbitrum"
