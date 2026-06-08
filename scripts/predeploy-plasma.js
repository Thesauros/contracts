#!/usr/bin/env node

require("dotenv").config();

const required = ["DEPLOYER_PRIVATE_KEY", "TREASURY_ADDRESS", "PLASMA_RPC_URL"];
const optional = [
  "VERIFY_CONTRACTS",
  "PLASMASCAN_API_KEY",
  "TIMELOCK_DELAY",
  "WITHDRAW_FEE_PERCENT",
];

let hasError = false;

function report(name, ok, message) {
  const status = ok ? "OK" : "MISSING";
  console.log(`${status.padEnd(7)} ${name}${message ? ` - ${message}` : ""}`);
  if (!ok) hasError = true;
}

console.log("Plasma predeploy check\n");

for (const name of required) {
  const value = process.env[name];
  report(name, Boolean(value), "required for deployment");
}

for (const name of optional) {
  const value = process.env[name];
  const message = value ? "set" : "optional";
  console.log(`${"INFO".padEnd(7)} ${name} - ${message}`);
}

const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
if (privateKey) {
  const valid = /^0x[a-fA-F0-9]{64}$/.test(privateKey);
  report(
    "DEPLOYER_PRIVATE_KEY format",
    valid,
    valid ? "looks valid" : "must be 0x-prefixed 32-byte hex"
  );
}

const treasury = process.env.TREASURY_ADDRESS;
if (treasury) {
  const valid = /^0x[a-fA-F0-9]{40}$/.test(treasury);
  report(
    "TREASURY_ADDRESS format",
    valid,
    valid ? "looks valid" : "must be a 20-byte hex address"
  );
}

const withdrawFee = process.env.WITHDRAW_FEE_PERCENT;
if (withdrawFee) {
  const parsed = BigInt(withdrawFee);
  const max = 5n * 10n ** 16n; // 0.05e18
  report(
    "WITHDRAW_FEE_PERCENT range",
    parsed <= max,
    parsed <= max ? "within 5% max" : "exceeds 5% max"
  );
}

const timelockDelay = process.env.TIMELOCK_DELAY;
if (timelockDelay) {
  const parsed = Number(timelockDelay);
  const valid = Number.isInteger(parsed) && parsed >= 1800 && parsed <= 2592000;
  report(
    "TIMELOCK_DELAY range",
    valid,
    valid ? "within expected range" : "must be 1800..2592000 seconds"
  );
}

console.log("\nDeployment script also requires:");
console.log("- funded deployer wallet on Plasma for gas");
console.log("- treasury address configured for withdraw fees");

console.log("\nPost-deploy initialization requires:");
console.log("- at least 1 USDT0 on deployer for setupVault()");

if (hasError) {
  console.error("\nPredeploy check failed.");
  process.exit(1);
}

console.log("\nPredeploy check passed.");
