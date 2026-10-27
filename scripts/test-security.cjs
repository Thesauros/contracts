#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const compat = process.argv.includes('--compat');
const forge = process.env.SECURITY_FORGE || 'forge';
const env = { ...process.env, FOUNDRY_PROFILE: 'security' };
delete env.ETH_RPC_URL; delete env.FOUNDRY_ETH_RPC_URL; delete env.FOUNDRY_FORK_URL;
if (compat) env.FOUNDRY_TEST = 'test/mocking'; else delete env.FOUNDRY_TEST;
const args = ['test', '--offline', '--use', './scripts/solc-security.cjs', '--json'];
if (compat) args.push('--remappings', 'forge-std/=lib/forge-std/src/');
const result = spawnSync(forge, args, { cwd: root, env, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
if (result.error) throw result.error;
if (result.stderr) process.stderr.write(result.stderr);
const begin = result.stdout.indexOf('{');
if (begin < 0) { process.stderr.write(result.stdout); process.exit(result.status || 1); }
const data = JSON.parse(result.stdout.slice(begin));
const suites = Object.entries(data).map(([suite, value]) => ({
  suite, tests: Object.entries(value.test_results).map(([test, t]) => ({
    test, status: t.status, reason: t.reason,
    fuzz_runs: t.kind && t.kind.Fuzz ? t.kind.Fuzz.runs : undefined,
  })),
}));
const failed = suites.flatMap(s => s.tests).filter(t => t.status !== 'Success');
const output = {
  change: 'security-remediation-2026-10-27',
  mode: compat ? 'existing-local-mocking' : 'selected-security-regressions',
  compiler: require('solc').version(), evm: 'Foundry local Shanghai; no fork',
  dependency: '@openzeppelin/contracts@' + require('@openzeppelin/contracts/package.json').version,
  tests: suites.reduce((n, s) => n + s.tests.length, 0), failed: failed.length, suites,
};
const dir = path.join(root, 'changes/security-remediation-2026-10-27');
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(path.join(dir, compat ? 'evm-compatibility.json' : 'evm-security.json'), JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ mode: output.mode, tests: output.tests, failed: output.failed, failures: failed }));
process.exitCode = result.status || (failed.length ? 1 : 0);
