// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')

const [imageCID, animationCID] = require('./arguments.js')
const AL = require('../../AL')

const dotenv = require('dotenv');
dotenv.config();



if (false) {
    // let's first create some random addresses
    const allowList = Array.from(Array(10).keys()).map(_ => ethers.Wallet.createRandom().address)
    // add my own account for testing:
    allowList.push(myAddress)
}


async function main() {
    console.log(imageCID);
    console.log(animationCID);


    const allowList = AL
    const leafNodes = allowList.map(addr => keccak256(addr))
    const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true })
    const merkleRoot = merkleTree.getHexRoot()
    console.log('merkle root', merkleTree.getHexRoot(), merkleRoot);

    console.log('deploying...');
    const Contract = await ethers.getContractFactory('ChildActiveMembersBadge');
    const contract = await Contract.deploy(imageCID, animationCID);

    await contract.deployed();

    console.log(`deployed to:`, contract.address);

    try {
        const TX = await contract.setMerkleRoot(merkleRoot)
        await TX.wait()
        console.log(`Merkel root was set to ${merkleRoot}!`);
    } catch (error) {
        console.log(error);
    }

    return


    // now we need to give the Child Manager contract addresses the depositor role
    const MUMBAI_DEPOSITOR = "0xb5505a6d998549090530911180f38aC5130101c6"
    const POLYGON_DEPOSITOR = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa"
    const ROLE = keccak256("DEPOSITOR_ROLE")

    try {
        const TX = await contract.grantRole(ROLE, MUMBAI_DEPOSITOR)
        console.log(TX.hash);
        await TX.wait()
        console.log(`depositor role was set to ${MUMBAI_DEPOSITOR}!`);
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