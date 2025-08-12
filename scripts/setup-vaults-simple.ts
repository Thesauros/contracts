import { ethers } from 'hardhat';
import { tokenAddresses } from '../utils/constants';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Setup Vaults with account:', deployer.address);

  // USDC Vault address (from previous deployment)
  const usdcVaultAddress = '0xdf5AFad7f88888bEE944d14982c2d9eBA65653e6';
  const usdtVaultAddress = '0xe1D34AB80090da3498Fc5D0696a2Cf82971E5eC6';

  // Get token contracts
  const usdcToken = await ethers.getContractAt('IERC20', tokenAddresses.USDC);
  const usdtToken = await ethers.getContractAt('IERC20', tokenAddresses.USDT);

  // Check balances
  const usdcBalance = await usdcToken.balanceOf(deployer.address);
  const usdtBalance = await usdtToken.balanceOf(deployer.address);

  console.log(`USDC Balance: ${ethers.formatUnits(usdcBalance, 6)} USDC`);
  console.log(`USDT Balance: ${ethers.formatUnits(usdtBalance, 6)} USDT`);

  // Setup USDC Vault
  if (usdcBalance > 0) {
    console.log('\nSetting up USDC Vault...');
    const usdcVault = await ethers.getContractAt('Rebalancer', usdcVaultAddress);
    
    try {
      const isSetup = await usdcVault.setupCompleted();
      if (!isSetup) {
        const setupAmount = ethers.parseUnits('1', 6); // 1 USDC
        if (usdcBalance >= setupAmount) {
          console.log(`Approving ${ethers.formatUnits(setupAmount, 6)} USDC...`);
          const approveTx = await usdcToken.approve(usdcVaultAddress, setupAmount);
          await approveTx.wait();
          
          console.log('Setting up vault...');
          const setupTx = await usdcVault.setupVault(setupAmount);
          await setupTx.wait();
          
          console.log(`✅ USDC Vault setup completed with ${ethers.formatUnits(setupAmount, 6)} USDC`);
        } else {
          console.log('❌ Insufficient USDC balance for setup');
        }
      } else {
        console.log('✅ USDC Vault already setup');
      }
    } catch (error) {
      console.log('❌ Error setting up USDC Vault:', error);
    }
  }

  // Setup USDT Vault
  if (usdtBalance > 0) {
    console.log('\nSetting up USDT Vault...');
    const usdtVault = await ethers.getContractAt('Rebalancer', usdtVaultAddress);
    
    try {
      const isSetup = await usdtVault.setupCompleted();
      if (!isSetup) {
        const setupAmount = ethers.parseUnits('1', 6); // 1 USDT
        if (usdtBalance >= setupAmount) {
          console.log(`Approving ${ethers.formatUnits(setupAmount, 6)} USDT...`);
          const approveTx = await usdtToken.approve(usdtVaultAddress, setupAmount);
          await approveTx.wait();
          
          console.log('Setting up vault...');
          const setupTx = await usdtVault.setupVault(setupAmount);
          await setupTx.wait();
          
          console.log(`✅ USDT Vault setup completed with ${ethers.formatUnits(setupAmount, 6)} USDT`);
        } else {
          console.log('❌ Insufficient USDT balance for setup');
        }
      } else {
        console.log('✅ USDT Vault already setup');
      }
    } catch (error) {
      console.log('❌ Error setting up USDT Vault:', error);
    }
  }

  console.log('\nSetup completed!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
