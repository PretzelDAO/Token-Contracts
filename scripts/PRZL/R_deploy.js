// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const { forwarder, linkToken, weatherOracle, relayHub, vrfCoordinator, keyHash } = require('./config')

const BASE_URI = 'https://metadata.pretzeldao.com/bakery/'

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy
    const RandomPretzel = await ethers.getContractFactory("RandomPretzel");
    const randomPretzel = await RandomPretzel.deploy(forwarder, linkToken, weatherOracle, vrfCoordinator, keyHash);
    await randomPretzel.deployed();
    console.log("randomPretzel deployed to:", randomPretzel.address);


    // SET BASEURI
    const txURI = await randomPretzel.setBaseURI(BASE_URI)
    console.log('tx URI hash:', txURI.hash);

    const addr = randomPretzel.address
    const Paymaster = await ethers.getContractFactory("SingleRecipientPaymaster");
    const paymaster = await Paymaster.deploy(addr);
    console.log("Paymaster deployed to:", paymaster.address);


    //  SET RELAY HUB FOR PAYMASTER
    let txObj = await paymaster.setRelayHub(relayHub)
    console.log('txHash set relayHub', txObj.hash)

    //  SET TRUSTED FORWARDER FOR PAYMASTER
    txObj = await paymaster.setTrustedForwarder(forwarder)
    console.log('txHash set trusted forwarder', txObj.hash)


    const signers = await ethers.getSigners();
    const amountInEther = '0.005';

    // FUND THE PAYMASTER
    // WE NEED TO SET A CUSTOM GAS LIMIT

    // Create a transaction object
    let tx = {
        to: paymaster.address,
        // Convert currency unit from ether to wei
        value: ethers.utils.parseEther(amountInEther),
        gasLimit: ethers.utils.hexlify(100000),
        // gasPrice: ethers.utils.parseUnits('2', 'gwei')
    }

    txObj = await signers[0].sendTransaction(tx)
    console.log('txHash fund paymaster / relayhub', txObj.hash)


    // A Human-Readable ABI; for interacting with the contract, we
    // must include any fragment we wish to use
    const abi = [
        // Read-Only Functions
        "function balanceOf(address owner) view returns (uint256)",
        "function decimals() view returns (uint8)",
        "function symbol() view returns (string)",

        // Authenticated Functions
        "function transfer(address to, uint amount) returns (bool)",

        // Events
        "event Transfer(address indexed from, address indexed to, uint amount)"
    ];

    // Read-Only; By connecting to a Provider, allows:
    // - Any constant function
    // - Querying Filters
    // - Populating Unsigned Transactions for non-constant methods
    // - Estimating Gas for non-constant (as an anonymous sender)
    // - Static Calling non-constant methods (as anonymous sender)
    const erc20 = new ethers.Contract(linkToken, abi, signers[0]);
    txObj = await erc20.transfer(randomPretzel.address, ethers.utils.parseEther('1'))
    console.log('txHash LINK transfer', txObj.hash)
    await txObj.wait()

    // let's request an update from the oracle
    txObj = await randomPretzel.requestLocationCurrentConditions()
    console.log('txHash updating location info', txObj.hash)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
