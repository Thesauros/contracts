import { ethers } from "hardhat";
import { FeeCollector } from "../typechain-types";

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying FeeCollector with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Get treasury address from environment or use deployer as default
  const treasuryAddress = process.env.TREASURY_ADDRESS || deployer.address;
  
  console.log("Treasury address:", treasuryAddress);

  // Deploy FeeCollector
  const FeeCollectorFactory = await ethers.getContractFactory("FeeCollector");
  const feeCollector = await FeeCollectorFactory.deploy(treasuryAddress);
  
  await feeCollector.deployed();
  
  console.log("FeeCollector deployed to:", feeCollector.address);
  
  // Grant admin role to deployer
  const ADMIN_ROLE = await feeCollector.ADMIN_ROLE();
  await feeCollector.grantRole(ADMIN_ROLE, deployer.address);
  console.log("Admin role granted to:", deployer.address);
  
  // Save deployment info
  const deploymentInfo = {
    network: await deployer.provider.getNetwork(),
    contract: "FeeCollector",
    address: feeCollector.address,
    treasury: treasuryAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    blockNumber: await deployer.provider.getBlockNumber()
  };
  
  console.log("Deployment info:", JSON.stringify(deploymentInfo, null, 2));
  
  // Verify contract if on mainnet/testnet
  if (process.env.VERIFY_CONTRACT === "true") {
    console.log("Waiting for block confirmations...");
    await feeCollector.deployTransaction.wait(6);
    
    try {
      await hre.run("verify:verify", {
        address: feeCollector.address,
        constructorArguments: [treasuryAddress],
      });
      console.log("Contract verified successfully");
    } catch (error) {
      console.log("Verification failed:", error);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

