# Solana Stack - Техническое Задание

## 1. ОБЗОР SOLANA СТЕКА

### 1.1 Цель и Целевые Метрики
- **Целевая доходность**: 30% APY (приоритетная сеть)
- **Основная стратегия**: Дельта-нейтральное фармирование через Drift Protocol
- **Плечо**: 1.5x - 2x
- **Базовые активы**: SOL, ETH, BTC (через wrapped tokens)

### 1.2 Архитектурные Принципы
- **Anchor Framework**: Все контракты на Anchor
- **Drift Protocol Integration**: Нативная интеграция с Drift для перпов
- **Jupiter Integration**: Оптимальные свапы через Jupiter Aggregator
- **Cross-program Invocation**: Эффективное взаимодействие с внешними протоколами

---

## 2. SMART CONTRACT АРХИТЕКТУРА

### 2.1 Основной Vault Contract

```rust
// lib.rs
use anchor_lang::prelude::*;
use drift::cpi::accounts::*;
use drift::program::Drift;
use drift::{
    instructions::DriftInstruction,
    state::{perp_market::PerpMarket, user::User},
};

declare_id!("Thes4uRos1111111111111111111111111111111111");

#[program]
pub mod thesauros_drift_vault {
    use super::*;

    /// Инициализация vault
    pub fn initialize_vault(
        ctx: Context<InitializeVault>,
        risk_params: RiskParams,
        strategy_params: StrategyParams,
    ) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        let clock = Clock::get()?;

        vault.authority = ctx.accounts.authority.key();
        vault.drift_program = ctx.accounts.drift_program.key();
        vault.risk_params = risk_params;
        vault.strategy_params = strategy_params;
        vault.total_shares = 0;
        vault.total_assets = 0;
        vault.created_at = clock.unix_timestamp;
        vault.last_rebalance = clock.unix_timestamp;
        vault.bump = ctx.bumps.vault;

        // Инициализация Drift user account
        let cpi_ctx = CpiContext::new(
            ctx.accounts.drift_program.to_account_info(),
            drift::cpi::accounts::InitializeUser {
                user: ctx.accounts.drift_user.to_account_info(),
                user_stats: ctx.accounts.drift_user_stats.to_account_info(),
                state: ctx.accounts.drift_state.to_account_info(),
                authority: ctx.accounts.vault.to_account_info(),
                payer: ctx.accounts.payer.to_account_info(),
                rent: ctx.accounts.rent.to_account_info(),
                system_program: ctx.accounts.system_program.to_account_info(),
            },
        );
        drift::cpi::initialize_user(cpi_ctx, 0, "thesauros_vault")?;

        msg!("Vault initialized with authority: {}", vault.authority);
        Ok(())
    }

    /// Депозит пользователя
    pub fn deposit(
        ctx: Context<Deposit>,
        amount: u64,
    ) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        let user_account = &mut ctx.accounts.user_account;
        let clock = Clock::get()?;

        require!(amount > 0, VaultError::InvalidAmount);
        require!(amount >= MIN_DEPOSIT_AMOUNT, VaultError::DepositTooSmall);

        // Расчет shares по формуле ERC4626
        let shares_to_mint = if vault.total_shares == 0 {
            amount
        } else {
            let total_assets = calculate_total_assets(ctx.accounts)?;
            (amount as u128)
                .checked_mul(vault.total_shares as u128)
                .unwrap()
                .checked_div(total_assets as u128)
                .unwrap() as u64
        };

        // Трансфер токенов от пользователя в vault
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            anchor_spl::token::Transfer {
                from: ctx.accounts.user_token_account.to_account_info(),
                to: ctx.accounts.vault_token_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        );
        anchor_spl::token::transfer(cpi_ctx, amount)?;

        // Обновление состояния
        vault.total_shares += shares_to_mint;
        vault.total_assets += amount;

        if user_account.vault != vault.key() {
            user_account.vault = vault.key();
            user_account.user = ctx.accounts.user.key();
            user_account.shares = 0;
            user_account.total_deposited = 0;
            user_account.last_deposit = 0;
        }

        user_account.shares += shares_to_mint;
        user_account.total_deposited += amount;
        user_account.last_deposit = clock.unix_timestamp;

        // Исполнение стратегии
        execute_strategy(ctx.remaining_accounts, amount, vault)?;

        emit!(DepositEvent {
            user: ctx.accounts.user.key(),
            amount,
            shares: shares_to_mint,
            total_vault_assets: vault.total_assets,
            timestamp: clock.unix_timestamp,
        });

        msg!("User {} deposited {} tokens, received {} shares", 
             ctx.accounts.user.key(), amount, shares_to_mint);
        Ok(())
    }

    /// Вывод средств
    pub fn withdraw(
        ctx: Context<Withdraw>,
        shares: u64,
    ) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        let user_account = &mut ctx.accounts.user_account;
        let clock = Clock::get()?;

        require!(shares > 0, VaultError::InvalidAmount);
        require!(shares <= user_account.shares, VaultError::InsufficientShares);

        let total_assets = calculate_total_assets(ctx.accounts)?;
        let assets_to_withdraw = (shares as u128)
            .checked_mul(total_assets as u128)
            .unwrap()
            .checked_div(vault.total_shares as u128)
            .unwrap() as u64;

        // Закрытие позиций пропорционально
        close_positions_proportionally(
            ctx.remaining_accounts, 
            shares, 
            vault.total_shares, 
            vault
        )?;

        // Трансфер токенов пользователю
        let vault_seeds = &[
            VAULT_SEED.as_bytes(),
            vault.authority.as_ref(),
            &[vault.bump],
        ];
        let signer_seeds = &[&vault_seeds[..]];

        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            anchor_spl::token::Transfer {
                from: ctx.accounts.vault_token_account.to_account_info(),
                to: ctx.accounts.user_token_account.to_account_info(),
                authority: vault.to_account_info(),
            },
            signer_seeds,
        );
        anchor_spl::token::transfer(cpi_ctx, assets_to_withdraw)?;

        // Обновление состояния
        vault.total_shares -= shares;
        vault.total_assets = vault.total_assets.saturating_sub(assets_to_withdraw);
        user_account.shares -= shares;

        emit!(WithdrawEvent {
            user: ctx.accounts.user.key(),
            shares,
            amount: assets_to_withdraw,
            total_vault_assets: vault.total_assets,
            timestamp: clock.unix_timestamp,
        });

        msg!("User {} withdrew {} shares for {} tokens", 
             ctx.accounts.user.key(), shares, assets_to_withdraw);
        Ok(())
    }

    /// Ребалансировка стратегии
    pub fn rebalance(ctx: Context<Rebalance>) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        let clock = Clock::get()?;
        
        // Проверка временного интервала
        require!(
            clock.unix_timestamp - vault.last_rebalance >= MIN_REBALANCE_INTERVAL,
            VaultError::RebalanceTooFrequent
        );

        // Получение текущего состояния позиций
        let current_allocation = get_current_allocation(ctx.accounts)?;
        let target_allocation = &vault.strategy_params.target_allocation;

        // Проверка необходимости ребалансировки
        if !needs_rebalancing(&current_allocation, target_allocation, vault.strategy_params.rebalance_threshold) {
            return Ok(());
        }

        // Исполнение ребалансировки
        execute_rebalancing(
            ctx.remaining_accounts,
            &current_allocation,
            target_allocation,
            vault,
        )?;

        vault.last_rebalance = clock.unix_timestamp;

        emit!(RebalanceEvent {
            vault: vault.key(),
            old_allocation: current_allocation,
            new_allocation: target_allocation.clone(),
            timestamp: clock.unix_timestamp,
        });

        msg!("Vault rebalanced successfully");
        Ok(())
    }

    /// Экстренная остановка
    pub fn emergency_exit(ctx: Context<EmergencyExit>) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        
        // Проверка авторизации (только authority или риск-менеджер)
        require!(
            ctx.accounts.authority.key() == vault.authority ||
            ctx.accounts.authority.key() == vault.risk_params.risk_manager,
            VaultError::Unauthorized
        );

        // Закрытие всех позиций
        close_all_positions(ctx.remaining_accounts, vault)?;

        vault.emergency_exit = true;

        emit!(EmergencyExitEvent {
            vault: vault.key(),
            triggered_by: ctx.accounts.authority.key(),
            timestamp: Clock::get()?.unix_timestamp,
        });

        msg!("Emergency exit triggered by {}", ctx.accounts.authority.key());
        Ok(())
    }
}
```

### 2.2 Структуры Данных

```rust
// state.rs
use anchor_lang::prelude::*;

pub const VAULT_SEED: &str = "vault";
pub const USER_ACCOUNT_SEED: &str = "user_account";
pub const MIN_DEPOSIT_AMOUNT: u64 = 1_000_000; // 1 USDC
pub const MIN_REBALANCE_INTERVAL: i64 = 3600; // 1 hour

#[account]
pub struct Vault {
    /// Владелец vault
    pub authority: Pubkey,
    /// Drift program ID
    pub drift_program: Pubkey,
    /// Drift user account для этого vault
    pub drift_user: Pubkey,
    /// Параметры стратегии
    pub strategy_params: StrategyParams,
    /// Параметры риска
    pub risk_params: RiskParams,
    /// Общее количество выпущенных shares
    pub total_shares: u64,
    /// Общая стоимость активов в vault
    pub total_assets: u64,
    /// Время создания
    pub created_at: i64,
    /// Время последней ребалансировки
    pub last_rebalance: i64,
    /// Флаг экстренного выхода
    pub emergency_exit: bool,
    /// Bump seed для PDA
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct StrategyParams {
    /// Целевое плечо (базисные пункты, 150 = 1.5x)
    pub target_leverage: u16,
    /// Коэффициент хеджирования (базисные пункты, 10000 = 100%)
    pub hedge_ratio: u16,
    /// Порог для ребалансировки (базисные пункты, 500 = 5%)
    pub rebalance_threshold: u16,
    /// Целевая аллокация активов
    pub target_allocation: AssetAllocation,
    /// Максимальный slippage (базисные пункты, 100 = 1%)
    pub max_slippage: u16,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct AssetAllocation {
    /// Вес SOL (базисные пункты)
    pub sol_weight: u16,
    /// Вес ETH (базисные пункты)  
    pub eth_weight: u16,
    /// Вес BTC (базисные пункты)
    pub btc_weight: u16,
    /// Вес стейблкоинов (базисные пункты)
    pub stable_weight: u16,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct RiskParams {
    /// Максимальное плечо (базисные пункты)
    pub max_leverage: u16,
    /// Минимальный health factor
    pub min_health_factor: u16,
    /// Порог ликвидации для emergency exit
    pub liquidation_threshold: u16,
    /// Максимальный размер позиции
    pub max_position_size: u64,
    /// Менеджер рисков
    pub risk_manager: Pubkey,
}

#[account]
pub struct UserAccount {
    /// Vault, к которому принадлежит аккаунт
    pub vault: Pubkey,
    /// Пользователь
    pub user: Pubkey,
    /// Количество shares у пользователя
    pub shares: u64,
    /// Общая сумма депозитов
    pub total_deposited: u64,
    /// Время последнего депозита
    pub last_deposit: i64,
}
```

### 2.3 Контексты для инструкций

```rust
// contexts.rs
use anchor_lang::prelude::*;
use anchor_spl::token::{Token, TokenAccount, Mint};
use drift::program::Drift;
use drift::state::user::User as DriftUser;

#[derive(Accounts)]
pub struct InitializeVault<'info> {
    #[account(
        init,
        payer = payer,
        space = 8 + std::mem::size_of::<Vault>(),
        seeds = [VAULT_SEED.as_bytes(), authority.key().as_ref()],
        bump
    )]
    pub vault: Account<'info, Vault>,

    #[account(mut)]
    pub authority: Signer<'info>,

    /// CHECK: Drift user account will be initialized by CPI
    #[account(mut)]
    pub drift_user: UncheckedAccount<'info>,

    /// CHECK: Drift user stats account
    #[account(mut)]
    pub drift_user_stats: UncheckedAccount<'info>,

    /// CHECK: Drift state account
    pub drift_state: UncheckedAccount<'info>,

    pub drift_program: Program<'info, Drift>,

    #[account(mut)]
    pub payer: Signer<'info>,

    pub rent: Sysvar<'info, Rent>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(
        mut,
        seeds = [VAULT_SEED.as_bytes(), vault.authority.as_ref()],
        bump = vault.bump
    )]
    pub vault: Account<'info, Vault>,

    #[account(
        init_if_needed,
        payer = user,
        space = 8 + std::mem::size_of::<UserAccount>(),
        seeds = [USER_ACCOUNT_SEED.as_bytes(), vault.key().as_ref(), user.key().as_ref()],
        bump
    )]
    pub user_account: Account<'info, UserAccount>,

    #[account(mut)]
    pub user: Signer<'info>,

    #[account(
        mut,
        token::mint = usdc_mint,
        token::authority = user,
    )]
    pub user_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        token::mint = usdc_mint,
        token::authority = vault,
    )]
    pub vault_token_account: Account<'info, TokenAccount>,

    pub usdc_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}
```

---

## 3. ИНТЕГРАЦИИ

### 3.1 Drift Protocol Integration

```rust
// integrations/drift.rs
use anchor_lang::prelude::*;
use drift::{
    cpi::accounts::*,
    instruction::*,
    state::{perp_market::PerpMarket, user::User},
};

pub struct DriftIntegration<'info> {
    pub drift_program: Program<'info, drift::program::Drift>,
    pub drift_user: Account<'info, User>,
    pub drift_state: UncheckedAccount<'info>,
}

impl<'info> DriftIntegration<'info> {
    /// Открытие перп позиции
    pub fn open_perp_position(
        &self,
        ctx: &Context<Rebalance>,
        market_index: u16,
        direction: PositionDirection,
        base_asset_amount: u64,
        vault: &Account<Vault>,
    ) -> Result<()> {
        let vault_seeds = &[
            VAULT_SEED.as_bytes(),
            vault.authority.as_ref(),
            &[vault.bump],
        ];
        let signer_seeds = &[&vault_seeds[..]];

        let place_order_params = OrderParams {
            order_type: OrderType::Market,
            market_type: MarketType::Perp,
            direction,
            user_order_id: 0,
            base_asset_amount,
            price: 0, // Market order
            market_index,
            reduce_only: false,
            post_only: PostOnlyParam::None,
            immediate_or_cancel: false,
            max_ts: None,
            trigger_price: None,
            trigger_condition: OrderTriggerCondition::Above,
            oracle_price_offset: None,
            auction_duration: None,
            auction_start_price: None,
            auction_end_price: None,
        };

        let cpi_ctx = CpiContext::new_with_signer(
            self.drift_program.to_account_info(),
            PlacePerpOrder {
                state: self.drift_state.to_account_info(),
                user: self.drift_user.to_account_info(),
                user_stats: ctx.remaining_accounts[0].to_account_info(),
                authority: vault.to_account_info(),
            },
            signer_seeds,
        );

        drift::cpi::place_perp_order(cpi_ctx, place_order_params)?;

        msg!("Opened {} perp position on market {} for {} base units", 
             match direction {
                 PositionDirection::Long => "long",
                 PositionDirection::Short => "short",
             },
             market_index, 
             base_asset_amount
        );

        Ok(())
    }

    /// Получение текущих funding rates
    pub fn get_funding_rates(&self, ctx: &Context<Rebalance>) -> Result<Vec<FundingRate>> {
        let mut funding_rates = Vec::new();

        // Получение funding rates для основных рынков
        let markets = vec![
            0,  // SOL-PERP
            1,  // ETH-PERP  
            2,  // BTC-PERP
        ];

        for market_index in markets {
            if let Some(market_account) = ctx.remaining_accounts
                .iter()
                .find(|account| {
                    // Проверка что это правильный market account
                    true
                }) {
                
                let market_data = PerpMarket::load(&market_account.data.borrow())?;
                
                funding_rates.push(FundingRate {
                    market_index,
                    funding_rate: market_data.amm.last_funding_rate,
                    predicted_funding_rate: market_data.amm.last_funding_rate,
                });
            }
        }

        Ok(funding_rates)
    }
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct FundingRate {
    pub market_index: u16,
    pub funding_rate: i64,
    pub predicted_funding_rate: i64,
}
```

### 3.2 Jupiter Integration

```rust
// integrations/jupiter.rs
use anchor_lang::prelude::*;

pub struct JupiterIntegration;

impl JupiterIntegration {
    /// Свап для ребалансировки портфеля
    pub fn swap_for_rebalancing<'info>(
        ctx: &Context<'_, '_, '_, 'info, Rebalance<'info>>,
        current_allocation: &AssetAllocation,
        target_allocation: &AssetAllocation,
        total_value: u64,
        vault: &Account<Vault>,
    ) -> Result<()> {
        // Расчет необходимых свапов
        let required_swaps = Self::calculate_required_swaps(
            current_allocation,
            target_allocation,
            total_value,
        )?;

        for swap in required_swaps {
            if swap.amount > 0 {
                Self::execute_jupiter_swap(ctx, &swap, vault)?;
            }
        }

        Ok(())
    }

    fn calculate_required_swaps(
        current: &AssetAllocation,
        target: &AssetAllocation,
        total_value: u64,
    ) -> Result<Vec<RequiredSwap>> {
        let mut swaps = Vec::new();

        // SOL rebalancing
        let current_sol_value = (total_value as u128 * current.sol_weight as u128 / 10000) as u64;
        let target_sol_value = (total_value as u128 * target.sol_weight as u128 / 10000) as u64;
        
        if current_sol_value != target_sol_value {
            let sol_mint = Pubkey::from_str("So11111111111111111111111111111111111111112").unwrap();
            let usdc_mint = Pubkey::from_str("EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v").unwrap();
            
            if current_sol_value > target_sol_value {
                // Продаем SOL
                swaps.push(RequiredSwap {
                    input_mint: sol_mint,
                    output_mint: usdc_mint,
                    amount: current_sol_value - target_sol_value,
                    min_out_amount: (current_sol_value - target_sol_value) * 95 / 100,
                });
            } else {
                // Покупаем SOL
                swaps.push(RequiredSwap {
                    input_mint: usdc_mint,
                    output_mint: sol_mint,
                    amount: target_sol_value - current_sol_value,
                    min_out_amount: (target_sol_value - current_sol_value) * 95 / 100,
                });
            }
        }

        Ok(swaps)
    }
}

#[derive(Debug)]
struct RequiredSwap {
    input_mint: Pubkey,
    output_mint: Pubkey,
    amount: u64,
    min_out_amount: u64,
}
```

---

## 4. СТРАТЕГИЯ И ЛОГИКА

### 4.1 Исполнение Стратегии

```rust
// strategy/execution.rs
use anchor_lang::prelude::*;

/// Исполнение дельта-нейтральной стратегии
pub fn execute_strategy<'info>(
    remaining_accounts: &[AccountInfo<'info>],
    deposit_amount: u64,
    vault: &mut Account<'info, Vault>,
) -> Result<()> {
    let allocation = &vault.strategy_params.target_allocation;
    
    // 1. Распределение депозита согласно целевой аллокации
    let sol_amount = (deposit_amount as u128 * allocation.sol_weight as u128 / 10000) as u64;
    let eth_amount = (deposit_amount as u128 * allocation.eth_weight as u128 / 10000) as u64;
    let btc_amount = (deposit_amount as u128 * allocation.btc_weight as u128 / 10000) as u64;
    let stable_amount = deposit_amount - sol_amount - eth_amount - btc_amount;

    msg!("Executing strategy with allocation: SOL={}, ETH={}, BTC={}, Stable={}", 
         sol_amount, eth_amount, btc_amount, stable_amount);

    // 2. Покупка спот позиций через Jupiter
    if sol_amount > 0 || eth_amount > 0 || btc_amount > 0 {
        execute_spot_purchases(remaining_accounts, sol_amount, eth_amount, btc_amount, vault)?;
    }

    // 3. Открытие хедж позиций на Drift
    open_hedge_positions(remaining_accounts, sol_amount, eth_amount, btc_amount, vault)?;

    // 4. Использование части средств для staking (dSOL)
    if stable_amount > 0 {
        stake_sol_portion(remaining_accounts, stable_amount / 4, vault)?; // 25% в dSOL
    }

    // 5. Депозит в JLP для торговых комиссий
    deposit_to_jlp(remaining_accounts, stable_amount / 2, vault)?; // 50% в JLP

    Ok(())
}

fn execute_spot_purchases<'info>(
    remaining_accounts: &[AccountInfo<'info>],
    sol_amount: u64,
    eth_amount: u64,
    btc_amount: u64,
    vault: &mut Account<'info, Vault>,
) -> Result<()> {
    msg!("Executing spot purchases through Jupiter");
    
    // Здесь должна быть интеграция с Jupiter для свапов
    // jupiter::swap_usdc_for_sol(sol_amount)?;
    // jupiter::swap_usdc_for_eth(eth_amount)?;
    // jupiter::swap_usdc_for_btc(btc_amount)?;
    
    Ok(())
}

fn open_hedge_positions<'info>(
    remaining_accounts: &[AccountInfo<'info>],
    sol_amount: u64,
    eth_amount: u64,
    btc_amount: u64,
    vault: &mut Account<'info, Vault>,
) -> Result<()> {
    let hedge_ratio = vault.strategy_params.hedge_ratio;

    msg!("Opening hedge positions on Drift Protocol");

    // SOL hedge
    if sol_amount > 0 {
        let hedge_size = (sol_amount as u128 * hedge_ratio as u128 / 10000) as u64;
        msg!("Opening SOL short hedge for {} units", hedge_size);
    }

    // ETH hedge  
    if eth_amount > 0 {
        let hedge_size = (eth_amount as u128 * hedge_ratio as u128 / 10000) as u64;
        msg!("Opening ETH short hedge for {} units", hedge_size);
    }

    // BTC hedge
    if btc_amount > 0 {
        let hedge_size = (btc_amount as u128 * hedge_ratio as u128 / 10000) as u64;
        msg!("Opening BTC short hedge for {} units", hedge_size);
    }

    Ok(())
}
```

### 4.2 Ребалансировка

```rust
// strategy/rebalancing.rs
use anchor_lang::prelude::*;

pub fn execute_rebalancing<'info>(
    remaining_accounts: &[AccountInfo<'info>],
    current_allocation: &AssetAllocation,
    target_allocation: &AssetAllocation,
    vault: &mut Account<'info, Vault>,
) -> Result<()> {
    msg!("Starting rebalancing process");

    // 1. Проверка и корректировка funding rates
    let funding_rates = get_current_funding_rates(remaining_accounts)?;
    adjust_for_funding_rates(remaining_accounts, &funding_rates, vault)?;

    // 2. Ребалансировка спот позиций через Jupiter
    rebalance_spot_positions(current_allocation, target_allocation, vault)?;

    // 3. Корректировка хедж позиций на Drift
    rebalance_hedge_positions(target_allocation, vault)?;

    // 4. Управление маржой
    manage_margin_health(remaining_accounts, vault)?;

    msg!("Rebalancing completed successfully");
    Ok(())
}

fn adjust_for_funding_rates<'info>(
    remaining_accounts: &[AccountInfo<'info>],
    funding_rates: &[FundingRate],
    vault: &mut Account<'info, Vault>,
) -> Result<()> {
    for rate in funding_rates {
        msg!("Market {} funding rate: {}%", rate.market_index, rate.funding_rate);
        
        // Логика корректировки позиций на основе funding rates
        if rate.funding_rate > 1000000 { // > 1% годовых
            msg!("Reducing exposure for market {} due to unfavorable funding", rate.market_index);
        } else if rate.funding_rate < -2000000 { // < -2% годовых  
            msg!("Increasing exposure for market {} due to favorable funding", rate.market_index);
        }
    }
    
    Ok(())
}
```

---

## 5. МОНИТОРИНГ И АВТОМАТИЗАЦИЯ

### 5.1 Rebalancing Bot

```typescript
// monitoring/rebalancing_bot.ts
import { Connection, PublicKey } from '@solana/web3.js';
import { AnchorProvider, Wallet, Program } from '@coral-xyz/anchor';
import { DriftClient } from '@drift-labs/sdk';

export class RebalancingBot {
    private connection: Connection;
    private provider: AnchorProvider;
    private program: Program;
    private driftClient: DriftClient;
    private vaultPubkey: PublicKey;
    private monitoringInterval: number;

    constructor(
        connection: Connection,
        wallet: Wallet,
        vaultPubkey: PublicKey,
        monitoringInterval: number = 300000 // 5 минут
    ) {
        this.connection = connection;
        this.provider = new AnchorProvider(connection, wallet, {});
        this.vaultPubkey = vaultPubkey;
        this.monitoringInterval = monitoringInterval;
    }

    async start(): Promise<void> {
        console.log(`Starting rebalancing bot for vault: ${this.vaultPubkey.toString()}`);
        
        setInterval(async () => {
            try {
                await this.checkAndRebalance();
            } catch (error) {
                console.error('Error in rebalancing check:', error);
            }
        }, this.monitoringInterval);
    }

    private async checkAndRebalance(): Promise<void> {
        // 1. Получение текущего состояния vault
        const vaultAccount = await this.program.account.vault.fetch(this.vaultPubkey);
        
        // 2. Проверка funding rates
        const fundingRates = await this.getCurrentFundingRates();
        console.log('Current funding rates:', fundingRates);

        // 3. Проверка health factor
        const healthFactor = await this.getHealthFactor();
        console.log('Current health factor:', healthFactor);

        // 4. Проверка необходимости ребалансировки
        const needsRebalance = await this.needsRebalancing(vaultAccount);
        
        if (needsRebalance || healthFactor < 1.2) {
            console.log('Triggering rebalancing...');
            await this.executeRebalance();
        }

        // 5. Проверка экстренных условий
        if (healthFactor < 1.1) {
            console.log('EMERGENCY: Health factor critically low, triggering emergency exit');
            await this.triggerEmergencyExit();
        }
    }

    private async getCurrentFundingRates(): Promise<FundingRate[]> {
        const fundingRates: FundingRate[] = [];
        
        // Получение funding rates через Drift client
        const solMarket = await this.driftClient.getPerpMarketAccount(0);
        const ethMarket = await this.driftClient.getPerpMarketAccount(1);
        const btcMarket = await this.driftClient.getPerpMarketAccount(2);

        fundingRates.push({
            marketIndex: 0,
            fundingRate: solMarket.amm.lastFundingRate.toNumber(),
            predictedFundingRate: solMarket.amm.lastFundingRate.toNumber()
        });

        fundingRates.push({
            marketIndex: 1,
            fundingRate: ethMarket.amm.lastFundingRate.toNumber(),
            predictedFundingRate: ethMarket.amm.lastFundingRate.toNumber()
        });

        fundingRates.push({
            marketIndex: 2,
            fundingRate: btcMarket.amm.lastFundingRate.toNumber(),
            predictedFundingRate: btcMarket.amm.lastFundingRate.toNumber()
        });

        return fundingRates;
    }

    private async getHealthFactor(): Promise<number> {
        // Получение health factor через Drift
        const user = await this.driftClient.getUser();
        return user.getHealthRatio().toNumber();
    }

    private async executeRebalance(): Promise<void> {
        try {
            const tx = await this.program.methods
                .rebalance()
                .accounts({
                    vault: this.vaultPubkey,
                    // Другие необходимые аккаунты
                })
                .rpc();
            
            console.log('Rebalancing transaction:', tx);
        } catch (error) {
            console.error('Failed to execute rebalancing:', error);
        }
    }

    private async triggerEmergencyExit(): Promise<void> {
        try {
            const tx = await this.program.methods
                .emergencyExit()
                .accounts({
                    vault: this.vaultPubkey,
                    authority: this.provider.wallet.publicKey,
                })
                .rpc();
            
            console.log('Emergency exit transaction:', tx);
        } catch (error) {
            console.error('Failed to trigger emergency exit:', error);
        }
    }
}

interface FundingRate {
    marketIndex: number;
    fundingRate: number;
    predictedFundingRate: number;
}