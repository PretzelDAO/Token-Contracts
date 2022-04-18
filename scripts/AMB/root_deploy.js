// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const fs = require('fs')
const { NFTStorage, File } = require('nft.storage')
const dotenv = require('dotenv');
const keccak256 = require('keccak256')
dotenv.config();




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

    // const { imageCID, animationCID } = await uploadData()
    const imageCID = 'a'
    const animationCID = 'b'

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
        console.log(TX.hash);
        await TX.wait()
        console.log('predicate role was set');
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