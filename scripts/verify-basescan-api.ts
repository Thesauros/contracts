import axios from 'axios';
import fs from 'fs';
import path from 'path';

const BASESCAN_API_KEY = 'XSYZVX9NTMI2I48VNS4965K3Y3X1HYXTSD';
const BASESCAN_API_URL = 'https://api.basescan.org/api';

interface ContractInfo {
  name: string;
  address: string;
  constructorArgs: any[];
  sourceCode: string;
  contractName: string;
  compilerVersion: string;
  optimizationUsed: string;
  runs: string;
  licenseType: string;
}

async function verifyContract(contract: ContractInfo) {
  console.log(`\n📋 Verifying ${contract.name} at ${contract.address}...`);
  
  try {
    // First, check if contract is already verified
    const checkResponse = await axios.get(`${BASESCAN_API_URL}`, {
      params: {
        module: 'contract',
        action: 'getabi',
        address: contract.address,
        apikey: BASESCAN_API_KEY
      }
    });

    if (checkResponse.data.status === '1') {
      console.log(`✅ ${contract.name} is already verified!`);
      return;
    }

    // Prepare verification data
    const verificationData = {
      module: 'contract',
      action: 'verifysourcecode',
      apikey: BASESCAN_API_KEY,
      contractaddress: contract.address,
      sourceCode: contract.sourceCode,
      codeformat: 'solidity-single-file',
      contractname: contract.contractName,
      compilerversion: contract.compilerVersion,
      optimizationUsed: contract.optimizationUsed,
      runs: contract.runs,
      licenseType: contract.licenseType,
      constructorArguements: contract.constructorArgs.length > 0 ? 
        ethers.utils.defaultAbiCoder.encode(
          contract.constructorArgs.map(() => 'address'),
          contract.constructorArgs
        ).slice(2) : ''
    };

    // Submit verification
    const verifyResponse = await axios.post(BASESCAN_API_URL, verificationData, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    if (verifyResponse.data.status === '1') {
      console.log(`✅ ${contract.name} verification submitted successfully!`);
      console.log(`   GUID: ${verifyResponse.data.result}`);
    } else {
      console.log(`❌ Failed to submit verification for ${contract.name}:`, verifyResponse.data.result);
    }

  } catch (error: any) {
    console.log(`❌ Error verifying ${contract.name}:`, error.message);
  }
}

async function main() {
  console.log('🔍 Starting contract verification via Basescan API...');
  
  // For now, let's just check if contracts are already verified
  const contracts = [
    { name: 'ProviderManager', address: '0xAeEcf7F780e88B155df330434Ef29b2B077024e0' },
    { name: 'AaveV3Provider', address: '0x78c11f63E6840820be18fDA461Ab16f23da5884f' },
    { name: 'CompoundV3Provider', address: '0x2Ed9B7fB6Bbe0920145B2a79c18C3f7cFCAE3C99' },
    { name: 'Timelock', address: '0xf061f5Da1B4de034d0Ebd05eA131975599B0221D' },
    { name: 'VaultManager', address: '0x6d7570E49d7bc011396ffc9E4Dc0F44777556566' }
  ];

  for (const contract of contracts) {
    try {
      console.log(`\n📋 Checking ${contract.name} at ${contract.address}...`);
      
      const response = await axios.get(`${BASESCAN_API_URL}`, {
        params: {
          module: 'contract',
          action: 'getabi',
          address: contract.address,
          apikey: BASESCAN_API_KEY
        }
      });

      if (response.data.status === '1') {
        console.log(`✅ ${contract.name} is already verified!`);
        console.log(`   View on Basescan: https://basescan.org/address/${contract.address}`);
      } else {
        console.log(`❌ ${contract.name} is not verified yet.`);
        console.log(`   View on Basescan: https://basescan.org/address/${contract.address}`);
      }
    } catch (error: any) {
      console.log(`❌ Error checking ${contract.name}:`, error.message);
    }
  }
  
  console.log('\n🎉 Verification check completed!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
