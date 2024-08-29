// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { IIPAssetRegistry } from "./interfaces/registries/IIPAssetRegistry.sol";
import { IGroupNFT } from "./interfaces/IGroupNFT.sol";
import { Errors } from "./lib/Errors.sol";

/// @title GroupNFT
/// @notice ERC721-compliant NFT contract for grouping IP assets within Story Protocol.
contract GroupNFT is IGroupNFT, ERC721Upgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for uint256;

    /// @notice Immutable reference to the IP Asset Registry
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Event emitted when metadata for a batch of tokens is updated, per EIP-4906
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);

    /// @dev Storage structure for the GroupNFT
    /// @custom:storage-location erc7201:story-protocol.GroupNFT
    struct GroupNFTStorage {
        string imageUrl;
        uint256 totalSupply;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.GroupNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GroupNFTStorageLocation =
        0x1f63c78b3808749cafddcb77c269221c148dbaa356630c2195a6ec03d7fedb00;

    /// @notice Ensures only the IP Asset Registry can call certain functions
    modifier onlyIPAssetRegistry() {
        if (msg.sender != address(IP_ASSET_REGISTRY)) {
            revert Errors.GroupNFT__CallerNotIPAssetRegistry(msg.sender);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address iPAssetRegistry) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(iPAssetRegistry);
        _disableInitializers();
    }

    /// @dev Initializes the GroupNFT contract
    /// @param accessManager Address of the access control manager
    /// @param imageUrl URL of the image associated with the NFT
    function initialize(address accessManager, string memory imageUrl) public initializer {
        if (accessManager == address(0)) {
            revert Errors.GroupNFT__ZeroAccessManager();
        }
        __ERC721_init("Programmable IP Group IP NFT", "GroupNFT");
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();

        GroupNFTStorage storage nftStorage = _getGroupNFTStorage();
        nftStorage.imageUrl = imageUrl;
    }

    /// @notice Sets the Licensing Image URL
    /// @dev Restricted to protocol admin
    /// @param url The URL of the Licensing Image
    function setLicensingImageUrl(string calldata url) external restricted {
        GroupNFTStorage storage nftStorage = _getGroupNFTStorage();
        nftStorage.imageUrl = url;
        emit BatchMetadataUpdate(0, nftStorage.totalSupply);
    }

    /// @notice Mints a new Group NFT
    /// @param minter Address of the minter
    /// @param receiver Address of the receiver of the minted Group NFT
    /// @return groupNftId ID of the newly minted Group NFT
    function mintGroupNft(address minter, address receiver) external onlyIPAssetRegistry returns (uint256 groupNftId) {
        GroupNFTStorage storage nftStorage = _getGroupNFTStorage();
        groupNftId = nftStorage.totalSupply++;
        _mint(receiver, groupNftId);
        emit GroupNFTMinted(minter, receiver, groupNftId);
    }

    /// @notice Returns the total supply of minted Group NFTs
    /// @return Total number of minted Group NFTs
    function totalSupply() external view returns (uint256) {
        return _getGroupNFTStorage().totalSupply;
    }

    /// @notice Returns the metadata URI for a given token ID
    /// @param id ID of the token
    /// @return URI of the token's metadata
    function tokenURI(
        uint256 id
    ) public view virtual override(ERC721Upgradeable, IERC721Metadata) returns (string memory) {
        GroupNFTStorage storage nftStorage = _getGroupNFTStorage();

        string memory json = string(
            abi.encodePacked(
                "{",
                '"name": "Story Protocol IP Assets Group #',
                id.toString(),
                '",',
                '"description": "IPAsset Group",',
                '"external_url": "https://protocol.storyprotocol.xyz/ipa/',
                id.toString(),
                '",',
                '"image": "',
                nftStorage.imageUrl,
                '"'
            )
        );

        json = string(abi.encodePacked(json, "}"));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Checks if the contract supports a specific interface
    /// @param interfaceId Interface ID to check
    /// @return True if the interface is supported, false otherwise
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(IGroupNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Retrieves the GroupNFT storage structure
    /// @return Reference to the GroupNFT storage
    function _getGroupNFTStorage() private pure returns (GroupNFTStorage storage nftStorage) {
        assembly {
            nftStorage.slot := GroupNFTStorageLocation
        }
    }

    /// @dev Authorizes an upgrade to the contract
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
