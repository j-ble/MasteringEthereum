# Mastering Ethereum Smart Contracts with Foundry

Welcome to the **MasteringEthereum** project — a hands-on learning repository for developing, testing, and deploying Ethereum smart contracts using [Foundry](https://book.getfoundry.sh/). This project follows examples and exercises inspired by the *Mastering Ethereum* book, adapted with modern development tools.

## 🛠️ Stack

- **[Foundry](https://github.com/foundry-rs/foundry)** – Blazing-fast toolkit for Ethereum development (written in Rust)
  - `forge` – Testing framework
  - `cast` – CLI for interacting with contracts
  - `anvil` – Local Ethereum node (alternative to Ganache/Hardhat)
  - `chisel` – Solidity REPL

## 📁 Directory Structure

```
.
├── contracts/       # Solidity smart contracts
├── script/          # Deployment scripts
├── src/             # Optional core contract logic (used in some Foundry setups)
├── test/            # Contract unit tests (Forge)
├── foundry.toml     # Foundry config file
```

## 🧪 Quick Start

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Clone the Repository

```bash
git clone https://github.com/j-ble/MasteringEthereum.git
cd MasteringEthereum
```

### 3. Build Contracts

```bash
forge build
```

### 4. Run Tests

```bash
forge test
```

### 5. Format Code

```bash
forge fmt
```

### 6. Launch Local Node

```bash
anvil
```

### 7. Deploy to a Network

Update your private key and RPC URL before running the script:

```bash
forge script script/Counter.s.sol:CounterScript \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

## ⛽ Gas Snapshots

Benchmark contract gas usage with:

```bash
forge snapshot
```

## 🧰 Using Cast

Use `cast` to interact with deployed contracts:

```bash
cast <subcommand>
```

Examples:

```bash
cast block-number --rpc-url <your_rpc_url>
cast call <contract_address> "functionName(uint256)" 123 --rpc-url <your_rpc_url>
```

## 📚 Reference Docs

- 🔗 [Foundry Book](https://book.getfoundry.sh/)
- 📘 [Mastering Ethereum](https://github.com/ethereumbook/ethereumbook)

## 👨‍💻 Author

Jacob Blemaster – [@j-ble](https://github.com/j-ble)  
Feel free to fork, star, and build on top of this repo as you follow along the *Mastering Ethereum* journey.

---

> “Winners and losers have the same goal. It’s the system that determines who gets there.” – Stay consistent. Stay building.
