# EVM Stack - Техническое Задание

## 1. ОБЗОР EVM СТЕКА

### 1.1 Цель и Целевые Метрики
- **Целевая доходность**: 15-18% APY на Ethereum, 5-7% на Bitcoin
- **Основная стратегия**: Дельта-нейтральное фармирование через перп протоколы
- **Плечо**: 1.5x - 2x
- **Базовые активы**: ETH, BTC, стейблкоины (USDC, USDT, DAI)

### 1.2 Архитектурные Принципы
- **ERC-4626 Compliance**: Стандартизированные vault интерфейсы
- **Modular Design**: Отдельные контракты для каждой функциональности
- **Multi-Protocol Integration**: GMX, Gains.trade, AAVE для комплексной стратегии
- **Chainlink Automation**: Автоматизированные ребалансировки

---

## 2. SMART CONTRACT АРХИТЕКТУРА

### 2.1 Основной Vault Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ThesaurosDeltaVault is ERC20, ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;
    
    // Роли доступа
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    // Структуры данных
    struct StrategyParams {
        uint256 targetLeverage;        // 150 = 1.5x (в базисных пунктах)
        uint256 rebalanceThreshold;   // 500 = 5% (в базисных пунктах)
        uint256 maxSlippage;          // 100 = 1% (в базисных пунктах)
        uint256 emergencyExitThreshold; // 110 = 1.1 health factor
        AssetAllocation targetAllocation;
    }
    
    struct AssetAllocation {
        uint16 ethWeight;    // 4000 = 40% (в базисных пунктах)
        uint16 btcWeight;    // 3500 = 35%
        uint16 stableWeight; // 2500 = 25%
    }

    struct FeeStructure {
        uint256 performanceFee;  // 2000 = 20% (в базисных пунктах)
        uint256 managementFee;   // 0 = 0%
        uint256 withdrawalFee;   // 50 = 0.5%
        uint256 rebalancingFee;  // 10 = 0.1%
    }

    struct PositionInfo {
        uint256 spotValue;      // Стоимость спот позиций
        uint256 perpValue;      // Стоимость перп позиций
        int256 totalPnl;        // Общая прибыль/убыток
        uint256 healthFactor;   // Health factor позиций
        uint256 leverage;       // Текущее плечо
    }
    
    // Состояние контракта
    IERC20 public immutable depositAsset; // USDC
    StrategyParams public strategyParams;
    FeeStructure public feeStructure;
    
    uint256 public totalAssets;
    uint256 public lastRebalance;
    uint256 public totalFeesCollected;
    bool public emergencyExit;
    
    // Интеграции с протоколами
    IPerpProtocol public perpProtocol;
    ILendingProtocol public lendingProtocol;
    ISwapRouter public swapRouter;
    IChainlinkAutomation public automation;
    
    // Маппинги
    mapping(address => uint256) public userLastDeposit;
    mapping(address => uint256) public userTotalDeposited;
    
    // События
    event Deposited(address indexed user, uint256 amount, uint256 shares, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 shares, uint256 amount, uint256 timestamp);
    event Rebalanced(uint256 totalValue, uint256 newLeverage, uint256 timestamp);
    event EmergencyExit(string reason, address triggeredBy, uint256 timestamp);
    event FeesCollected(uint256 amount, string feeType, uint256 timestamp);
    event StrategyParamsUpdated(StrategyParams newParams, uint256 timestamp);
    
    // Модификаторы
    modifier onlyRebalancer() {
        require(hasRole(REBALANCER_ROLE, msg.sender), "Not authorized rebalancer");
        _;
    }
    
    modifier onlyRiskManager() {
        require(hasRole(RISK_MANAGER_ROLE, msg.sender), "Not authorized risk manager");
        _;
    }
    
    modifier notInEmergencyExit() {
        require(!emergencyExit, "Vault in emergency exit");
        _;
    }

    constructor(
        address _depositAsset,
        string memory _name,
        string memory _symbol,
        StrategyParams memory _strategyParams,
        FeeStructure memory _feeStructure,
        address _admin
    ) ERC20(_name, _symbol) {
        depositAsset = IERC20(_depositAsset);
        strategyParams = _strategyParams;
        feeStructure = _feeStructure;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(REBALANCER_ROLE, _admin);
        _grantRole(RISK_MANAGER_ROLE, _admin);
        
        lastRebalance = block.timestamp;
        
        emit StrategyParamsUpdated(_strategyParams, block.timestamp);
    }

    /// @notice Депозит пользователя с автоматическим исполнением стратегии
    /// @param amount Сумма для депозита в базовом активе
    /// @return shares Количество выпущенных vault токенов
    function deposit(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        notInEmergencyExit 
        returns (uint256 shares) 
    {
        require(amount > 0, "Amount must be greater than 0");
        require(amount >= 100e6, "Minimum deposit is 100 USDC"); // 100 USDC minimum
        
        uint256 currentTotalAssets = getTotalAssets();
        uint256 supply = totalSupply();
        
        // Расчет shares по стандарту ERC4626
        shares = supply == 0 
            ? amount 
            : (amount * supply) / currentTotalAssets;
            
        require(shares > 0, "Zero shares minted");
        
        // Трансфер депозита
        depositAsset.safeTransferFrom(msg.sender, address(this), amount);
        
        // Выпуск shares
        _mint(msg.sender, shares);
        
        // Обновление состояния
        totalAssets += amount;
        userLastDeposit[msg.sender] = block.timestamp;
        userTotalDeposited[msg.sender] += amount;
        
        // Исполнение стратегии для нового депозита
        _executeStrategy(amount);
        
        emit Deposited(msg.sender, amount, shares, block.timestamp);
    }

    /// @notice Вывод средств пользователя с пропорциональным закрытием позиций
    /// @param shares Количество vault токенов для обмена
    /// @return amount Сумма базового актива к выводу
    function withdraw(uint256 shares) 
        external 
        nonReentrant 
        returns (uint256 amount) 
    {
        require(shares > 0, "Shares must be greater than 0");
        require(shares <= balanceOf(msg.sender), "Insufficient shares");
        
        uint256 currentTotalAssets = getTotalAssets();
        uint256 supply = totalSupply();
        
        // Расчет суммы к выводу
        amount = (shares * currentTotalAssets) / supply;
        
        // Расчет и удержание withdrawal fee
        uint256 withdrawalFee = (amount * feeStructure.withdrawalF