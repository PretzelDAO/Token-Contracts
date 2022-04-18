const { ethers } = require("hardhat");

const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')

const AL = require('../../AL')

async function main() {
    const allowList = AL

    const account = await ethers.getSigner()
    const address = account.address
    console.log(address);

    const leafNodes = allowList.map(addr => keccak256(addr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
    // const merkleRoot = merkleTree.getRoot();

    let merkleProof = merkleTree.getHexProof(keccak256(address));


    const Contract = await ethers.getContractFactory('ChildActiveMembersBadge');

    const contract = Contract.attach('0x2b98AD929Ee80d23902d27d1A9A9549D4b067448')

    const tx = await contract.claim(merkleProof, {
        gasLimit: 500000
    })
    await tx.wait()

    console.log(await contract.balanceOf(address));

    console.log(await contract.tokenURI(1));
    // console.log(await contract.tokenURI(0));

}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });