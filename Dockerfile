FROM golang:1.23-alpine AS go-builder

SHELL ["/bin/sh", "-ecuxo", "pipefail"]

RUN apk add --no-cache ca-certificates build-base git

WORKDIR /code

ADD go.mod go.sum ./
RUN set -eux; \
    export ARCH=$(uname -m); \
    WASM_VERSION=$(go list -m all | grep github.com/CosmWasm/wasmvm || true); \
    if [ ! -z "${WASM_VERSION}" ]; then \
      WASMVM_REPO=$(echo $WASM_VERSION | awk '{print $1}' | sed 's/\/v[0-9]\+$//');\
      WASMVM_VERS=$(echo $WASM_VERSION | awk '{print $2}');\
      wget -O /lib/libwasmvm_muslc.$(uname -m).a https://${WASMVM_REPO}/releases/download/${WASMVM_VERS}/libwasmvm_muslc.$(uname -m).a;\
    fi; \
    go mod download;


# Copy over code
COPY . /code

# force it to use static lib (from above) not standard libgo_cosmwasm.so file
# then log output of file /code/bin/vectord
# then ensure static linking
RUN LEDGER_ENABLED=false BUILD_TAGS=muslc LINK_STATICALLY=true make build \
  && file /code/build/vectord \
  && echo "Ensuring binary is statically linked ..." \
  && (file /code/build/vectord | grep "statically linked")

# --------------------------------------------------------
FROM alpine:3.16

# Install dependencies used for Starship
RUN apk add --no-cache curl make bash jq sed

#add user vector
RUN addgroup vector && adduser -S -h /home/vector -s /bin/bash -G vector vector

# Switch to user vector
USER vector
WORKDIR /home/vector

COPY --from=go-builder --chown=vector:vector /code/build/vectord /home/vector/bin/vectord

# rest server, tendermint p2p, tendermint rpc
EXPOSE 1317 26656 26657

CMD ["/home/vector/bin/vectord", "version"]
