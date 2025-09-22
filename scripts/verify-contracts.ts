import { ethers } from 'hardhat';
import { deployments } from 'hardhat';

async function main() {
  console.log('🔍 Starting contract verification...');
  
  const contractAddresses = [
    {
      name: 'ProviderManager',
      address: '0xAeEcf7F780e88B155df330434Ef29b2B077024e0',
      args: []
    },
    {
      name: 'AaveV3Provider', 
      address: '0x78c11f63E6840820be18fDA461Ab16f23da5884f',
      args: ['0xAeEcf7F780e88B155df330434Ef29b2B077024e0'] // ProviderManager address
    },
    {
      name: 'CompoundV3Provider',
      address: '0x2Ed9B7fB6Bbe0920145B2a79c18C3f7cFCAE3C99', 
      args: ['0xAeEcf7F780e88B155df330434Ef29b2B077024e0'] // ProviderManager address
    },
    {
      name: 'Timelock',
      address: '0xf061f5Da1B4de034d0Ebd05eA131975599B0221D',
      args: ['0xafA9ed53c33bbD8DE300481ce150dB3D35738F9D', 1800] // admin, delay
    },
    {
      name: 'VaultManager',
      address: '0x6d7570E49d7bc011396ffc9E4Dc0F44777556566',
      args: ['0xf061f5Da1B4de034d0Ebd05eA131975599B0221D'] // Timelock address
    }
  ];

  for (const contract of contractAddresses) {
    try {
      console.log(`\n📋 Verifying ${contract.name} at ${contract.address}...`);
      
      await hre.run('verify:verify', {
        address: contract.address,
        constructorArguments: contract.args,
        network: 'base'
      });
      
      console.log(`✅ ${contract.name} verified successfully!`);
    } catch (error: any) {
      if (error.message.includes('Already Verified')) {
        console.log(`✅ ${contract.name} already verified!`);
      } else {
        console.log(`❌ Failed to verify ${contract.name}:`, error.message);
      }
    }
  }
  
  console.log('\n🎉 Verification process completed!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
