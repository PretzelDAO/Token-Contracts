const { ethers } = require("hardhat");

const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')

const ALLOW_LIST = [
    '0x56512613DbF01D92F69dAC490aC9d4C03Fd12c39'
]


async function main() {
    const account = await ethers.getSigner()
    const address = account.address
    console.log(address);

    const leafNodes = ALLOW_LIST.map(addr => keccak256(addr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
    // const merkleRoot = merkleTree.getRoot();

    let merkleProof = merkleTree.getHexProof(keccak256(address));


    const Contract = await ethers.getContractFactory('ChildActiveMembersBadge');

    const contract = Contract.attach('0x6B6A19bF71B4eB587C00069a5901fCb457629cFe')

    // const tx = await contract.claim(merkleProof)

    console.log(await contract.balanceOf(address));

    console.log(await contract.tokenURI(0));
    console.log(await contract.tokenURI(1));

}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });