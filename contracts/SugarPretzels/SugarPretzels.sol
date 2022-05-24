// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract SugarPretzels is ERC721, ChainlinkClient, ERC2771Context, Ownable {
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

    int16 public constant temperatureConversionConstant = 10;
    uint24 public constant precipitationConversionConstant = 100;

    struct Coordinates {
        string lat;
        string long;
    }

    enum Coating {
        Brown,
        White,
        None
    }

    enum Topping {
        StripesWhite,
        StripesBrown,
        StripesRainbow,
        StripesPretzelDAO,
        SprinklesWhite,
        SprinklesBrown,
        SprinklesRainbow,
        SprinklesPretzelDAO,
        DotsWhite,
        DotsBrown,
        DotsRainbow,
        DotsPretzelDAO,
        None
    }

    struct Pretzel {
        uint8 background; // 16 backgrounds in total
        bool half;
        bool salt;
        // uint256 body; // 2 bodies
        Coating coating;
        Topping topping;
    }

    CurrentConditionsResult public currentConditions;
    LocationResult public locationInfo;
    string public baseURI = "";

    // The tokenId of the next token to be minted.
    uint256 private _currentIndex;
    uint256 private _startTokenId = 1;

    mapping(address => bool) public hasMintedGasless;
    uint256 public updateFrequency = 0.5 days;

    bytes32 public locationConditionsJobId = "7c276986e23b4b1c990d8659bca7a9d0";
    uint256 private paymentAmount = 0.1 ether;
    Coordinates public hausDerKunstLocation =
        Coordinates("48.144043846779574", "11.585822689487678");
    uint256 public lastUpdate = 0;

    mapping(uint256 => Pretzel) public pretzelData;
    uint256 immutable NUM_WORDS = 4;

    constructor(
        address trustedForwarder,
        address _link,
        address _oracle
    ) ERC721("SugarPretzels", "SPS") ERC2771Context(trustedForwarder) {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
        _currentIndex = _startTokenId;
    }

    function setUpdateFrequency(uint256 delta) external onlyOwner {
        updateFrequency = delta;
    }

    function totalSupply() public view returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than _currentIndex - _startTokenId() times
        unchecked {
            return _currentIndex - _startTokenId;
        }
    }

    /**
     * @notice Returns the current weather conditions of a location for the given coordinates.
     */
    function requestLocationCurrentConditions() public {
        require(
            block.timestamp - lastUpdate >= updateFrequency,
            "Weather conditions can only be updated every $updateFrequency."
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
        req.add("units", "metric");

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

    function generatePretzel(uint256[] memory randomWords)
        private
        view
        returns (Pretzel memory)
    {
        int16 temp = currentConditions.temperature;
        uint24 precipitation = currentConditions.precipitationPast12Hours;
        uint8 tempIdx = 3;
        uint8 precipitationIdx = 3;

        if (temp <= 0) {
            tempIdx = 0;
        } else if (temp < 15 * temperatureConversionConstant) {
            tempIdx = 1;
        } else if (temp < 30 * temperatureConversionConstant) {
            tempIdx = 2;
        }

        if (precipitation == 0) {
            precipitationIdx = 0;
        } else if (precipitation < 25 * precipitationConversionConstant) {
            precipitationIdx = 1;
        } else if (precipitation < 75 * precipitationConversionConstant) {
            precipitationIdx = 2;
        }

        uint8 background = precipitationIdx + tempIdx * 4;

        bool half = (randomWords[0] % 2) != 1;
        // 10% chance to get a salty pretzel
        bool salt = (randomWords[1] % 10) == 0;

        if (salt && !half) {
            return Pretzel(background, half, salt, Coating.None, Topping.None);
        }

        // 90% chance to get a coating
        bool hasCoating = (randomWords[2] % 10) > 0;
        if (hasCoating) {
            Coating coating = Coating(randomWords[2] % 2);
            Topping topping = Topping(randomWords[3] % 13);
            return Pretzel(background, half, salt, coating, topping);
        } else {
            // topping only works with coating
            return Pretzel(background, half, salt, Coating.None, Topping.None);
        }
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

    function setLocationConditionsJobId(bytes32 _locationConditionsJobId)
        external
        onlyOwner
    {
        locationConditionsJobId = _locationConditionsJobId;
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

    function getRandomWords(address to)
        private
        view
        returns (uint256[] memory)
    {
        uint256[] memory randomWords = new uint256[](4);

        randomWords[0] = uint256(
            keccak256(
                abi.encode(
                    to,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    block.difficulty,
                    blockhash(block.number - 1),
                    address(this),
                    totalSupply()
                )
            )
        );

        for (uint256 i = 1; i < NUM_WORDS; ) {
            randomWords[i] = uint256(keccak256(abi.encode(randomWords[i - 1])));
            unchecked {
                ++i;
            }
        }

        return randomWords;
    }

    function mintWithoutGas() external {
        require(
            super.isTrustedForwarder(msg.sender),
            "Gasless minting is only possible via OpenGSN."
        );
        require(
            !hasMintedGasless[_msgSender()],
            "Maximum number of gasless mints reached."
        );
        hasMintedGasless[_msgSender()] = true;

        handleMint(_msgSender(), getRandomWords(_msgSender()));
    }

    function mint() external {
        require(
            _msgSender() == tx.origin,
            "Contracts are not allowed to mint."
        );

        handleMint(_msgSender(), getRandomWords(_msgSender()));
    }

    function handleMint(address minter, uint256[] memory randomWords) private {
        uint256 tokenId = _currentIndex;
        unchecked {
            ++_currentIndex;
        }

        Pretzel memory pretzel = generatePretzel(randomWords);
        pretzelData[tokenId] = pretzel;

        // interactions
        _safeMint(minter, tokenId);
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
}
