// contracts/Getters.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "../interfaces/IWormhole.sol";

import "./RelayProviderState.sol";

contract RelayProviderGetters is RelayProviderState {
    function owner() public view returns (address) {
        return _state.owner;
    }

    function pendingOwner() public view returns (address) {
        return _state.pendingOwner;
    }

    function isInitialized(address impl) public view returns (bool) {
        return _state.initializedImplementations[impl];
    }

    function chainId() public view returns (uint16) {
        return _state.chainId;
    }

    function coreRelayer() public view returns (address) {
        return _state.coreRelayer;
    }

    function approvedSender(address sender) public view returns (bool) {
        return _state.approvedSenders[sender];
    }

    function gasPrice(uint16 targetChainId) public view returns (uint128) {
        return _state.data[targetChainId].gasPrice;
    }

    function nativeCurrencyPrice(uint16 targetChainId) public view returns (uint128) {
        return _state.data[targetChainId].nativeCurrencyPrice;
    }

    function deliverGasOverhead(uint16 targetChainId) public view returns (uint32) {
        return _state.deliverGasOverhead[targetChainId];
    }

    function maximumBudget(uint16 targetChainId) public view returns (uint256) {
        return _state.maximumBudget[targetChainId];
    }

    function wormholeFee(uint16 targetChainId) public view returns (uint32) {
        return _state.wormholeFee[targetChainId];
    }

    function rewardAddress() public view returns (address) {
        return _state.rewardAddress;
    }

    function deliveryAddress(uint16 targetChain) public view returns (bytes32 whFormatAddress) {
        return _state.deliveryAddressMap[targetChain];
    }

    function assetConversionBuffer(uint16 targetChain)
        public
        view
        returns (uint16 tolerance, uint16 toleranceDenominator)
    {
        return (_state.assetConversionBuffer[targetChain], _state.assetConversionBufferDenominator[targetChain]);
    }
}
