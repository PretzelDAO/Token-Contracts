const { ethers } = require("hardhat");

const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')

const AL = require('../../AL')

// this is the address on Polygon mainnet
const CONTRACT_ADDRESS = '0x476e32d19D136b0F7634e4Bd987Ee72bD9f474d2'

async function main() {
    const allowList = AL

    const leafNodes = allowList.map(addr => keccak256(addr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
    const merkleRoot = merkleTree.getHexRoot();
    console.log(`New Merkle Root is ${merkleRoot}`);

    const Contract = await ethers.getContractFactory('ChildActiveMembersBadge');
    const contract = Contract.attach(CONTRACT_ADDRESS)

    console.log(`Setting Merkle Root`);
    const tx = await contract.setMerkleRoot(merkleRoot)
    console.log(tx.hash);
    await tx.wait()
    console.log(`DONE`);
}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });