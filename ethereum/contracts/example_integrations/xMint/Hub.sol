// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "solidity-bytes-utils/BytesLib.sol";

import "../../interfaces/IWormhole.sol";
import "../../interfaces/ITokenBridge.sol";
import "../../interfaces/IWormholeReceiver.sol";
import "../../interfaces/ICoreRelayer.sol";

contract XmintHub is ERC20, IWormholeReceiver {
    //using BytesLib for bytes;

    mapping(uint16 => bytes32) trustedContracts;
    mapping(bytes32 => bool) consumedMessages;
    address owner;
    IWormhole core_bridge;
    ITokenBridge token_bridge;
    ICoreRelayer core_relayer;
    uint32 nonce = 1;
    uint8 consistencyLevel = 200;

    uint32 SAFE_DELIVERY_GAS_CAPTURE = 5000000; //Capture 500k gas for fees

    event Log(string indexed str);

    constructor(
        string memory name_,
        string memory symbol_,
        address coreBridgeAddress,
        address tokenBridgeAddress,
        address coreRelayerAddress
    ) ERC20(name_, symbol_) {
        owner = msg.sender;
        core_bridge = IWormhole(coreBridgeAddress);
        token_bridge = ITokenBridge(tokenBridgeAddress);
        core_relayer = ICoreRelayer(coreRelayerAddress);
    }

    /**
     * This function is used to add spoke contract deployments into the trusted addresses of this
     *     contract.
     */
    function registerApplicationContracts(uint16 chainId, bytes32 emitterAddr) public {
        require(msg.sender == owner, "Only owner can register new chains!");
        trustedContracts[chainId] = emitterAddr;
    }

    //This is the function which receives all messages from the remote contracts.
    function receiveWormholeMessages(bytes[] memory vaas, bytes[] memory additionalData) public payable override {
        //The first message should be from the token bridge, so attempt to redeem it.
        ITokenBridge.TransferWithPayload memory transferResult =
            token_bridge.parseTransferWithPayload(token_bridge.completeTransferWithPayload(vaas[0]));

        // Ensure this transfer originated from a trusted address!
        // The token bridge enforces replay protection however, so no need to enforce it here.
        // The chain which this came from is a property of the core bridge, so the chain ID is read from the VAA.
        uint16 fromChain = core_bridge.parseVM(vaas[0]).emitterChainId;
        //Require that the address these tokens were sent from is the trusted remote contract for that chain.
        require(transferResult.fromAddress == trustedContracts[fromChain]);

        //Calculate how many tokens to mint for the user
        //TODO is tokenAddress the origin address or the local foreign address?
        uint256 mintAmount =
            calculateMintAmount(transferResult.amount, core_relayer.fromWormholeFormat(transferResult.tokenAddress));

        //Mint tokens to this contract
        _mint(address(this), mintAmount);

        //Bridge the tokens back to the spoke contract, maintaining the intendedRecipient, which is inside the payload.
        bridgeTokens(fromChain, transferResult.payload, mintAmount);

        //Request delivery from the relayer network
        requestForward(fromChain, bytesToBytes32(transferResult.payload, 0));
    }

    function bridgeTokens(uint16 remoteChain, bytes memory payload, uint256 amount) internal {
        (bool success, bytes memory data) = address(token_bridge).call{value: amount + core_bridge.messageFee()}(
            //token, amount, receipientChain, recipientAddress, nonce, payload
            abi.encodeWithSignature(
                "transferTokensWithPayload(address,uint256,uint16,bytes32,nonce,bytes memory)",
                address(this),
                amount,
                remoteChain,
                trustedContracts[remoteChain],
                nonce,
                payload
            )
        );
    }

    function requestForward(uint16 targetChain, bytes32 intendedRecipient) internal {
        uint256 computeBudget = core_relayer.quoteGasDeliveryFee(
            targetChain, SAFE_DELIVERY_GAS_CAPTURE, core_relayer.getDefaultRelayProvider()
        );
        uint256 applicationBudget = 0;

        ICoreRelayer.DeliveryRequest memory request = ICoreRelayer.DeliveryRequest(
            targetChain, //target chain
            trustedContracts[targetChain], //target address
            intendedRecipient, //refund address. All remaining funds will be returned to the user now
            computeBudget, //compute budget
            applicationBudget, //application budget, not needed in this case.
            core_relayer.getDefaultRelayParams() //no overrides
        );

        core_relayer.requestDelivery{value: computeBudget + applicationBudget}(
            request, nonce, core_relayer.getDefaultRelayProvider()
        );
    }

    //This function calculates how many tokens should be minted to the end user based on how much
    //money they sent to this contract.
    function calculateMintAmount(uint256 paymentAmount, address paymentToken) internal returns (uint256 mintAmount) {
        //Because this is a toy example, we will mint them 1 token regardless of what token they paid with
        // or how much they paid.
        return 1 * 10 ^ 18;
    }

    //This function allows you to purchase tokens from the Hub chain. Because this is all on the Hub chain,
    // there's no need for relaying.
    function purchaseLocal() internal {
        //TODO this
    }

    function mintLocal() internal {
        //TODO this
    }

    function bytesToBytes32(bytes memory b, uint256 offset) private pure returns (bytes32) {
        bytes32 out;

        for (uint256 i = 0; i < 32; i++) {
            out |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
        }
        return out;
    }
}
