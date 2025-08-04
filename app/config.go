package app

import (
	"errors"

	"cosmossdk.io/math"
	"github.com/cosmos/cosmos-sdk/codec"
	"github.com/cosmos/cosmos-sdk/codec/legacy"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/x/auth/migrations/legacytx"
	"github.com/cosmos/evm/crypto/ethsecp256k1"
	evmcodec "github.com/cosmos/evm/encoding/codec"
	"github.com/cosmos/evm/ethereum/eip712"
	evmtypes "github.com/cosmos/evm/x/vm/types"
)

var sealed = false

var coinInfo = evmtypes.EvmCoinInfo{
	Denom:         "atest",
	ExtendedDenom: "atest",
	DisplayDenom:  "TEST",
	Decimals:      evmtypes.EighteenDecimals, // Changed from SixDecimals to EighteenDecimals for EVM compatibility
}

func RegisterEVMCodec(legacyAmino *codec.LegacyAmino, interfaceRegistry codectypes.InterfaceRegistry) {
	legacyAmino.RegisterConcrete(&ethsecp256k1.PubKey{},
		ethsecp256k1.PubKeyName, nil)
	legacyAmino.RegisterConcrete(&ethsecp256k1.PrivKey{},
		ethsecp256k1.PrivKeyName, nil)
	legacy.Cdc = legacyAmino
	legacytx.RegressionTestingAminoCodec = legacyAmino

	evmcodec.RegisterInterfaces(interfaceRegistry)
}

func (app *App) setupEVM() error {
	if sealed {
		return errors.New("setupEVM called twice")
	}

	// chainID := app.ChainID()
	// from := strings.LastIndexByte(chainID, '_')
	// to := strings.LastIndexByte(chainID, '-')

	// evmChainID, err := strconv.ParseUint(chainID[from+1:to], 10, 64)
	// if err != nil {
	// 	return fmt.Errorf("can't parse evm chain id from %s: %w", chainID, err)
	// }

	eip712.SetEncodingConfig(app.legacyAmino, app.interfaceRegistry, 13388)

	// set the denom info for the chain
	if err := setBaseDenom(coinInfo); err != nil {
		return err
	}

	ethCfg := evmtypes.DefaultChainConfig(13388)
	if err := evmtypes.NewEVMConfigurator().
		WithChainConfig(ethCfg).
		WithEVMCoinInfo(coinInfo).
		Configure(); err != nil {
		return err
	}

	sealed = true

	return nil
}

// setBaseDenom registers the display denom and base denom and sets the
// base denom for the chain.
func setBaseDenom(ci evmtypes.EvmCoinInfo) error {
	if err := sdk.RegisterDenom(ci.DisplayDenom, math.LegacyOneDec()); err != nil {
		return err
	}

	// sdk.RegisterDenom will automatically overwrite the base denom when the
	// new setBaseDenom() are lower than the current base denom's units.
	return sdk.RegisterDenom(ci.Denom, math.LegacyNewDecWithPrec(1, int64(ci.Decimals)))
}
