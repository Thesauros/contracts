import { ethers, deployments } from 'hardhat';

async function main() {
  const initialDeposit = ethers.parseUnits('1', 6);

  const rebalancerDeployment = await deployments.get('Rebalancer');
  const vault = await ethers.getContractAt(
    'Rebalancer',
    rebalancerDeployment.address
  );

  const assetAddress = await vault.asset();
  const asset = await ethers.getContractAt('IERC20', assetAddress);

  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();

  const balance = await asset.balanceOf(signerAddress);
  if (balance < initialDeposit) {
    throw new Error(
      `Insufficient asset balance for setupVault(): need ${initialDeposit.toString()}`
    );
  }

  await asset.approve(rebalancerDeployment.address, initialDeposit).then((tx) =>
    tx.wait()
  );

  await vault.setupVault(initialDeposit).then((tx) => tx.wait());

  console.log(`Vault initialized at ${rebalancerDeployment.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
