package app

import (
	"fmt"
	"io"
	"sort"

	evidencekeeper "cosmossdk.io/x/evidence/keeper"

	clienthelpers "cosmossdk.io/client/v2/helpers"
	"cosmossdk.io/depinject"
	"cosmossdk.io/log"
	storetypes "cosmossdk.io/store/types"
	circuitkeeper "cosmossdk.io/x/circuit/keeper"
	upgradekeeper "cosmossdk.io/x/upgrade/keeper"
	authante "github.com/cosmos/cosmos-sdk/x/auth/ante"
	"github.com/cosmos/cosmos-sdk/x/gov"
	govclient "github.com/cosmos/cosmos-sdk/x/gov/client"
	paramsclient "github.com/cosmos/cosmos-sdk/x/params/client"

	evmante "github.com/cosmos/evm/ante"
	cosmosevmante "github.com/cosmos/evm/ante/evm"
	cosmosevmtypes "github.com/cosmos/evm/types"
	cosmosevmutils "github.com/cosmos/evm/utils"
	corevm "github.com/ethereum/go-ethereum/core/vm"

	abci "github.com/cometbft/cometbft/abci/types"
	dbm "github.com/cosmos/cosmos-db"
	"github.com/cosmos/cosmos-sdk/baseapp"
	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	"github.com/cosmos/cosmos-sdk/runtime"
	"github.com/cosmos/cosmos-sdk/server"
	"github.com/cosmos/cosmos-sdk/server/api"
	"github.com/cosmos/cosmos-sdk/server/config"
	servertypes "github.com/cosmos/cosmos-sdk/server/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/module"
	"github.com/cosmos/cosmos-sdk/x/auth"

	authkeeper "github.com/cosmos/cosmos-sdk/x/auth/keeper"
	authsims "github.com/cosmos/cosmos-sdk/x/auth/simulation"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"
	authzkeeper "github.com/cosmos/cosmos-sdk/x/authz/keeper"
	bankkeeper "github.com/cosmos/cosmos-sdk/x/bank/keeper"
	consensuskeeper "github.com/cosmos/cosmos-sdk/x/consensus/keeper"
	distrkeeper "github.com/cosmos/cosmos-sdk/x/distribution/keeper"
	"github.com/cosmos/cosmos-sdk/x/genutil"
	genutiltypes "github.com/cosmos/cosmos-sdk/x/genutil/types"
	govkeeper "github.com/cosmos/cosmos-sdk/x/gov/keeper"
	govtypes "github.com/cosmos/cosmos-sdk/x/gov/types"
	mintkeeper "github.com/cosmos/cosmos-sdk/x/mint/keeper"
	paramskeeper "github.com/cosmos/cosmos-sdk/x/params/keeper"
	paramstypes "github.com/cosmos/cosmos-sdk/x/params/types"
	slashingkeeper "github.com/cosmos/cosmos-sdk/x/slashing/keeper"
	stakingkeeper "github.com/cosmos/cosmos-sdk/x/staking/keeper"
	icacontrollerkeeper "github.com/cosmos/ibc-go/v10/modules/apps/27-interchain-accounts/controller/keeper"
	icahostkeeper "github.com/cosmos/ibc-go/v10/modules/apps/27-interchain-accounts/host/keeper"
	porttypes "github.com/cosmos/ibc-go/v10/modules/core/05-port/types"
	ibckeeper "github.com/cosmos/ibc-go/v10/modules/core/keeper"
	"github.com/spf13/cast"

	common "github.com/ethereum/go-ethereum/common"

	// EVM imports (corrected paths for v0.3.0)
	"github.com/cosmos/evm/x/erc20"
	erc20keeper "github.com/cosmos/evm/x/erc20/keeper"
	feemarketkeeper "github.com/cosmos/evm/x/feemarket/keeper"
	precisebankkeeper "github.com/cosmos/evm/x/precisebank/keeper"
	evmkeeper "github.com/cosmos/evm/x/vm/keeper"
	evmtypes "github.com/cosmos/evm/x/vm/types"

	// Replace IBC transfer with EVM fork
	transfer "github.com/cosmos/evm/x/ibc/transfer"
	ibctransferkeeper "github.com/cosmos/evm/x/ibc/transfer/keeper"

	// EVM server flags and ante (corrected paths)
	evmserver "github.com/cosmos/evm/server"
	srvflags "github.com/cosmos/evm/server/flags"

	"vector/docs"
	vectormodulekeeper "vector/x/vector/keeper"
)

const (
	// Name is the name of the application.
	Name = "vector"
	// AccountAddressPrefix is the prefix for account addresses.
	AccountAddressPrefix = "vector"
	// ChainCoinType is the coin type of the chain.
	ChainCoinType = 60 // Changed from 118 to 60 for EVM compatibility (Ethereum standard)
)

const (
	// ContractMemoryLimit is the memory limit of each contract execution (in MiB)
	// constant value so all nodes run with the same limit.
	ContractMemoryLimit = uint32(32)
)

// We pull these out so we can set them with LDFLAGS in the Makefile
var (
	NodeDir = ".vector"
	// DefaultNodeHome default home directories for the application daemon
	DefaultNodeHome string
)

var (
	_ runtime.AppI            = (*App)(nil)
	_ servertypes.Application = (*App)(nil)
	_ evmserver.Application   = (*App)(nil)
)

// App extends an ABCI application, but with most of its parameters exported.
// They are exported for convenience in creating helper functions, as object
// capabilities aren't needed for testing.
type App struct {
	*runtime.App
	legacyAmino *codec.LegacyAmino
	appCodec    codec.Codec
	clientCtx   client.Context

	txConfig          client.TxConfig
	interfaceRegistry codectypes.InterfaceRegistry

	// keepers
	// only keepers required by the app are exposed
	// the list of all modules is available in the app_config

	AuthKeeper            authkeeper.AccountKeeper
	BankKeeper            bankkeeper.Keeper
	StakingKeeper         *stakingkeeper.Keeper
	SlashingKeeper        slashingkeeper.Keeper
	MintKeeper            mintkeeper.Keeper
	DistrKeeper           distrkeeper.Keeper
	GovKeeper             *govkeeper.Keeper
	UpgradeKeeper         *upgradekeeper.Keeper
	AuthzKeeper           authzkeeper.Keeper
	EvidenceKeeper        evidencekeeper.Keeper
	ConsensusParamsKeeper consensuskeeper.Keeper
	CircuitBreakerKeeper  circuitkeeper.Keeper
	ParamsKeeper          paramskeeper.Keeper

	// ibc keepers
	IBCKeeper           *ibckeeper.Keeper
	ICAControllerKeeper icacontrollerkeeper.Keeper
	ICAHostKeeper       icahostkeeper.Keeper
	TransferKeeper      ibctransferkeeper.Keeper

	// EVM keepers
	EVMKeeper         *evmkeeper.Keeper
	FeeMarketKeeper   feemarketkeeper.Keeper
	Erc20Keeper       erc20keeper.Keeper
	PreciseBankKeeper precisebankkeeper.Keeper

	VectorKeeper vectormodulekeeper.Keeper
	// this line is used by starport scaffolding # stargate/app/keeperDeclaration

	// EVM pending transaction listeners
	pendingTxListeners []evmante.PendingTxListener

	// simulation manager
	sm *module.SimulationManager
}

func init() {

	sdk.DefaultBondDenom = "stake"

	var err error
	clienthelpers.EnvPrefix = Name
	DefaultNodeHome, err = clienthelpers.GetNodeHomeDirectory("." + Name)
	if err != nil {
		panic(err)
	}
}

// getGovProposalHandlers return the chain proposal handlers.
func getGovProposalHandlers() []govclient.ProposalHandler {
	var govProposalHandlers []govclient.ProposalHandler
	// this line is used by starport scaffolding # stargate/app/govProposalHandlers

	govProposalHandlers = append(
		govProposalHandlers,
		paramsclient.ProposalHandler,
		// this line is used by starport scaffolding # stargate/app/govProposalHandler
	)

	return govProposalHandlers
}

func AppConfig() depinject.Config {
	return depinject.Configs(
		moduleConfig(),
		// will be used inside runtime.ProvideInterfaceRegistry
		depinject.Provide(ProvideMsgEthereumTxCustomGetSigner),
		// Loads the ao config from a YAML file.
		// appconfig.LoadYAML(AppConfigYAML),
		depinject.Supply(
			// supply custom module basics
			map[string]module.AppModuleBasic{
				genutiltypes.ModuleName: genutil.NewAppModuleBasic(genutiltypes.DefaultMessageValidator),
				govtypes.ModuleName:     gov.NewAppModuleBasic(getGovProposalHandlers()),
				// this line is used by starport scaffolding # stargate/appConfig/moduleBasic
			},
		),
	)
}

// NewTxConfig initializes a new TxConfig, equivalent to the one used by [App].
func NewTxConfig() client.TxConfig {
	var txConfig client.TxConfig

	appConfig := depinject.Configs(
		AppConfig(),
		depinject.Supply(
			log.NewNopLogger(),
		),
	)

	if err := depinject.Inject(appConfig,
		&txConfig,
	); err != nil {
		panic(err)
	}

	return txConfig
}

// New returns a reference to an initialized App.
func New(
	logger log.Logger,
	db dbm.DB,
	traceStore io.Writer,
	loadLatest bool,
	appOpts servertypes.AppOptions,
	baseAppOptions ...func(*baseapp.BaseApp),
) (*App, error) {
	var (
		app        = &App{}
		appBuilder *runtime.AppBuilder

		// merge the AppConfig and other configuration in one config
		appConfig = depinject.Configs(
			AppConfig(),
			depinject.Supply(
				appOpts, // supply app options
				app.GetIBCKeeper,
				app.GetEvmKeeper,
				app.GetFeemarketKeeper,
				logger, // supply logger
				// here alternative options can be supplied to the DI container.
				// those options can be used f.e to override the default behavior of some modules.
				// for instance supplying a custom address codec for not using bech32 addresses.
				// read the depinject documentation and depinject module wiring for more information
				// on available options and how to use them.
			),
		)
	)

	if err := depinject.Inject(appConfig,
		&appBuilder,
		&app.appCodec,
		&app.legacyAmino,
		&app.txConfig,
		&app.interfaceRegistry,
		&app.AuthKeeper,
		&app.BankKeeper,
		&app.StakingKeeper,
		&app.SlashingKeeper,
		&app.MintKeeper,
		&app.DistrKeeper,
		&app.GovKeeper,
		&app.UpgradeKeeper,
		&app.ParamsKeeper,
		&app.AuthzKeeper,
		&app.EvidenceKeeper,
		// &app.FeeGrantKeeper,
		// &app.GroupKeeper,
		&app.ConsensusParamsKeeper,
		&app.CircuitBreakerKeeper,
		&app.VectorKeeper,
		// this line is used by starport scaffolding # stargate/app/keeperDefinition
	); err != nil {
		panic(err)
	}

	if app.txConfig == nil || app.txConfig.TxDecoder() == nil {
		panic("TxConfig/TxDecoder is nil – ensure ProvideTxConfig and dependencies are provided")
	}

	updatedBaseAppOptions := append(
		[]func(*baseapp.BaseApp){
			func(bApp *baseapp.BaseApp) {
				bApp.SetTxDecoder(app.txConfig.TxDecoder())
			},
		},
		baseAppOptions...)

	app.App = appBuilder.Build(db, traceStore, updatedBaseAppOptions...)

	RegisterEVMCodec(app.legacyAmino, app.interfaceRegistry)
	app.SetTxEncoder(app.txConfig.TxEncoder())

	if err := app.setupEVM(); err != nil {
		panic(err)
	}

	// register legacy modules
	if err := app.registerIBCModules(appOpts); err != nil {
		panic(err)
	}

	// Setup IBC-v2 routing with ERC20 middleware
	var transferStack porttypes.IBCModule
	transferStack = transfer.NewIBCModule(app.TransferKeeper)
	transferStack = erc20.NewIBCMiddleware(app.Erc20Keeper, transferStack)

	// // Update IBC router
	// ibcRouter := porttypes.NewRouter().
	// 	AddRoute(ibctransfertypes.ModuleName, transferStack)
	// app.IBCKeeper.SetRouter(ibcRouter)

	/****  Module Options ****/

	// create the simulation manager and define the order of the modules for deterministic simulations
	overrideModules := map[string]module.AppModuleSimulation{
		authtypes.ModuleName: auth.NewAppModule(app.appCodec, app.AuthKeeper, authsims.RandomGenesisAccounts, nil),
	}
	app.sm = module.NewSimulationManagerFromAppModules(app.ModuleManager.Modules, overrideModules)

	app.sm.RegisterStoreDecoders()

	// A custom InitChainer sets if extra pre-init-genesis logic is required.
	// This is necessary for manually registered modules that do not support app wiring.
	// Manually set the module version map as shown below.
	// The upgrade module will automatically handle de-duplication of the module version map.
	app.SetInitChainer(func(ctx sdk.Context, req *abci.RequestInitChain) (*abci.ResponseInitChain, error) {
		if err := app.UpgradeKeeper.SetModuleVersionMap(ctx, app.ModuleManager.GetVersionMap()); err != nil {
			return nil, err
		}
		return app.App.InitChainer(ctx, req)
	})

	maxGasWanted := cast.ToUint64(appOpts.Get(srvflags.EVMMaxTxGasWanted))

	app.setAnteHandler(app.txConfig, maxGasWanted)

	if err := app.Load(loadLatest); err != nil {
		panic(err)
	}

	return app, nil
}

// GetSubspace returns a param subspace for a given module name.
func (app *App) GetSubspace(moduleName string) paramstypes.Subspace {
	subspace, _ := app.ParamsKeeper.GetSubspace(moduleName)
	return subspace
}

// LegacyAmino returns App's amino codec.
func (app *App) LegacyAmino() *codec.LegacyAmino {
	return app.legacyAmino
}

// AppCodec returns App's app codec.
func (app *App) AppCodec() codec.Codec {
	return app.appCodec
}

// InterfaceRegistry returns App's InterfaceRegistry.
func (app *App) InterfaceRegistry() codectypes.InterfaceRegistry {
	return app.interfaceRegistry
}

// GetMemKey returns the MemoryStoreKey for the provided store key.
func (app *App) GetMemKey(storeKey string) *storetypes.MemoryStoreKey {
	key, ok := app.UnsafeFindStoreKey(storeKey).(*storetypes.MemoryStoreKey)
	if !ok {
		return nil
	}

	return key
}

func (app *App) GetTransientKey(storeKey string) *storetypes.TransientStoreKey {
	key, ok := app.UnsafeFindStoreKey(storeKey).(*storetypes.TransientStoreKey)
	if !ok {
		return nil
	}

	return key
}

// GetKey returns the KVStoreKey for the provided store key.
func (app *App) GetKey(storeKey string) *storetypes.KVStoreKey {
	kvStoreKey, ok := app.UnsafeFindStoreKey(storeKey).(*storetypes.KVStoreKey)
	if !ok {
		return nil
	}
	return kvStoreKey
}

// SimulationManager implements the SimulationApp interface
func (app *App) SimulationManager() *module.SimulationManager {
	return app.sm
}

// RegisterAPIRoutes registers all application module routes with the provided
// API server.
func (app *App) RegisterAPIRoutes(apiSvr *api.Server, apiConfig config.APIConfig) {
	app.App.RegisterAPIRoutes(apiSvr, apiConfig)
	// register swagger API in app.go so that other applications can override easily
	if err := server.RegisterSwaggerAPI(apiSvr.ClientCtx, apiSvr.Router, apiConfig.Swagger); err != nil {
		panic(err)
	}

	// register app's OpenAPI routes.
	docs.RegisterOpenAPIService(Name, apiSvr.Router)
}

// GetIBCKeeper returns the IBC keeper.
func (app *App) GetIBCKeeper() *ibckeeper.Keeper {
	return app.IBCKeeper
}

// GetEvmKeeper returns the Evm keeper.
func (app *App) GetEvmKeeper(_placeHolder int16) *evmkeeper.Keeper {
	return app.EVMKeeper
}

// GetFeemarketKeeper returns the Feemarket keeper.
func (app *App) GetFeemarketKeeper(_placeHolder int32) feemarketkeeper.Keeper {
	return app.FeeMarketKeeper
}

func (app *App) TxConfig() client.TxConfig {
	return app.txConfig
}

// GetMaccPerms returns a copy of the module account permissions
//
// NOTE: This is solely to be used for testing purposes.
func GetMaccPerms() map[string][]string {
	dup := make(map[string][]string)
	for _, perms := range moduleAccPerms {
		dup[perms.GetAccount()] = perms.GetPermissions()
	}

	return dup
}

// BlockedAddresses returns all the app's blocked account addresses.
//
// Note, this includes:
//   - module accounts
//   - Ethereum's native precompiled smart contracts
//   - Cosmos EVM' available static precompiled contracts
func BlockedAddresses() map[string]bool {
	blockedAddrs := make(map[string]bool)

	maccPerms := GetMaccPerms()
	accs := make([]string, 0, len(maccPerms))
	for acc := range maccPerms {
		accs = append(accs, acc)
	}
	sort.Strings(accs)

	for _, acc := range accs {
		blockedAddrs[authtypes.NewModuleAddress(acc).String()] = true
	}

	blockedPrecompilesHex := evmtypes.AvailableStaticPrecompiles
	for _, addr := range corevm.PrecompiledAddressesPrague {
		blockedPrecompilesHex = append(blockedPrecompilesHex, addr.Hex())
	}

	for _, precompile := range blockedPrecompilesHex {
		blockedAddrs[cosmosevmutils.Bech32StringFromHexAddress(precompile)] = true
	}

	return blockedAddrs
}

func (app *App) SetClientCtx(clientCtx client.Context) {
	app.clientCtx = clientCtx
}

// // DefaultGenesis returns a default genesis from the registered AppModuleBasic's.
// func (a *App) DefaultGenesis() map[string]json.RawMessage {
// 	genesis := a.App.DefaultGenesis()

// 	mintGenState := NewMintGenesisState()
// 	genesis[minttypes.ModuleName] = a.appCodec.MustMarshalJSON(mintGenState)

// 	evmGenState := NewEVMGenesisState()
// 	genesis[evmtypes.ModuleName] = a.appCodec.MustMarshalJSON(evmGenState)

// 	// NOTE: for the example chain implementation we are also adding a default token pair,
// 	// which is the base denomination of the chain (i.e. the Wevm contract)
// 	erc20GenState := NewErc20GenesisState()
// 	genesis[erc20types.ModuleName] = a.appCodec.MustMarshalJSON(erc20GenState)

//		return genesis
//	}

func (app *App) RegisterPendingTxListener(listener func(common.Hash)) {
	app.pendingTxListeners = append(app.pendingTxListeners, listener)
}

func (app *App) setAnteHandler(txConfig client.TxConfig, maxGasWanted uint64) {
	options := HandlerOptions{
		HandlerOptions: authante.HandlerOptions{
			ExtensionOptionChecker: cosmosevmtypes.HasDynamicFeeExtensionOption,
			// FeegrantKeeper:         app.FeeGrantKeeper,
			SignModeHandler: txConfig.SignModeHandler(),
			SigGasConsumer:  evmante.SigVerificationGasConsumer,
		},
		AccountKeeper: app.AuthKeeper,
		BankKeeper:    app.BankKeeper,
		IBCKeeper:     app.IBCKeeper,
		// TXCounterStoreService: runtime.NewKVStoreService(txCounterStoreKey),
		CircuitKeeper:   &app.CircuitBreakerKeeper,
		EVMKeeper:       app.EVMKeeper,
		FeeMarketKeeper: app.FeeMarketKeeper,
		Cdc:             app.appCodec,
		TxFeeChecker:    cosmosevmante.NewDynamicFeeChecker(app.FeeMarketKeeper),

		MaxTxGasWanted: maxGasWanted,
	}

	if err := options.Validate(); err != nil {
		panic(fmt.Errorf("failed to create AnteHandler: %w", err))
	}

	anteHandler := NewAnteHandler(options)

	// Set the AnteHandler for the app
	app.SetAnteHandler(anteHandler)
}

// kvStoreKeys returns all the kv store keys registered inside App.
func (app *App) kvStoreKeys() map[string]*storetypes.KVStoreKey {
	keys := make(map[string]*storetypes.KVStoreKey)

	for _, k := range app.GetStoreKeys() {
		if kv, ok := k.(*storetypes.KVStoreKey); ok {
			keys[kv.Name()] = kv
		}
	}

	return keys
}
