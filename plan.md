# Cosmos EVM v0.3.0 Integration Plan for Vector Blockchain

## Overview
Integrating Cosmos EVM v0.3.0 into Vector blockchain based on the official migration guide.
Vector is built with Ignite v0.33+ using Cosmos SDK v0.53.x and dependency injection patterns.

## ✅ Completed Tasks
- [x] Analyzed current Vector app structure
- [x] Reviewed Cosmos EVM v0.3.0 migration guide
- [x] Created integration plan
- [x] **Phase 1: Dependencies**
  - [x] Add `github.com/cosmos/evm v0.3.0`
  - [x] Add `github.com/ethereum/go-ethereum v1.15.11`
  - [x] Add replace directive for cosmos-patched Geth
  - [x] Run `go mod tidy`
- [x] **Phase 2: Core Integration**
  - [x] Add EVM module imports (corrected to use x/vm instead of x/evm)
  - [x] Replace IBC transfer imports with EVM fork
  - [x] Add ante handler and server flag imports
  - [x] Add EVM keepers to App struct
  - [x] Add PreciseBank keeper
  - [x] Add FeeMarket keeper
  - [x] Add ERC20 keeper
  - [x] Mount EVM store keys (KV and transient)
  - [x] Initialize FeeMarket keeper (first)
  - [x] Initialize PreciseBank keeper
  - [x] Initialize EVM keeper (fixed constructor signature)
  - [x] Initialize ERC20 keeper
  - [x] Update TransferKeeper with ERC20 integration
- [x] **Phase 3: IBC & Middleware**
  - [x] Setup IBC-v2 routing
  - [x] Create IBC transfer stack with ERC20 middleware
  - [x] Update IBC router configuration
  - [x] Fix IBC transfer keeper conflicts
- [x] **Phase 4: Module Management**
  - [x] Add EVM modules to module manager
  - [x] Set BeginBlocker order (feemarket → evm → erc20)
  - [x] Set EndBlocker order
  - [x] Add EVM modules to module manager
- [x] **Phase 5: Handlers**
  - [x] Configure chainante.HandlerOptions
  - [x] Set dynamic fee checker
  - [x] Set EVM-specific options
  - [x] Setup ante handlers
- [x] **🎉 SUCCESSFUL BUILD** - Vector blockchain compiles with EVM integration!

## 🔄 In Progress Tasks
- [ ] Step 8: Add CLI flags and test functionality

## 📋 Pending Tasks

### Phase 6: CLI & Configuration
- [ ] Step 8: Add CLI flags
  - [ ] Add --evm.chain-id flag to root.go
  - [ ] Add --evm.tracer flag
  - [ ] Add --evm.max-tx-gas-wanted flag
  - [ ] Bridge flags to app options

### Phase 7: Configuration & Genesis
- [ ] Step 9: Update genesis configuration
  - [ ] Add EVM module genesis defaults
  - [ ] Configure token pairs if needed
  - [ ] Set power reduction for 18 decimals

- [ ] Step 10: Security & Blocked Addresses
  - [ ] Add precompile addresses to blocked addresses
  - [ ] Update BlockedAddresses() function

### Phase 8: Testing & Validation
- [ ] Step 11: Basic functionality test
  - [x] Run `go build ./cmd/vectord` ✅
  - [ ] Test chain initialization
  - [ ] Validate EVM functionality

- [ ] Step 12: Integration testing
  - [ ] Start local devnet
  - [ ] Deploy test ERC-20 contract
  - [ ] Test IBC-v2 token transfers
  - [ ] Validate fee market functionality

## 🎯 Success Criteria
- [x] Chain compiles without errors ✅
- [ ] EVM transactions work (contract deployment/execution)
- [ ] IBC-v2 ERC-20 token transfers functional
- [ ] Dynamic fee market (EIP-1559) operational
- [ ] PreciseBank handles decimal conversions properly

## 📝 Key Files Modified
- [x] `/go.mod` - Dependencies ✅
- [x] `/app/app.go` - Core integration (keepers initialized) ✅
- [x] `/app/ibc.go` - IBC transfer keeper updated to EVM fork ✅
- [ ] `/cmd/vectord/root.go` - CLI flags
- [ ] `/app/app_config.go` - Module configuration (if needed)

## 🔍 Important Notes
- Cosmos EVM v0.3.0 shipped July 16, 2025
- Separate chain-IDs: Cosmos chain-id vs EVM chain-id
- EIP-1559 dynamic fees enabled by default
- x/precisebank mandatory for non-18-decimal chains
- Permissionless x/erc20 bridging
- x/revenue module removed in v0.3.0

## 🚨 Breaking Changes from v0.2.0
- SDK bump to v0.53.x
- IBC-Go v10
- Geth v1.15
- New IBC-v2 "erc20:" prefix
- Removed x/revenue module
- Removed implicit authz precompile

## 🎮 EVM Chain Configuration
- **Cosmos Chain ID**: `vector_6666-1` (example)
- **EVM Chain ID**: `6666` (configurable via CLI)
- **Base Denomination**: `stake` (current)
- **Decimals**: 6 (current) - PreciseBank handles 18-decimal conversion

## 📊 Current Status
- ✅ **MAJOR MILESTONE: Successful compilation!**
- ✅ EVM keepers successfully initialized
- ✅ Correct package structure identified (x/vm not x/evm)
- ✅ Constructor signatures fixed
- ✅ Ante handlers configured
- ✅ IBC-v2 routing with ERC20 middleware setup
- ✅ Module management and ordering configured
- 🔄 Ready for CLI flags and functionality testing

---

Last Updated: July 31, 2025
Status: **SUCCESS - Core Integration Complete!** 🎉
Next: CLI flags and functionality testing