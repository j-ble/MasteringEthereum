// etherum blockchain and it's ecosystem
// connect to the blockchain node, create wallet instances, and interact with smart contracts
const { ethers } = require("ethers");

// loads environment variables
// managing private keys and other sensitive data
const dotenv = require("dotenv");

// CCTP contract that burns and sends 
const tokenMessengerAbi = require("./abis/cctp/TokenMessenger.json");
// For a CCTP helper contract
const messageAbi = require("./abis/cctp/Message.json");
// USDC token contract itself (to call/approve)
const usdcAbi = require("./abis/Usdc.json");
// For the CCTP contract that receives messages and mints tokens
const messageTransmitterAbi = require("./abis/cctp/MessageTransmitter.json");

// dotenv configuration, which reads the .env file
dotenv.config();

/**
 * Main function that runs asynchronously since blockchain operations are async
 */
const main = async () => {
  // Providers is the connection to the blockchain node. Allows us the read data from the chain (e.g., get balances, read contract state).
  // Creating a JsonRpcProvider, which connects to a specific nodes via its RPC (Remote Protocol Procedure) URL.
  // Need a provider for each chain we are interacting with.
  const ethProvider = new ethers.providers.JsonRpcProvider(
    process.env.ETH_TESTNET_RPC
  );
  const baseProvider = new ethers.providers.JsonRpcProvider(
    process.env.BASE_TESTNET_RPC
  );

  // "Wallet" in ethers.js is an object that holds the private key and is connected to a provider.
  // We are creating wallet instances for both the source (Ethereum) and destination (BASE) chains.
  const ethWallet = new ethers.Wallet(process.env.ETH_PRIVATE_KEY, ethProvider); // Signs transactions on the Ethereum testnet.
  const baseWallet = new ethers.Wallet(
    process.env.BASE_PRIVATE_KEY,
    baseProvider // Signs that transactions on the BASE testnet.
  );

  /**
   * Testnet Contract Addresses
   * These are the hardcoded addresses of the deployed smart contracts we will interact with.
   * These addresses are specific to the testnet environment.
   */
  // Source Chain (Ethereum Sepolia)
  const ETH_TOKEN_MESSENGER_CONTRACT_ADDRESS =
    "0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5"; // The CCTP contract that burns USDC and emits the message.
  const USDC_ETH_CONTRACT_ADDRESS =
    "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"; // The USDC token contract on the Ethereum Sepolia.
  const ETH_MESSAGE_CONTRACT_ADDRESS =
    "0x80537e4e8bAb73D21096baa3a8c813b45CA0b7c9"; // A CCTP utility contract with helper functions like address formatting.
  const BASE_MESSAGE_TRANSMITTER_CONTRACT_ADDRESS =
    "0x7865fAfC2db2093669d92c0F33AeEF291086BEFD"; // The CCTP contract that receives the attested messages and mints USDC. 

  /**
   * Initialize contracts
   * We create "Contract" objects. A contract object combines an address, an ABI, and a wallet signer/provider.
   * This gives us the ability to call functions on the on-chain smart contract.
   */
  const ethTokenMessenger = new ethers.Contract(
    ETH_TOKEN_MESSENGER_CONTRACT_ADDRESS,
    tokenMessengerAbi,
    ethWallet
  );
  const usdcEth = new ethers.Contract(
    USDC_ETH_CONTRACT_ADDRESS,
    usdcAbi,
    ethWallet
  );
  const ethMessage = new ethers.Contract(
    ETH_MESSAGE_CONTRACT_ADDRESS,
    messageAbi,
    ethWallet
  );
  // Contract instance for the destination chian (BASE), signed by the 'baseWallet' instance.
  const baseMessageTransmitter = new ethers.Contract(
    BASE_MESSAGE_TRANSMITTER_CONTRACT_ADDRESS,
    messageTransmitterAbi,
    baseWallet
  );

  /**
   * Transaction Details
   */
  const mintRecipient = process.env.RECIPIENT_ADDRESS; // The final address that will receive the USDC on the destination chian (BASE).
  const BASE_DESTINATION_DOMAIN = 6; // Tells the protocol where the funds are going to be sent. 
  const amount = process.env.AMOUNT; // The amount of USDC to be transferred, in its smallest unit (e.g., 1,000,000 for 1 USDC, since it has 6 decimals).

  // Convert recipient address to bytes32
  // We call the helper function on the CCTP contract to perform this conversion.
  const destinationAddressInBytes32 = await ethMessage.addressToBytes32(
    mintRecipient
  );

  /**
   * Approve (Source Chain)
   * The standard ERC20 token interaction. Before withdrawaling tokens from our wallet, we must first grant permission.
   * We do this by calling the 'approve' function on the USDC token contract itself.
   * We are telling the USDC contract: "I grant the TokenMessenger contract to withdraw up to 'amount' of USDC from my balance."
   */
  const approveTx = await usdcEth.approve(
    ETH_TOKEN_MESSENGER_CONTRACT_ADDRESS,
    amount
  );
  // `approve` returns a transaction object immediately. We must wait for it to be mined and confirmed on the blockchain.
  await approveTx.wait();
  console.log("ApproveTxReceipt:", approveTx.hash);

  /**
   * Burn (Source Chain)
   * TokenMessenger has approval, we can call its 'depositFromBurn' function.
   * This function will:
   * 1. Pull the 'amount' of USDC from our wallet.
   * 2. "Burn" those tokens, removing them from the total supply on the Ethereum Sepolia.
   * 3. Emit a speceial event 'MessageSent' containing the details of the burn. This event is the "cross-chain message".
   */
  const burnTx = await ethTokenMessenger.depositForBurn(
    amount,
    BASE_DESTINATION_DOMAIN,
    destinationAddressInBytes32,
    USDC_ETH_CONTRACT_ADDRESS
  );
  // Wait for the burn transaction to be mined.
  await burnTx.wait();
  console.log("BurnTxReceipt:", burnTx.hash);

  /**
   * Retireve Message Bytes (Off-Chain)
   * The 'depositForBurn' function emits an event. We need to find this event in the transaction receipt to get the raw message data.
   * This raw data cointatins all the information needed to mint the tokens on the destination chain (BASE).
   */
  // Get the full receipt for our burn transaction.
  const receipt = await ethProvider.getTransactionReceipt(burnTx.hash);
  // An events unique identifier is the hash of its signature. We calculate the hash for the 'MessageSent(bytes)' event.  
  const eventTopic = ethers.utils.id("MessageSent(bytes)");
  // Search the transaction logs (events) for the one that matches our event's topic.
  const log = receipt.logs.find((l) => l.topics[0] === eventTopic);
  // The event's payload (the actual message) is stored in the 'log.data' field, ABI-encoded. We decode it to get the raw 'messageBytes'.
  const messageBytes = ethers.utils.defaultAbiCoder.decode(
    ["bytes"],
    log.data
  )[0];
  // We hash the message bytes. This has is a unique identifier for our specific cross-chain transfer.
  const messageHash = ethers.utils.keccak256(messageBytes);

  console.log("MessageBytes:", messageBytes);
  console.log("MessageHash:", messageHash);

  /**
   * Fetch Attestation Signature (Off-Chain)
   * The destination chain (BASE) needs to verify the burn came from the source chain (Ethereum Sepolia). It will not mint without this proof.
   * Circle runs an off-chain "Attestation Service" that watches for burn events. When it sees our events, it generates a cryptographic signature (an "attestation").
   */
  let attestationResponse = { status: "pending" };
  while (attestationResponse.status !== "complete") {
    // We send the 'messageHash' to Circle's API.
    const response = await fetch(
      `https://iris-api-sandbox.circle.com/attestations/${messageHash}`
    );
    attestationResponse = await response.json();
    // Wait for 2 seconds before tyring again to avoid rate limiting. 
    await new Promise((r) => setTimeout(r, 2000));
  }

  // Once the status is "complete", the repsonse will contain the signature.
  const attestationSignature = attestationResponse.attestation;
  console.log("Signature:", attestationSignature);

  /**
   * Receive Message (Destination Chain)
   * Now we have everything we need to complete the transfer on the destination chain (BASE).
   * 1. The original 'messageBytes' (what to do). 
   * 2. The 'attestationSignature' (proof that it's authorized).
   * We call the 'receiveMessage' function on the 'MessageTransmitter' contract on Base.
   */
  const receiveTx = await baseMessageTransmitter.receiveMessage(
    messageBytes, // The orignal message with all transfer details.
    attestationSignature // The signatire from Circle proving the message is valid.
  );
  // The 'MessageTransmitter' contract will:
  // 1. Verify the attestation signature against the message bytes.
  // 2. If valid, it will decode the message to get the recipient and amount.
  // 2. It will then Mint new USDC tokens on the Base network and send them to the recipient.
  await receiveTx.wait();
  console.log("ReceiveTxReceipt:", receiveTx.hash);
};

// Run the main function and catch any potential errors during the process. 
main().catch(console.error);
