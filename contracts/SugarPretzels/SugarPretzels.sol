// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract SugarPretzels is
    ERC721,
    ERC721Enumerable,
    ChainlinkClient,
    VRFConsumerBaseV2,
    ERC2771Context,
    Ownable
{
    using Counters for Counters.Counter;
    using Chainlink for Chainlink.Request;

    struct LocationResult {
        uint256 locationKey;
        string name;
        bytes2 countryCode;
    }
    struct CurrentConditionsResult {
        uint256 timestamp;
        uint24 precipitationPast12Hours;
        uint24 precipitationPast24Hours;
        uint24 precipitationPastHour;
        uint24 pressure;
        int16 temperature;
        uint16 windDirectionDegrees;
        uint16 windSpeed;
        uint8 precipitationType;
        uint8 relativeHumidity;
        uint8 uvIndex;
        uint8 weatherIcon;
    }

    struct Coordinates {
        string lat;
        string long;
    }

    enum Icing {
        None,
        Brown,
        White
    }

    enum Topping {
        None,
        StripesWhite,
        StripesBrown,
        StripesRainbow,
        SprinklesWhite,
        SprinklesBrown,
        SprinklesRainbow,
        DotWhite,
        DotBrown,
        DotRainbow
    }

    struct Pretzel {
        uint8 background; // 16 backgrounds in total
        bool half;
        bool salt;
        // uint256 body; // 2 bodies
        Icing icing;
        Topping topping;
    }

    CurrentConditionsResult public currentConditions;
    LocationResult public locationInfo;
    Counters.Counter private _tokenIdCounter;
    string public baseURI = "";
    mapping(address => bool) public hasMinted;

    bytes32 public locationConditionsJobId = "7c276986e23b4b1c990d8659bca7a9d0";
    uint256 public paymentAmount = 0.1 ether;
    Coordinates public hausDerKunstLocation =
        Coordinates("48.144043846779574", "11.585822689487678");
    uint256 public lastUpdate = 0;

    VRFCoordinatorV2Interface COORDINATOR;
    // Your subscription ID.
    uint64 s_subscriptionId;

    // Rinkeby coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 4;

    mapping(uint256 => address) public minterIds;
    mapping(uint256 => Pretzel) public pretzelData;

    constructor(
        address trustedForwarder,
        address _link,
        address _oracle,
        uint64 subscriptionId
    )
        ERC721("SugarPretzels", "SPS")
        VRFConsumerBaseV2(vrfCoordinator)
        ERC2771Context(trustedForwarder)
    {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    /**
     * @notice Returns the current weather conditions of a location for the given coordinates.
     */
    function requestLocationCurrentConditions() public {
        require(
            block.timestamp - lastUpdate >= 1 days,
            "Weather conditions can only be updated every 24h."
        );
        lastUpdate = block.timestamp;

        Chainlink.Request memory req = buildChainlinkRequest(
            locationConditionsJobId,
            address(this),
            this.fulfillLocationCurrentConditions.selector
        );

        req.add("endpoint", "location-current-conditions"); // NB: not required if it has been hardcoded in the job spec
        req.add("lat", hausDerKunstLocation.lat);
        req.add("lon", hausDerKunstLocation.long);
        req.add("units", "metrics");

        sendChainlinkRequest(req, paymentAmount);
    }

    /**
     * @notice Consumes the data returned by the node job on a particular request.
     * @dev Only when `_locationFound` is true, both `_locationFound` and `_currentConditionsResult` will contain
     * meaningful data (as bytes). This function body is just an example of usage.
     * @param _requestId the request ID for fulfillment.
     * @param _locationFound true if a location was found for the given coordinates, otherwise false.
     * @param _locationResult the location information (encoded as LocationResult).
     * @param _currentConditionsResult the current weather conditions (encoded as CurrentConditionsResult).
     */
    function fulfillLocationCurrentConditions(
        bytes32 _requestId,
        bool _locationFound,
        bytes memory _locationResult,
        bytes memory _currentConditionsResult
    ) public recordChainlinkFulfillment(_requestId) {
        if (_locationFound) {
            storeLocationResult(_locationResult);
            storeCurrentConditionsResult(_currentConditionsResult);
        }
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() private returns (uint256) {
        // Will revert if subscription is not set and funded.
        return
            COORDINATOR.requestRandomWords(
                keyHash,
                s_subscriptionId,
                requestConfirmations,
                callbackGasLimit,
                numWords
            );
    }

    function fulfillRandomWords(
        uint256 requestId, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        address minter = minterIds[requestId];

        require(!hasMinted[minter], "Only one mint per wallet is allowed.");

        handleMint(minter, generatePretzel(randomWords));
    }

    function generatePretzel(uint256[] memory randomWords)
        public
        pure
        returns (Pretzel memory)
    {
        int16 temp = 255; //currentConditions.temperature;
        uint24 precipitation = 2000; //currentConditions.precipitationPast12Hours;
        uint8 tempIdx = 3;
        uint8 precipitationIdx = 3;

        if (temp <= 0) {
            tempIdx = 0;
        } else if (temp < 15 * 10**1) {
            tempIdx = 1;
        } else if (temp < 30 * 10**1) {
            tempIdx = 2;
        }

        if (precipitation == 0) {
            precipitationIdx = 0;
        } else if (precipitation < 25 * 10**2) {
            precipitationIdx = 1;
        } else if (precipitation < 75 * 10**2) {
            precipitationIdx = 2;
        }

        uint8 background = precipitationIdx + tempIdx * 4;

        bool half = (randomWords[0] % 2) != 1;
        bool salt = (randomWords[1] % 2) != 1;

        if (salt && !half) {
            return Pretzel(background, half, salt, Icing.None, Topping.None);
        }

        Icing icing = Icing(randomWords[2] % 3);
        Topping topping = Topping.None;
        if (icing != Icing.None) {
            topping = Topping(randomWords[3] % 10);
        }
        return Pretzel(background, half, salt, icing, topping);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function storeLocationResult(bytes memory _locationResult) private {
        LocationResult memory result = abi.decode(
            _locationResult,
            (LocationResult)
        );
        locationInfo = result;
    }

    function storeCurrentConditionsResult(bytes memory _currentConditionsResult)
        private
    {
        CurrentConditionsResult memory result = abi.decode(
            _currentConditionsResult,
            (CurrentConditionsResult)
        );
        currentConditions = result;
    }

    /* ========== OTHER FUNCTIONS ========== */

    function getOracleAddress() external view returns (address) {
        return chainlinkOracleAddress();
    }

    function setOracle(address _oracle) external onlyOwner {
        setChainlinkOracle(_oracle);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface linkToken = LinkTokenInterface(
            chainlinkTokenAddress()
        );
        require(
            linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    // =============================================

    function mint() external {
        require(
            !hasMinted[_msgSender()],
            "Only one mint per wallet is allowed."
        );
        minterIds[requestRandomWords()] = _msgSender();
    }

    function handleMint(address minter, Pretzel memory pretzel) private {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // interactions
        _safeMint(minter, tokenId);
        pretzelData[tokenId] = pretzel;

        hasMinted[minter] = true;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    // The following functions are overrides required by Solidity.

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
