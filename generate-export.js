const fs = require('fs');
const path = require('path');

// make export directory
const exportDir = './export';
if (!fs.existsSync(exportDir)) {
    fs.mkdirSync(exportDir, { recursive: true });
}

// copy Rebalancer.json
const rebalancerSource = './deployments/arbitrumOne/Rebalancer.json';
const rebalancerDest = './export/Rebalancer.json';

if (fs.existsSync(rebalancerSource)) {
    fs.copyFileSync(rebalancerSource, rebalancerDest);
    console.log('Rebalancer.json скопирован в export/');
} else {
    console.log('Rebalancer.json не найден в deployments/arbitrumOne/');
}

// read deployed-vaults.json for getting information about vault's
const deployedVaultsPath = './deployments/arbitrumOne/deployed-vaults.json';
let vaultsData = {};

if (fs.existsSync(deployedVaultsPath)) {
    const deployedVaults = JSON.parse(fs.readFileSync(deployedVaultsPath, 'utf8'));
    
    // create config.json
    const config = {
        networks: [
            {
                chainId: deployedVaults.chainId,
                chainName: "Arbitrum One",
                vaults: [
                    {
                        coin: "USDT",
                        address: deployedVaults.vaults.USDT.address
                    },
                    {
                        coin: "USDC", 
                        address: deployedVaults.vaults.USDC.address
                    }
                ]
            }
        ]
    };
    
    // write config.json
    fs.writeFileSync('./export/config.json', JSON.stringify(config, null, 2));
    console.log('config.json создан в export/');
} else {
    console.log('deployed-vaults.json не найден');
}
