// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const fs = require('fs')
const { NFTStorage, File } = require('nft.storage')
const dotenv = require('dotenv');
const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')
dotenv.config();

const ALLOW_LIST = [
    '0x56512613DbF01D92F69dAC490aC9d4C03Fd12c39'
]


async function uploadData() {
    const client = new NFTStorage({ token: process.env.NFT_STORAGE_API_KEY });

    const imageData = fs.readFileSync(`./assets/og_token.jpg`)
    const imageFile = new File([imageData], `W3B_OG_TOKEN.jpg`, { type: 'image/jpg' });
    const imageCID = await client.storeBlob(imageFile);
    console.log('image cid', imageCID);

    const animationData = fs.readFileSync(`./assets/og_token.mp4`)
    const animationFile = new File([animationData], `W3B_OG_TOKEN.mp4`, { type: ' video/mp4' });
    const animationCID = await client.storeBlob(animationFile);
    console.log('animation cid', animationCID);


    return {
        imageCID,
        animationCID
    }

}



async function main() {
    const account = await ethers.getSigner()
    const myAddress = account.address
    console.log(myAddress);

    if (false) {
        // let's first create some random addresses
        const allowList = Array.from(Array(10).keys()).map(_ => ethers.Wallet.createRandom().address)
        // add my own account for testing:
        allowList.push(myAddress)
    }

    const allowList = ALLOW_LIST
    const leafNodes = allowList.map(addr => keccak256(addr))
    const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true })
    const merkleRoot = merkleTree.getHexRoot()

    console.log('merkle root', merkleTree.getHexRoot(), merkleRoot);

    // const { imageCID, animationCID } = await uploadData()
    const imageCID = 'a'
    const animationCID = 'b'

    console.log('deploying...');
    const Contract = await ethers.getContractFactory('ChildActiveMembersBadge');
    const contract = await Contract.deploy(imageCID, animationCID, merkleRoot);

    await contract.deployed();

    console.log(`deployed to:`, contract.address);


    // now we need to give the Child Manager contract addresses the depositor role
    const MUMBAI_DEPOSITOR = "0xb5505a6d998549090530911180f38aC5130101c6"
    const POLYGON_DEPOSITOR = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa"
    const ROLE = keccak256("DEPOSITOR_ROLE")

    try {
        const TX = await contract.grantRole(ROLE, MUMBAI_DEPOSITOR)
        console.log(TX.hash);
        await TX.wait()
        console.log('depositor role was set');
    } catch (error) {
        console.log(error);
    }


    return

    // this should be a test and not be in the deploy script!

    // this should not work
    // this is a new address which is not whitelisted
    // (also the TX is send from my acc so shoulnd't work anyway)
    const bAddress = ethers.Wallet.createRandom()
    try {
        const bTX = await contract.claim(merkleTree.getHexProof(bAddress))
        await bTX.wait()
    } catch (error) {
        console.log("failed succesfully");
    }

    // this should work
    const gTX = await contract.claim(merkleTree.getHexProof(keccak256(myAddress)))
    await gTX.wait()

    const tokenURI = await contract.tokenURI(0)
    console.log(tokenURI);
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });