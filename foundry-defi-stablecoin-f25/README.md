# Decentralized Stablecoin (DSC)

This project implements a decentralized, crypto-backed stablecoin (DSC) using the Foundry framework. The stablecoin is designed to maintain a 1:1 peg to the US Dollar.

## Core Concepts

1.  **Relative Stability**: The stablecoin is pegged to $1.00 USD. This is achieved by using Chainlink Price Feeds to get real-time price information for collateral assets.
2.  **Algorithmic Stability Mechanism**: The system is algorithmic and decentralized. Users can only mint new stablecoins when they provide a sufficient amount of collateral.
3.  **Exogenous Collateral**: The stablecoin is backed by other cryptocurrencies. The accepted collateral types are:
    *   Wrapped Ether (wETH)
    *   Wrapped Bitcoin (wBTC)

## Testing with Foundry

This project uses Foundry for smart contract development and testing.

*   **Stateless Fuzzing**: `forge test` is used for fuzz testing, which involves calling functions with random data to check for vulnerabilities.
*   **Stateful Fuzzing**: Invariant tests are used to check that specific properties of the smart contracts hold true across a sequence of random function calls.

## Project Structure

This project uses the following tools from the Foundry toolkit:

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
