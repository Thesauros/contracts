# CHANGELOG

## [1.1.0] - 2025-09-12

### EthenaProvider Optimization and Architecture Unification

### Added
- **Unified validation method `_validateAndGetContracts()`**: Added comprehensive validation method that returns all necessary contracts and data in a single call, eliminating code duplication across 7 methods
- **ProviderManager integration**: Implemented ProviderManager pattern for dynamic contract resolution and asset validation