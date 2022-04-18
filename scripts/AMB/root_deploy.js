// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const keccak256 = require('keccak256')

const { imageCID, animationCID } = require('./arguments.js')

const dotenv = require('dotenv');
dotenv.config();

async function main() {
    console.log('deploying...');
    const Contract = await ethers.getContractFactory('RootActiveMembersBadge');
    const contract = await Contract.deploy(imageCID, animationCID);

    await contract.deployed();

    console.log(`deployed to:`, contract.address);


    // Only this predicate proxy address should have the rights to mint tokens on Ethereum.
    // Goerli Testnet
    const GOERLI_PREDICE_PRXORIES = {
        "MintableERC20PredicateProxy": "0x37c3bfC05d5ebF9EBb3FF80ce0bd0133Bf221BC8",
        "MintableERC721PredicateProxy": "0x56E14C4C1748a818a5564D33cF774c59EB3eDF59",
        "MintableERC1155PredicateProxy": "0x72d6066F486bd0052eefB9114B66ae40e0A6031a",
    }

    const ROLE = keccak256("PREDICATE_ROLE")

    try {
        const TX = await contract.grantRole(ROLE, GOERLI_PREDICE_PRXORIES["MintableERC721PredicateProxy"])
        await TX.wait()
        console.log('Predicate role was set!');
    } catch (error) {
        console.log(error);
    }


}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });