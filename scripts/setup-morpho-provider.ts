import { ethers } from "hardhat";
import { ProviderManager } from "../typechain-types";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Setting up MorphoProvider with account:", deployer.address);

    // Get the ProviderManager contract
    const providerManagerAddress = process.env.PROVIDER_MANAGER_ADDRESS;
    if (!providerManagerAddress) {
        throw new Error("PROVIDER_MANAGER_ADDRESS environment variable is required");
    }

    const providerManager = await ethers.getContractAt("ProviderManager", providerManagerAddress) as ProviderManager;

    // MorphoProvider configuration
    const morphoProviderAddress = process.env.MORPHO_PROVIDER_ADDRESS;
    if (!morphoProviderAddress) {
        throw new Error("MORPHO_PROVIDER_ADDRESS environment variable is required");
    }

    const morphoProtocolAddress = process.env.MORPHO_PROTOCOL_ADDRESS;
    if (!morphoProtocolAddress) {
        throw new Error("MORPHO_PROTOCOL_ADDRESS environment variable is required");
    }

    // Assets to configure (example: USDC, WETH, etc.)
    const assets = [
        process.env.USDC_ADDRESS,
        process.env.WETH_ADDRESS,
        process.env.USDT_ADDRESS,
        process.env.DAI_ADDRESS
    ].filter(Boolean);

    console.log("Configuring MorphoProvider for assets:", assets);

    // Set yield tokens (Morpho protocol address for each asset)
    for (const asset of assets) {
        if (asset) {
            console.log(`Setting yield token for asset ${asset} to Morpho protocol ${morphoProtocolAddress}`);
            await providerManager.setYieldToken(
                "Morpho_Provider",
                asset,
                morphoProtocolAddress
            );
        }
    }

    // Set markets (for now, we'll use the same address for all markets)
    for (const asset of assets) {
        if (asset) {
            console.log(`Setting market for asset ${asset} to Morpho protocol ${morphoProtocolAddress}`);
            await providerManager.setMarket(
                "Morpho_Provider",
                asset,
                ethers.ZeroAddress, // No second asset for Morpho
                morphoProtocolAddress
            );
        }
    }

    console.log("MorphoProvider setup completed successfully!");
    console.log("Provider identifier: Morpho_Provider");
    console.log("Morpho protocol address:", morphoProtocolAddress);
    console.log("Configured assets:", assets);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
