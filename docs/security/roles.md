# Roles and Access Rights

The Thesauros system uses a role-based access model to ensure security and control over critical operations.

## Role Overview

### Admin (Administrator)
**Highest level of access**

Administrators have full control over system settings and can perform critical operations.

#### Access Rights:
- Pause and resume operations
- Manage vault settings
- Manage providers
- Manage fees
- Manage treasury

#### Methods available to Admin:
```solidity
// Vault
function pause(Actions action) external onlyAdmin
function unpause(Actions action) external onlyAdmin
function setActiveProvider(IProvider _activeProvider) external onlyAdmin
function setTreasury(address _treasury) external onlyAdmin
function setWithdrawFeePercent(uint256 _withdrawFeePercent) external onlyAdmin
function setMinAmount(uint256 _minAmount) external onlyAdmin


// ProviderManager
function addProvider(IProvider provider) external onlyAdmin
function removeProvider(IProvider provider) external onlyAdmin
```

### Operator (Operator)
**Operational level access**

Operators can perform rebalancing and other operational tasks.

#### Access Rights:
- Execute rebalancing between providers
- Activate providers
- Manage rebalancing strategies

#### Methods available to Operator:
```solidity
// Rebalancer
function rebalance(
    uint256 assets,
    IProvider from,
    IProvider to,
    uint256 fee,
    bool activateToProvider
) external onlyOperator returns (bool)

// RebalancerWithRewards
function rebalance(
    uint256 assets,
    IProvider from,
    IProvider to,
    uint256 fee,
    bool activateToProvider
) external onlyOperator returns (bool)
```

### Executor (Executor)
**Transaction execution level**

Executors can execute transactions through VaultManager.

#### Access Rights:
- Execute rebalancing through VaultManager
- Manage multiple vaults

#### Methods available to Executor:
```solidity
// VaultManager
function rebalanceVault(
    IVault vault,
    uint256 assets,
    IProvider from,
    IProvider to,
    uint256 fee,
    bool activateToProvider
) external onlyExecutor returns (bool success)
```

### Timelock (Timelock)
**Governance level access**

Timelock can perform critical operations with delay for governance purposes.

#### Access Rights:
- Update vault providers
- Update timelock address
- Execute critical operations with delay

#### Methods available to Timelock:
```solidity
// Vault
function setProviders(IProvider[] memory providers) external onlyTimelock
function setTimelock(address _timelock) external onlyTimelock

// Timelock
function queue(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp) external onlyOwner
function execute(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp) external payable onlyOwner
function cancel(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp) external onlyOwner
```

## Role Hierarchy

```
Admin (Highest)
├── Operator
├── Executor
└── Timelock
    └── Owner (Timelock owner)
```

## Access Control Implementation

### AccessManager

The system uses `AccessManager` for role management:

```solidity
contract AccessManager {
    mapping(bytes32 => mapping(address => bool)) private _roles;
    
    modifier onlyRole(bytes32 role) {
        if (!hasRole(role, msg.sender)) {
            revert AccessManager__Unauthorized();
        }
        _;
    }
    
    function hasRole(bytes32 role, address account) public view returns (bool);
    function grantRole(bytes32 role, address account) external onlyAdmin;
    function revokeRole(bytes32 role, address account) external onlyAdmin;
}
```

### Role Constants

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
```

## Security Considerations

### Principle of Least Privilege

Each role has the minimum necessary permissions to perform its functions:

- **Admin**: Full system control
- **Operator**: Rebalancing operations only
- **Executor**: Vault management operations
- **Timelock**: Critical operations with delay

### Multi-Signature Support

Critical operations can be protected by multi-signature wallets:

```solidity
// Example: Multi-sig as admin
address public admin = multiSigWallet;

// Multi-sig can perform admin operations
function setTreasury(address _treasury) external onlyAdmin {
    treasury = _treasury;
    emit TreasuryUpdated(_treasury);
}
```

### Timelock Protection

Critical operations are protected by timelock delays:

```solidity
// Provider updates require timelock
function setProviders(IProvider[] memory providers) external onlyTimelock {
    _providers = providers;
    emit ProvidersUpdated(providers);
}
```

## Role Assignment

### Initial Setup

```solidity
// Deploy AccessManager
AccessManager accessManager = new AccessManager();

// Grant initial roles
accessManager.grantRole(ADMIN_ROLE, adminAddress);
accessManager.grantRole(OPERATOR_ROLE, operatorAddress);
accessManager.grantRole(EXECUTOR_ROLE, executorAddress);
```

### Role Updates

```solidity
// Grant new role
accessManager.grantRole(OPERATOR_ROLE, newOperatorAddress);

// Revoke role
accessManager.revokeRole(OPERATOR_ROLE, oldOperatorAddress);
```

## Emergency Procedures

### Emergency Pause

Admins can pause operations in emergency situations:

```solidity
// Pause all operations
vault.pause(Actions.Deposit);
vault.pause(Actions.Withdraw);
vault.pause(Actions.Rebalance);

```

### Emergency Withdrawal

Admins can withdraw funds in emergency:

```solidity

// Emergency rebalancing to safe provider
vaultManager.rebalanceVault(
    vault,
    type(uint256).max,
    riskyProvider,
    safeProvider,
    0,
    true
);
```

## Monitoring and Auditing

### Role Activity Tracking

All role-based operations emit events for monitoring:

```solidity
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
event AdminUpdated(address indexed admin);
event OperatorUpdated(address indexed operator);
```

### Access Logs

Monitor role changes and critical operations:

```solidity
// Track admin changes
function setAdmin(address _admin) external onlyAdmin {
    emit AdminUpdated(_admin);
    admin = _admin;
}

// Track operator changes
function setOperator(address _operator) external onlyAdmin {
    emit OperatorUpdated(_operator);
    operator = _operator;
}
```

## Best Practices

### Role Management

1. **Regular Review**: Periodically review role assignments
2. **Separation of Duties**: Avoid single points of failure
3. **Timelock Usage**: Use timelock for critical operations
4. **Multi-Sig**: Use multi-signature wallets for admin roles

### Security Measures

1. **Access Monitoring**: Monitor all role-based operations
2. **Emergency Procedures**: Have clear emergency response plans
3. **Regular Audits**: Conduct regular security audits
4. **Incident Response**: Prepare for security incidents

### Operational Guidelines

1. **Documentation**: Document all role assignments and changes
2. **Training**: Train operators on security procedures
3. **Testing**: Regularly test emergency procedures
4. **Backup Plans**: Have backup plans for critical operations

## Integration Examples

### With Governance DAO

```solidity
// DAO can control admin role
function setAdmin(address _admin) external onlyDAO {
    admin = _admin;
    emit AdminUpdated(_admin);
}

// DAO can update timelock delay
function setDelay(uint256 _delay) external onlyDAO {
    timelock.setDelay(_delay);
}
```

### With Multi-Sig Wallet

```solidity
// Multi-sig as admin
address public admin = multiSigWallet;

// Multi-sig can perform admin operations
function setTreasury(address _treasury) external onlyAdmin {
    treasury = _treasury;
    emit TreasuryUpdated(_treasury);
}
```

### With Automated Systems

```solidity
// Automated system as operator
address public operator = automationSystem;

// Automated rebalancing
function autoRebalance() external onlyOperator {
    // Automated rebalancing logic
    rebalance(amount, fromProvider, toProvider, fee, activate);
}
```

## Compliance and Governance

### Regulatory Compliance

- **KYC/AML**: Implement if required by regulations
- **Audit Trails**: Maintain complete audit trails
- **Reporting**: Regular reporting to regulators
- **Compliance Monitoring**: Monitor for compliance violations

### Governance Framework

- **DAO Integration**: Integrate with DAO governance
- **Voting Mechanisms**: Implement voting for critical decisions
- **Transparency**: Maintain transparency in operations
- **Community Involvement**: Involve community in governance

## Risk Management

### Risk Assessment

1. **Access Risk**: Risk of unauthorized access
2. **Operational Risk**: Risk of operational failures
3. **Financial Risk**: Risk of financial losses
4. **Reputational Risk**: Risk of reputational damage

### Mitigation Strategies

1. **Access Controls**: Implement strong access controls
2. **Monitoring**: Continuous monitoring of operations
3. **Insurance**: Consider insurance coverage
4. **Incident Response**: Prepare incident response plans

## Future Enhancements

### Advanced Access Control

- **Time-based Access**: Time-limited role assignments
- **Conditional Access**: Access based on conditions
- **Behavioral Analysis**: Analyze user behavior patterns
- **AI-powered Security**: AI-based security monitoring

### Governance Improvements

- **On-chain Voting**: Implement on-chain voting mechanisms
- **Delegated Voting**: Allow vote delegation
- **Quadratic Voting**: Implement quadratic voting
- **Futarchy**: Implement futarchy governance 