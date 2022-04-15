## Overview
This is the first project of the Web3 Builders Munich DAO. It allows early members to mint an OG NFT.

## Specification
The community has decided on the following specifications for the OG NFT:
- The owner of the smart contract should be a multisig contract
- All members in the tech team will be the initial members of the multisig contract
- Only members on the whitelist of the NFT contract should be able to mint an NFT
- The whitelist should be editable
- The NFT contract should be able to pause and allow the transfer of NFTs
- All NFTs share the same meta data
- Each NFT should have a unique ID

## Project overview
- hardhat.config.js: config file for hardhat which is a tool to deploy and test smart contracts
- .env.example: dummy file which stores environment variables -> rename to .env
- /contracts: Solidity code for multisig wallet and ERC721 (NFT) contract
- /test: tests which are run with hardhat to test the ERC721 contract (Note: the multisig wallet contract doesn't need any tests since it's a standard template without any changes)
- assets/: images/gifs for the NFTs
- pin_nft_assets.js: script to upload gifs to IPFS
- /frontend: React frontend code which allows members to mint their NFT
- package.json & yarn.lock: configuration files to keep track of installed node package manager (npm) packages (e.g. React, hardhat, etc.)

## How to run


## Contributors
