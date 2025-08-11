import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import {
  MockERC20__factory,
  MockERC20,
  RewardsDistributor,
  RewardsDistributor__factory,
} from '../../typechain-types';

describe('RewardsDistributor', async () => {
  let deployer: SignerWithAddress;
  let rootUpdater: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  let testToken: MockERC20;
  let rewardsDistributor: RewardsDistributor;

  let ROOT_UPDATER_ROLE: string;

  let assetDecimals: bigint;

  let claimableAlice: bigint;
  let claimableBob: bigint;
  let totalClaimable: bigint;

  let proofAlice: string[];
  let proofBob: string[];

  let distributionValues: any[];
  let merkleTree: any;

  before(async () => {
    [deployer, rootUpdater, alice, bob] = await ethers.getSigners();

    ROOT_UPDATER_ROLE = ethers.id('ROOT_UPDATER_ROLE');

    assetDecimals = 18n;

    claimableAlice = ethers.parseEther('1');
    claimableBob = ethers.parseEther('2');

    totalClaimable = claimableAlice + claimableBob;
  });

  beforeEach(async () => {
    testToken = await new MockERC20__factory(deployer).deploy(
      'Mock Token',
      'MTK',
      assetDecimals
    );

    rewardsDistributor = await new RewardsDistributor__factory(
      deployer
    ).deploy();

    await rewardsDistributor.grantRole(ROOT_UPDATER_ROLE, rootUpdater.address);
    await testToken.mint(await rewardsDistributor.getAddress(), totalClaimable);

    distributionValues = [
      [alice.address, await testToken.getAddress(), claimableAlice],
      [bob.address, await testToken.getAddress(), claimableBob],
    ];

    merkleTree = StandardMerkleTree.of(distributionValues, [
      'address',
      'address',
      'uint256',
    ]);

    proofAlice = merkleTree.getProof(distributionValues[0]);
    proofBob = merkleTree.getProof(distributionValues[1]);
  });

  describe('claim', async () => {
    it('Should revert if the contract is paused', async () => {
      await rewardsDistributor.pause();

      await expect(
        rewardsDistributor
          .connect(alice)
          .claim(
            alice.address,
            await testToken.getAddress(),
            claimableAlice,
            proofAlice
          )
      ).to.be.revertedWithCustomError(rewardsDistributor, 'EnforcedPause');
    });
    it('Should revert if there is no root', async () => {
      await expect(
        rewardsDistributor
          .connect(alice)
          .claim(
            alice.address,
            await testToken.getAddress(),
            claimableAlice,
            proofAlice
          )
      ).to.be.revertedWithCustomError(
        rewardsDistributor,
        'RewardsDistributor__InvalidProof'
      );
    });
    it('Should revert when the rewards have already been claimed', async () => {
      await rewardsDistributor.connect(rootUpdater).updateRoot(merkleTree.root);

      await rewardsDistributor
        .connect(alice)
        .claim(
          alice.address,
          await testToken.getAddress(),
          claimableAlice,
          proofAlice
        );

      await expect(
        rewardsDistributor
          .connect(alice)
          .claim(
            alice.address,
            await testToken.getAddress(),
            claimableAlice,
            proofAlice
          )
      ).to.be.revertedWithCustomError(
        rewardsDistributor,
        'RewardsDistributor__AlreadyClaimed'
      );
    });
    it('Should claim the rewards', async () => {
      await rewardsDistributor.connect(rootUpdater).updateRoot(merkleTree.root);

      const tx = await rewardsDistributor
        .connect(bob)
        .claim(
          bob.address,
          await testToken.getAddress(),
          claimableBob,
          proofBob
        );

      expect(await testToken.balanceOf(bob.address)).to.equal(claimableBob);
      expect(
        await testToken.balanceOf(await rewardsDistributor.getAddress())
      ).to.equal(totalClaimable - claimableBob);

      await expect(tx)
        .to.emit(rewardsDistributor, 'RewardsClaimed')
        .withArgs(bob.address, await testToken.getAddress(), claimableBob);
    });
  });

  describe('updateRoot', async () => {
    const newRoot = ethers.encodeBytes32String('newRoot');
    it('Should revert if the caller is not the root updater', async () => {
      await expect(
        rewardsDistributor.connect(alice).updateRoot(newRoot)
      ).to.be.revertedWithCustomError(
        rewardsDistributor,
        'AccessManager__CallerIsNotRootUpdater'
      );
    });
    it('Should update the root', async () => {
      const tx = await rewardsDistributor
        .connect(rootUpdater)
        .updateRoot(newRoot);

      expect(await rewardsDistributor.root()).to.equal(newRoot);
      await expect(tx)
        .to.emit(rewardsDistributor, 'RootUpdated')
        .withArgs(newRoot);
    });
  });

  describe('withdraw', async () => {
    it('Should revert when called by non-admin', async () => {
      await expect(
        rewardsDistributor.connect(alice).withdraw(await testToken.getAddress())
      ).to.be.revertedWithCustomError(
        rewardsDistributor,
        'AccessManager__CallerIsNotAdmin'
      );
    });
    it('Should withdraw the contract balance', async () => {
      await rewardsDistributor
        .connect(deployer)
        .withdraw(await testToken.getAddress());

      expect(
        await testToken.balanceOf(await rewardsDistributor.getAddress())
      ).to.equal(0);
      expect(await testToken.balanceOf(deployer.address)).to.equal(
        totalClaimable
      );
    });
  });

  describe('pause', async () => {
    it('Should revert when called by non-admin', async () => {
      await expect(
        rewardsDistributor.connect(alice).pause()
      ).to.be.revertedWithCustomError(
        rewardsDistributor,
        'AccessManager__CallerIsNotAdmin'
      );
    });
    it('Should revert if the contract is already paused', async () => {
      await rewardsDistributor.connect(deployer).pause();

      await expect(
        rewardsDistributor.connect(deployer).pause()
      ).to.be.revertedWithCustomError(rewardsDistributor, 'EnforcedPause');
    });
    it('Should pause the contract', async () => {
      const tx = await rewardsDistributor.connect(deployer).pause();

      expect(await rewardsDistributor.paused()).to.equal(true);
      await expect(tx)
        .to.emit(rewardsDistributor, 'Paused')
        .withArgs(deployer.address);
    });
  });

  describe('unpause', async () => {
    it('Should revert when called by non-admin', async () => {
      await expect(
        rewardsDistributor.connect(alice).unpause()
      ).to.be.revertedWithCustomError(
        rewardsDistributor,
        'AccessManager__CallerIsNotAdmin'
      );
    });
    it('Should revert if the contract is not paused', async () => {
      await expect(
        rewardsDistributor.connect(deployer).unpause()
      ).to.be.revertedWithCustomError(rewardsDistributor, 'ExpectedPause');
    });
    it('Should unpause the contract', async () => {
      await rewardsDistributor.connect(deployer).pause();

      const tx = await rewardsDistributor.connect(deployer).unpause();

      expect(await rewardsDistributor.paused()).to.equal(false);
      await expect(tx)
        .to.emit(rewardsDistributor, 'Unpaused')
        .withArgs(deployer.address);
    });
  });
});
