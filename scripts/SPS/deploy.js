// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, network } = require("hardhat");
const constructorArgs = require('./arguments')



const RELAY_HUBS = {
    'polygon': '0x6C28AfC105e65782D9Ea6F2cA68df84C9e7d750d',
    'mumbai': '0x6646cD15d33cE3a6933e36de38990121e8ba2806',
    'kovan': '0x727862794bdaa3b8Bc4E3705950D4e9397E3bAfd'
}

const NETWORK = network.name
const BASE_URI = 'http://metadata.pretzeldao.com:8080/sugarpretzels/nft/'


async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy
    const SugarPretzel = await ethers.getContractFactory("SugarPretzels");

    // DEPLOY TOKEN CONTRACT WITH TRUSTED FORWARDING CONTRACT HERE
    const [trustedForwarder, linkTokenAddress, weatherOracleAddress] = constructorArgs

    const sugarPretzel = await SugarPretzel.deploy(trustedForwarder, linkTokenAddress, weatherOracleAddress);

    await sugarPretzel.deployed();
    console.log("sugarPretzel deployed to:", sugarPretzel.address);


    // SET BASEURI
    // const txURI = await sugarPretzel.setBaseURI(BASE_URI)
    // console.log('tx URI hash:', txURI.hash);

    const addr = sugarPretzel.address
    const Paymaster = await ethers.getContractFactory("SingleRecipientPaymaster");
    const paymaster = await Paymaster.deploy(addr);
    console.log("Paymaster deployed to:", paymaster.address);


    //  SET RELAY HUB FOR PAYMASTER
    const relayHub = RELAY_HUBS[NETWORK]
    let txObj = await paymaster.setRelayHub(relayHub)
    console.log('txHash set relayHub', txObj.hash)

    //  SET TRUSTED FORWARDER FOR PAYMASTER
    txObj = await paymaster.setTrustedForwarder(trustedForwarder)
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
    const erc20 = new ethers.Contract(linkTokenAddress, abi, signers[0]);
    txObj = await erc20.transfer(sugarPretzel.address, ethers.utils.parseEther('1'))
    console.log('txHash LINK transfer', txObj.hash)
    await txObj.wait()

    // let's request an update from the oracle
    txObj = await sugarPretzel.requestLocationCurrentConditions()
    console.log('txHash updating location info', txObj.hash)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
