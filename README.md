# Generated With [Spawn](https://github.com/rollchains/spawn)

## Module Scaffolding

- `spawn module new <name>` _Generates a Cosmos module template_

## Content Generation

- `make proto-gen` _Generates go code from proto files, stubs interfaces_

## Testnet

- `make testnet` _IBC testnet from chain <-> local cosmos-hub_
- `make sh-testnet` _Single node, no IBC. quick iteration_
- `local-ic chains` _See available testnets from the chains/ directory_
- `local-ic start <name>` _Starts a local chain with the given name_

## Local Images

- `make install` _Builds the chain's binary_
- `make local-image` _Builds the chain's docker image_

## Testing

- `go test ./... -v` _Unit test_
- `make ictest-*` _E2E testing_

## Webapp Template

Generate the template base with spawn. Requires [npm](https://nodejs.org/en/download/package-manager) and [yarn](https://classic.yarnpkg.com/lang/en/docs/install) to be installed.

- `make generate-webapp` _[Cosmology Webapp Template](https://github.com/cosmology-tech/create-cosmos-app)_

Start the testnet with `make testnet`, and open the webapp `cd ./web && yarn dev`

## Scripts suite

### Run a localnode from scratch

```bash
CLEAN=true HOME_DIR=mytestnet ./scripts/test_node.sh
```
