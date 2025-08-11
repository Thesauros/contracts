# RewardsDistributor

Rewards distributor using Merkle proof for efficient token reward distribution.

**File:** `contracts/RewardsDistributor.sol`

## Overview

RewardsDistributor provides efficient reward distribution to users using Merkle proof. This allows distributing rewards without storing state for each user, significantly reducing gas costs.

## Constructor

```solidity
constructor()
```

The contract does not require parameters in the constructor, as all settings are performed through management methods.

## Main Methods

### claim(address account, address reward, uint256 claimable, bytes32[] calldata proof)

Allows a user to claim rewards using Merkle proof.

```solidity
function claim(
    address account,
    address reward,
    uint256 claimable,
    bytes32[] calldata proof
) external whenNotPaused
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `account` | `address` | Address of the reward recipient |
| `reward` | `address` | Address of the reward token |
| `claimable` | `uint256` | Total amount of available rewards |
| `proof` | `bytes32[]` | Merkle proof for verification |

#### Limitations

- Contract must not be paused (`whenNotPaused`)
- Merkle proof must be valid
- Rewards must not have been already claimed

#### Execution Logic

1. **Merkle Proof Verification** - verify that data matches the Merkle tree root
2. **Already Claimed Check** - calculate amount of rewards not yet claimed
3. **Token Transfer** - send rewards to user address
4. **State Update** - record amount of claimed rewards

#### Events

```solidity
event RewardsClaimed(address indexed account, address indexed reward, uint256 amount);
```

### updateRoot(bytes32 _root)

Updates the Merkle tree root for new reward distribution.

```solidity
function updateRoot(bytes32 _root) external onlyRootUpdater
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_root` | `bytes32` | New Merkle tree root |

#### Limitations

- Can only be called by root updater (`onlyRootUpdater`)

#### Events

```solidity
event RootUpdated(bytes32 indexed root);
```

### withdraw(address token)

Withdraws all tokens from the contract (admin only).

```solidity
function withdraw(address token) external onlyAdmin
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `token` | `address` | Address of the token to withdraw |

#### Limitations

- Can only be called by admin (`onlyAdmin`)

## Management Methods

### pause()

Pauses the contract.

```solidity
function pause() external onlyAdmin
```

#### Limitations

- Can only be called by admin (`onlyAdmin`)

### unpause()

Resumes contract operation.

```solidity
function unpause() external onlyAdmin
```

#### Limitations

- Can only be called by admin (`onlyAdmin`)

## View Methods

### claimed(address account, address reward)

Returns the amount of rewards already claimed by a user.

```solidity
function claimed(address account, address reward) public view returns (uint256)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `account` | `address` | User address |
| `reward` | `address` | Reward token address |

#### Returns

- `uint256` - Amount of rewards already claimed

### merkleRoot()

Returns the current Merkle tree root.

```solidity
function merkleRoot() public view returns (bytes32)
```

#### Returns

- `bytes32` - Current Merkle tree root

## Merkle Proof System

### How It Works

1. **Tree Construction**
   ```solidity
   // Leaf structure
   keccak256(abi.encodePacked(account, reward, claimable))
   ```

2. **Proof Verification**
   ```solidity
   // Verify proof
   bytes32 leaf = keccak256(abi.encodePacked(account, reward, claimable));
   bytes32 computedHash = leaf;
   
   for (uint256 i = 0; i < proof.length; i++) {
       bytes32 proofElement = proof[i];
       if (computedHash <= proofElement) {
           computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
       } else {
           computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
       }
   }
   
   return computedHash == merkleRoot;
   ```

### Claim Calculation

```solidity
// Calculate unclaimed amount
uint256 claimedAmount = claimed(account, reward);
uint256 unclaimedAmount = claimable - claimedAmount;

// Transfer rewards
if (unclaimedAmount > 0) {
    IERC20(reward).transfer(account, unclaimedAmount);
    _claimed[account][reward] = claimable;
    emit RewardsClaimed(account, reward, unclaimedAmount);
}
```

## Usage Examples

### Claiming Rewards

```solidity
// User claims their rewards
rewardsDistributor.claim(
    userAddress,      // User address
    rewardToken,      // Reward token address
    1000e6,          // Total claimable amount
    merkleProof      // Merkle proof
);
```

### Updating Root

```solidity
// Admin updates Merkle root for new distribution
rewardsDistributor.updateRoot(newMerkleRoot);
```

### Emergency Withdrawal

```solidity
// Admin withdraws all tokens in emergency
rewardsDistributor.withdraw(tokenAddress);
```

## Security Features

### Merkle Proof Validation

- Cryptographic verification of reward claims
- Prevents double-spending
- Efficient for large user bases

### Access Control

- Only admins can pause/unpause
- Only root updaters can update Merkle root
- Only admins can withdraw tokens

### State Management

- Tracks claimed amounts per user per token
- Prevents duplicate claims
- Maintains audit trail

## Integration

### With RebalancerWithRewards

```solidity
// Rebalancer transfers rewards to distributor
rewardsDistributor.transfer(rewardToken, amount);

// Users claim rewards
rewardsDistributor.claim(account, rewardToken, claimable, proof);
```

### With VaultManager

```solidity
// VaultManager can trigger reward distribution
vaultManager.distributeRewards(vault, rewardsDistributor);
```

## Events

### RewardsClaimed

Emitted when rewards are successfully claimed.

```solidity
event RewardsClaimed(
    address indexed account,  // User address
    address indexed reward,   // Reward token
    uint256 amount           // Claimed amount
);
```

### RootUpdated

Emitted when Merkle root is updated.

```solidity
event RootUpdated(bytes32 indexed root);
```

## Errors

```solidity
error RewardsDistributor__InvalidProof();
error RewardsDistributor__AlreadyClaimed();
```

### Error Descriptions

- `RewardsDistributor__InvalidProof()` - Merkle proof is invalid
- `RewardsDistributor__AlreadyClaimed()` - Rewards already claimed

## State Variables

```solidity
bytes32 public merkleRoot;
mapping(address => mapping(address => uint256)) private _claimed;
bool public paused;
```

## Modifiers

```solidity
modifier whenNotPaused() {
    if (paused) {
        revert Pausable__Paused();
    }
    _;
}
```

## Best Practices

### Merkle Tree Generation

- Use deterministic ordering for tree construction
- Include all necessary data in leaf hashes
- Validate tree integrity before deployment

### Gas Optimization

- Batch multiple claims in single transaction
- Use efficient proof verification
- Minimize storage operations

### Security Considerations

- Validate Merkle root updates
- Monitor for unusual claim patterns
- Implement rate limiting if needed

## Testing

### Unit Tests

```solidity
function testClaimRewards() public {
    // Setup
    bytes32[] memory proof = generateProof(user, reward, amount);
    
    // Execute
    rewardsDistributor.claim(user, reward, amount, proof);
    
    // Verify
    assertEq(rewardToken.balanceOf(user), amount);
    assertEq(rewardsDistributor.claimed(user, reward), amount);
}
```

### Integration Tests

```solidity
function testMerkleRootUpdate() public {
    // Setup
    bytes32 newRoot = generateNewMerkleRoot();
    
    // Execute
    rewardsDistributor.updateRoot(newRoot);
    
    // Verify
    assertEq(rewardsDistributor.merkleRoot(), newRoot);
}
```

## Gas Optimization

### Efficient Proof Verification

```solidity
// Optimized proof verification
function verifyProof(
    bytes32 leaf,
    bytes32[] memory proof,
    bytes32 root
) internal pure returns (bool) {
    bytes32 computedHash = leaf;
    
    for (uint256 i = 0; i < proof.length; i++) {
        bytes32 proofElement = proof[i];
        if (computedHash <= proofElement) {
            computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
        } else {
            computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
        }
    }
    
    return computedHash == root;
}
```

### Batch Operations

```solidity
// Batch claim multiple rewards
function batchClaim(
    address[] memory accounts,
    address[] memory rewards,
    uint256[] memory claimables,
    bytes32[][] memory proofs
) external {
    for (uint256 i = 0; i < accounts.length; i++) {
        claim(accounts[i], rewards[i], claimables[i], proofs[i]);
    }
} 