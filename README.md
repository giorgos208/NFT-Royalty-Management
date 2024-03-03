# NFT Royalty Management System

Welcome to `NFT Royalty Management System`, a repository for a smart contract based royalty management system that is being compiled and deployed with Truffle.

## Repository Structure

- `contracts/`: This directory contains the Solidity smart contracts for the project.
- `migrations/`: This directory holds migration scripts for deploying the contract to the blockchain.
- `truffle-config.js`: The Truffle configuration file is where you define network configurations, compiler settings, and other project-related settings.

## Quick Start

To use this repository:

1. **Clone the repository**:

   ```shell
   git clone https://github.com/giorgos208/NFT-Royalty-Management.git
   ```

2. **Install dependencies**:

   ```shell
   npm install
   ```

3. **Compile contract**:

   ```shell
   truffle compile
   ```

4. **Deploy contract (Not necessary in this step)**:

   ```shell
   truffle migrate --network sepolia
   ```

Please ensure you have Truffle installed globally on your machine, and have filled a .env file with these information:
 ```shell
 MNEMONIC = 
 INFURA_API_KEY = 
 ETHERSCAN_API_KEY = 
   ```

## Configuration

Make sure to update the `truffle-config.js` with your preferred network settings and other configurations before attempting to deploy your contracts.

## Support

For any additional help or information on using this repository, please refer to the official Truffle documentation.
