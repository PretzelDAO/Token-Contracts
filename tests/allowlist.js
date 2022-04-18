// note this is broken code

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