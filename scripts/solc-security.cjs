#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const solc = require('solc');
if (!solc.version().startsWith('0.8.23+')) throw new Error('Install exact solc@0.8.23 for security tests');
if (process.argv.includes('--version')) {
  process.stdout.write('solc, the solidity compiler commandline interface\nVersion: ' + solc.version() + '\n');
} else if (process.argv.includes('--standard-json')) {
  process.stdout.write(solc.compile(fs.readFileSync(0, 'utf8')));
} else throw new Error('Only --version and --standard-json are supported');
