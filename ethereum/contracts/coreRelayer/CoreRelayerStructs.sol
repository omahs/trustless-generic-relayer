// contracts/Structs.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "../interfaces/IWormhole.sol";

abstract contract CoreRelayerStructs {
    //This first group of structs are external facing API objects,
    //which should be considered untrusted and unmodifiable

    struct DeliveryRequestsContainer {
        uint8 payloadId; // payloadID = 1
        address relayProviderAddress;
        DeliveryRequest[] requests;
    }

    // struct TargetDeliveryParameters {
    //     // encoded batchVM to be delivered on the target chain
    //     bytes encodedVM;
    //     // Index of the delivery VM in a batch
    //     uint8 deliveryIndex;
    //     uint8 multisendIndex;
    //     //uint32 targetCallGasOverride;
    // }

    struct TargetDeliveryParametersSingle {
        // encoded batchVM to be delivered on the target chain
        bytes[] encodedVMs;
        // Index of the delivery VM in a batch
        uint8 deliveryIndex;
        // Index of the target chain inside the delivery VM
        uint8 multisendIndex;
        // relayer refund address
        address payable relayerRefundAddress;
    }
    // Optional gasOverride which can be supplied by the relayer
    // uint32 targetCallGasOverride;

    struct TargetRedeliveryByTxHashParamsSingle {
        bytes redeliveryVM;
        bytes[] sourceEncodedVMs;
        address payable relayerRefundAddress;
    }

    struct DeliveryRequest {
        uint16 targetChain;
        bytes32 targetAddress;
        bytes32 refundAddress;
        uint256 computeBudget;
        uint256 applicationBudget;
        bytes relayParameters;
    }

    struct RedeliveryByTxHashRequest {
        uint16 sourceChain;
        bytes32 sourceTxHash;
        uint32 sourceNonce;
        uint16 targetChain;
        uint8 deliveryIndex;
        uint8 multisendIndex;
        uint256 newComputeBudget;
        uint256 newApplicationBudget;
        bytes newRelayParameters;
    }

    struct RelayParameters {
        uint8 version; //1
        bytes32 providerAddressOverride;
    }

    //Below this are internal structs

    //Wire Types
    struct DeliveryInstructionsContainer {
        uint8 payloadId; //1
        bool sufficientlyFunded;
        DeliveryInstruction[] instructions;
    }

    struct DeliveryInstruction {
        uint16 targetChain;
        bytes32 targetAddress;
        bytes32 refundAddress;
        uint256 maximumRefundTarget;
        uint256 applicationBudgetTarget;
        ExecutionParameters executionParameters; //Has the gas limit to execute with
    }

    struct ExecutionParameters {
        uint8 version;
        uint32 gasLimit;
        bytes32 providerDeliveryAddress;
    }

    struct RedeliveryByTxHashInstruction {
        uint8 payloadId; //2
        uint16 sourceChain;
        bytes32 sourceTxHash;
        uint32 sourceNonce;
        uint16 targetChain;
        uint8 deliveryIndex;
        uint8 multisendIndex;
        uint256 newMaximumRefundTarget;
        uint256 newApplicationBudgetTarget;
        ExecutionParameters executionParameters;
    }

    //End Wire Types

    //Internal usage structs

    struct AllowedEmitterSequence {
        // wormhole emitter address
        bytes32 emitterAddress;
        // wormhole message sequence
        uint64 sequence;
    }

    struct ForwardingRequest {
        bytes deliveryRequestsContainer;
        uint16 rolloverChain;
        uint32 nonce;
        address sender;
        uint256 msgValue;
        bool isValid;
    }

    // struct DeliveryStatus {
    //     uint8 payloadID; // payloadID = 2;
    //     bytes32 batchHash;
    //     bytes32 emitterAddress;
    //     uint64 sequence;
    //     uint16 deliveryCount;
    //     bool deliverySuccess;
    // }

    // // TODO: WIP
    // struct RewardPayout {
    //     uint8 payloadID; // payloadID = 100; prevent collisions with new blueprint payloads
    //     uint16 fromChain;
    //     uint16 chain;
    //     uint256 amount;
    //     bytes32 receiver;
    // }
}
