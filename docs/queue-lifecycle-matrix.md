# Queue Lifecycle Matrix

Current as of **2026-04-02**.

## Purpose

This document defines the Sprint 3 withdrawal queue lifecycle.

## Statuses

The current queue statuses are:

1. `Pending`
2. `Processing`
3. `Funded`
4. `Claimed`
5. `Cancelled`

## Allowed Transitions

### `Pending`

Meaning:

- request exists;
- shares are escrowed in the vault;
- no active funding workflow has been started.

Allowed next statuses:

- `Processing`
- `Funded`
- `Cancelled`

### `Processing`

Meaning:

- keeper/orchestrator has started the funding workflow;
- liquidity sourcing may already be in progress.

Allowed next statuses:

- `Funded`
- `Cancelled`

### `Funded`

Meaning:

- home-side assets are reserved;
- request is claimable.

Allowed next status:

- `Claimed`

### `Claimed`

Meaning:

- user payout completed;
- escrowed shares are burned.

Allowed next statuses:

- none

### `Cancelled`

Meaning:

- request is closed before funding;
- escrowed shares are returned to the owner.

Allowed next statuses:

- none

## Timestamp Semantics

Each request stores:

- `createdAt` for queue-entry time;
- `updatedAt` for the latest lifecycle transition;
- `fundedAt` for the first transition into `Funded`;
- `claimedAt` for the transition into `Claimed`.

## Operational Meaning

`Pending -> Processing`:

- orchestrator accepted responsibility for funding.

`Processing -> Funded`:

- enough home-side liquidity has been recognized and reserved.

`Funded -> Claimed`:

- user completed the payout step.
