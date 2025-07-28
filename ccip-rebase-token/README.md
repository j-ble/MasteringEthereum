# CCIP-Rebase Token

Welcome to the CCIP-Rebase Token project! This protocol is designed to be a cross-chain, yield-bearing token. Users can deposit assets into a secure vault and receive a special "rebase token" in return. This token represents their share of the vault, and its balance automatically increases over time, generating a passive yield for the holder.

The core of this project combines the power of yield-generating assets with a unique incentive model to reward early adopters, all built to function seamlessly across multiple blockchains using Chainlink's Cross-Chain Interoperability Protocol (CCIP).

## How It Works

The protocol is built on a few core concepts that work together to create a dynamic and rewarding experience for users.

### 1. The Vault & Deposits
It all starts with the **Vault**. This is a smart contract where users deposit their underlying assets (e.g., ETH, USDC). In exchange for their deposit, the protocol mints a corresponding amount of the **Rebase Token** to the user. This token acts as a receipt and a representation of their share in the vault.

### 2. The Rebase Token: Your Dynamic Balance
Unlike a standard ERC20 token where your balance only changes when you send or receive tokens, our Rebase Token has a dynamic `balanceOf()` function.

- **Linearly Increasing Balance**: Your token balance grows predictably and linearly over time. This means that simply by holding the token, you are earning a yield.
- **Efficient Rebase Mechanism**: To save on gas fees and improve efficiency, the "accrued" interest is calculated and minted to your wallet **whenever you perform an action** with your tokens (such as `mint`, `burn`, `transfer`, or `bridge`). This is a "lazy rebase" approach that provides the same benefit without the high cost of a global rebase.

### 3. Interest Rate Model: Rewarding Early Adopters
The protocol features a unique interest rate mechanism designed to encourage early participation and long-term holding.

- **Individual Locked-In Rates**: When a user deposits into the vault, their deposit is assigned the **current global interest rate** of the protocol. This rate is then **locked in** for that specific deposit, providing a predictable yield.
- **Decreasing Global Rate**: The global interest rate of the protocol is designed to **only ever decrease** over time. This creates a powerful incentive for early adopters, as they can lock in higher rates that will be unavailable to later users. This mechanism aims to drive initial token adoption and reward the first wave of supporters.

## Key Features
- ✅ **Vault-Based Deposits:** Securely deposit assets to receive yield-bearing rebase tokens.
- ✅ **Dynamic Balances:** Receive a token whose balance increases linearly over time, representing your earned yield.
- ✅ **Efficient Rebase Mechanism:** Balance updates are efficiently calculated and minted during user actions (like transfers or bridging), saving gas compared to global rebase models.
- ✅ **Locked-In Interest Rates:** Each deposit locks in the protocol's global interest rate at that moment, ensuring a predictable yield for that specific deposit.
- ✅ **Early Adopter Incentives:** The global interest rate is designed to only decrease over time, rewarding early participants with higher potential yields.
- ✅ **Cross-Chain Native:** Built with CCIP in mind to allow seamless bridging and interaction across multiple blockchains.

---

## Getting Started

*(Instructions on how to set up the development environment, install dependencies, and run the project will be added here.)*

### Prerequisites

### Installation
1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd ccip-rebase-token
    ```

2.  **Install dependencies:**
    Foundry manages dependencies as git submodules. Install them using `forge`:
    ```bash
    forge install
    ```

3.  **Run tests:**
    ```bash
    forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage
    ```
    This will generate a `lcov.info` file in the `lcov` folder. This is to help your ai with code coverage.