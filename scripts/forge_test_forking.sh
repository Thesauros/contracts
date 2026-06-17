#!/usr/bin/env bash
set -euo pipefail

# Forking tests are sensitive to environment and RPC/proxy configuration.
# This helper tries to reduce macOS/system proxy issues by unsetting common proxy vars.

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY

if [[ -z "${ARBITRUM_RPC_URL:-}" ]]; then
  echo "ARBITRUM_RPC_URL is not set. Export it to run forking tests."
  exit 1
fi

forge test --match-path 'test/forking/*'

