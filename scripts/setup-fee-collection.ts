import { ethers } from "hardhat";
import { FeeCollector } from "../typechain-types";
import { Rebalancer } from "../typechain-types";

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Setting up fee collection with account:", deployer.address);

  // Get contract addresses from environment or use defaults
  const feeCollectorAddress = process.env.FEE_COLLECTOR_ADDRESS;
  const vaultAddress = process.env.VAULT_ADDRESS;
  const collectionInterval = process.env.COLLECTION_INTERVAL || "604800"; // 7 days in seconds

  if (!feeCollectorAddress) {
    throw new Error("FEE_COLLECTOR_ADDRESS environment variable is required");
  }

  if (!vaultAddress) {
    throw new Error("VAULT_ADDRESS environment variable is required");
  }

  console.log("FeeCollector address:", feeCollectorAddress);
  console.log("Vault address:", vaultAddress);
  console.log("Collection interval:", collectionInterval, "seconds");

  // Connect to contracts
  const feeCollector = await ethers.getContractAt("FeeCollector", feeCollectorAddress);
  const vault = await ethers.getContractAt("Rebalancer", vaultAddress);

  // Check if vault is already registered
  const vaultInfo = await feeCollector.getVaultInfo(vaultAddress);
  
  if (vaultInfo.isRegistered) {
    console.log("Vault is already registered for fee collection");
    console.log("Current interval:", vaultInfo.collectionInterval.toString());
    console.log("Last collection:", new Date(Number(vaultInfo.lastCollectionTime) * 1000).toISOString());
    console.log("Total fees collected:", ethers.utils.formatEther(vaultInfo.totalFeesCollected));
    
    // Ask if user wants to update interval
    const newInterval = process.env.UPDATE_INTERVAL;
    if (newInterval) {
      console.log("Updating collection interval to:", newInterval, "seconds");
      const tx = await feeCollector.updateCollectionInterval(vaultAddress, newInterval);
      await tx.wait();
      console.log("Collection interval updated successfully");
    }
  } else {
    console.log("Registering vault for fee collection...");
    const tx = await feeCollector.registerVault(vaultAddress, collectionInterval);
    await tx.wait();
    console.log("Vault registered successfully");
  }

  // Check vault readiness
  const isReady = await feeCollector.isVaultReadyForCollection(vaultAddress);
  const timeUntilNext = await feeCollector.getTimeUntilNextCollection(vaultAddress);
  
  console.log("Vault ready for collection:", isReady);
  if (!isReady) {
    console.log("Time until next collection:", timeUntilNext.toString(), "seconds");
    console.log("Next collection in:", Math.floor(Number(timeUntilNext) / 3600), "hours");
  }

  // Get vault asset balance (potential fees)
  const assetAddress = await vault.asset();
  const assetContract = await ethers.getContractAt("IERC20", assetAddress);
  const vaultBalance = await assetContract.balanceOf(vaultAddress);
  
  console.log("Vault asset balance:", ethers.utils.formatEther(vaultBalance));
  console.log("Asset address:", assetAddress);

  // If vault is ready and has balance, collect fees
  if (isReady && vaultBalance.gt(0)) {
    console.log("Collecting fees...");
    const collectTx = await feeCollector.collectFees(vaultAddress);
    await collectTx.wait();
    console.log("Fees collected successfully");
  }

  // Display final status
  console.log("\n=== Fee Collection Setup Complete ===");
  console.log("Vault:", vaultAddress);
  console.log("FeeCollector:", feeCollectorAddress);
  console.log("Collection interval:", collectionInterval, "seconds");
  console.log("Asset:", assetAddress);
  console.log("Ready for collection:", await feeCollector.isVaultReadyForCollection(vaultAddress));
}

// Helper function to collect fees from all registered vaults
async function collectAllFees() {
  const [deployer] = await ethers.getSigners();
  const feeCollectorAddress = process.env.FEE_COLLECTOR_ADDRESS;
  
  if (!feeCollectorAddress) {
    throw new Error("FEE_COLLECTOR_ADDRESS environment variable is required");
  }

  const feeCollector = await ethers.getContractAt("FeeCollector", feeCollectorAddress);
  
  console.log("Collecting fees from all registered vaults...");
  const tx = await feeCollector.collectAllFees();
  await tx.wait();
  console.log("All fees collected successfully");
}

// Helper function to check status of all vaults
async function checkAllVaults() {
  const [deployer] = await ethers.getSigners();
  const feeCollectorAddress = process.env.FEE_COLLECTOR_ADDRESS;
  
  if (!feeCollectorAddress) {
    throw new Error("FEE_COLLECTOR_ADDRESS environment variable is required");
  }

  const feeCollector = await ethers.getContractAt("FeeCollector", feeCollectorAddress);
  
  const vaultCount = await feeCollector.getRegisteredVaultsCount();
  console.log("Total registered vaults:", vaultCount.toString());
  
  const vaults = await feeCollector.getRegisteredVaults();
  
  for (let i = 0; i < vaults.length; i++) {
    const vaultAddress = vaults[i];
    const vaultInfo = await feeCollector.getVaultInfo(vaultAddress);
    const isReady = await feeCollector.isVaultReadyForCollection(vaultAddress);
    const timeUntilNext = await feeCollector.getTimeUntilNextCollection(vaultAddress);
    
    console.log(`\nVault ${i + 1}: ${vaultAddress}`);
    console.log("  Interval:", vaultInfo.collectionInterval.toString(), "seconds");
    console.log("  Last collection:", new Date(Number(vaultInfo.lastCollectionTime) * 1000).toISOString());
    console.log("  Total fees collected:", ethers.utils.formatEther(vaultInfo.totalFeesCollected));
    console.log("  Ready for collection:", isReady);
    if (!isReady) {
      console.log("  Time until next:", timeUntilNext.toString(), "seconds");
    }
  }
}

// Main execution
if (require.main === module) {
  const command = process.argv[2];
  
  if (command === "collect-all") {
    collectAllFees()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error(error);
        process.exit(1);
      });
  } else if (command === "check-all") {
    checkAllVaults()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error(error);
        process.exit(1);
      });
  } else {
    main()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error(error);
        process.exit(1);
      });
  }
}

export { main, collectAllFees, checkAllVaults };

