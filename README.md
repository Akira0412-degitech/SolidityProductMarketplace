# 🛒 Solidity Product Marketplace

A secure Ethereum smart contract for managing a decentralized product marketplace.  
Built with **Solidity** and **OpenZeppelin**, this contract supports:

- Product listings (by the owner)
- Ether-based product orders
- Delivery confirmation
- Product rating by buyers
- Protection from reentrancy attacks

---

## ⚙ Features

- 🧾 Add and restock products
- 💰 Place orders with Ether
- ✅ Confirm delivery to release payment
- ⭐ Rate products (1–5)
- 🔐 Reentrancy protection using OpenZeppelin

---

## 🛠 Tech Stack

- **Solidity** ^0.8.0
- [OpenZeppelin ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)
- Remix IDE for testing
- Optional: Hardhat/Truffle for local dev

---

## 🚀 Getting Started (with Remix)

1. Open [Remix](https://remix.ethereum.org)
2. Paste the contract into a new `.sol` file
3. Compile using version 0.8.0+
4. Deploy and interact:
   - Use `addProduct("Banana", 10, 10000000000000000)` to list a product (0.01 ETH)
   - Set **Value = 0.02** and use `createOrder(...)` to buy 2
   - Confirm and rate orders using respective functions

---

## 💡 Example Flow

```solidity
addProduct("Banana", 10, 10000000000000000);  // 0.01 ETH each
createOrder(seller, 1, 2);                    // Order 2 bananas
confirmOrder(1);                              // Confirm delivery
rateOrder(1, 5);                              // Rate the seller
