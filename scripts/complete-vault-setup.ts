import { ethers } from 'hardhat';
import { deployments } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Completing Vault Setup');
  console.log('=====================');
  console.log(`Deployer: ${deployer.address}`);

  // Get deployed contracts
  const rebalancerDeployment = await deployments.get('Rebalancer');
  const vaultManagerDeployment = await deployments.get('VaultManager');
  
  const rebalancer = await ethers.getContractAt('Rebalancer', rebalancerDeployment.address);
  const vaultManager = vaultManagerDeployment.address;
  
  const OPERATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes('OPERATOR_ROLE'));
  
  // Check if setup is completed
  const isSetup = await rebalancer.setupCompleted();
  console.log(`\nRebalancer at: ${rebalancerDeployment.address}`);
  console.log(`Setup completed: ${isSetup}`);
  
  // Setup vault if not done
  if (!isSetup) {
    console.log('\nSetting up vault...');
    const usdcAddress = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';
    const usdcToken = await ethers.getContractAt('IERC20', usdcAddress);
    const setupAmount = ethers.parseUnits('1', 6); // 1 USDC
    
    const balance = await usdcToken.balanceOf(deployer.address);
    console.log(`USDC Balance: ${ethers.formatUnits(balance, 6)} USDC`);
    
    if (balance >= setupAmount) {
      const approveTx = await usdcToken.approve(rebalancerDeployment.address, setupAmount);
      await approveTx.wait();
      console.log('✅ Approved USDC');
      
      const setupTx = await rebalancer.setupVault(setupAmount);
      await setupTx.wait();
      console.log(`✅ Setup vault completed with ${ethers.formatUnits(setupAmount, 6)} USDC`);
    } else {
      console.log(`❌ Insufficient USDC balance. Need: ${ethers.formatUnits(setupAmount, 6)}, Have: ${ethers.formatUnits(balance, 6)}`);
      return;
    }
  } else {
    console.log('✅ Vault already setup');
  }
  
  // Grant OPERATOR_ROLE to VaultManager
  console.log(`\nGranting OPERATOR_ROLE to VaultManager...`);
  const hasRole = await rebalancer.hasRole(OPERATOR_ROLE, vaultManager);
  if (!hasRole) {
    const grantTx = await rebalancer.grantRole(OPERATOR_ROLE, vaultManager);
    await grantTx.wait();
    console.log(`✅ Granted OPERATOR_ROLE to VaultManager (${vaultManager})`);
  } else {
    console.log(`✅ VaultManager already has OPERATOR_ROLE`);
  }
  
  console.log('\n✅ Setup completed!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

