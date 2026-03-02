// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Dependencies
import { Ownable } from "solady/auth/Ownable.sol";

// Interfaces
import { IWETH } from "@rhinestone/compact-utils/src/interfaces/IWETH.sol";

// Libraries
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

// Types
import { Execution } from "modulekit/integrations/ERC7579Exec.sol";

struct TokenAmount {
    address token;
    uint256 amount;
}

/// @title Rhinestone Relayer
contract RhinestoneRelayerV1 is Ownable {
    /* //////////////////////////////////////////////////////////////
                                 LIBRARIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Used for executing token transfers and approvals
    using SafeTransferLib for address;

    /* //////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the relayer address is invalid
    error InvalidRelayerAddress();

    /// @notice Error thrown when the relayer is not trusted
    error RelayerNotTrusted();

    /// @notice Thrown when a constructor argument is invalid
    error InvalidConstructorArg();

    /// @notice Thrown when the recipient address is invalid
    error InvalidRecipient();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when a relayer is set
    event RelayerSet(address indexed relayer, bool isTrusted);

    /// @notice Event emitted when tokens are withdrawn
    event Withdrawn(address indexed token, uint256 amount);

    /// @notice Event emitted when approvals are set for tokens
    event Approved(address indexed token, uint256 amount, address router);

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of trusted relayer addresses.
    mapping(address relayer => bool isTrusted) public isRelayer;

    /* //////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the Warp Routerr
    address public immutable RHINESTONE_ROUTER;

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the contract with the relayer address and owner.
    /// @param _router The address of the Warp Routerr.
    /// @param _owner The address of the initial owner.
    constructor(address _router, address _owner) {
        require(_router != address(0), InvalidConstructorArg());
        require(_owner != address(0), InvalidConstructorArg());

        // Initialize the Warp Routerr address
        RHINESTONE_ROUTER = _router;
        // Initialize the owner
        _initializeOwner(_owner);
    }

    /* //////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to check if the caller is a trusted relayer.
    modifier onlyTrustedRelayer() {
        // Check if the caller is a trusted relayer
        require(isRelayer[msg.sender], RelayerNotTrusted());
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the relayer address and trust status.
    /// @param relayer The address of the relayer to set.
    /// @param isTrusted Whether the relayer is trusted.
    /// @dev Only callable by the owner.
    function setRelayer(address relayer, bool isTrusted) external onlyOwner {
        // Set the relayer address and trust status
        isRelayer[relayer] = isTrusted;
        // Emit the RelayerSet event
        emit RelayerSet(relayer, isTrusted);
    }

    /// @notice Sets the approvals for a token to the Warp Routerr.
    /// @param tokenAmounts The array of TokenAmount structs containing token addresses and amounts.
    function setApprovals(TokenAmount[] calldata tokenAmounts) external onlyOwner {
        _setApprovalForRouter(tokenAmounts, RHINESTONE_ROUTER);
    }

    /// @notice Withdraws tokens from the contract to the owner's address.
    /// @param tokenAmount The array of TokenAmount structs containing token addresses and amounts.
    function withdraw(TokenAmount[] calldata tokenAmount) external onlyOwner {
        _withdraw(owner(), tokenAmount);
    }

    /// @notice Withdraws tokens from the contract to the owner's address.
    /// @param recipient a custom recipient to which the pot can rebalance to
    /// @param tokenAmount The array of TokenAmount structs containing token addresses and amounts.
    function withdraw(address recipient, TokenAmount[] calldata tokenAmount) external onlyOwner {
        require(recipient != address(0), InvalidRecipient());
        _withdraw(recipient, tokenAmount);
    }

    function _withdraw(address recipient, TokenAmount[] calldata tokenAmount) internal {
        uint256 length = tokenAmount.length;
        // sload owner and cache it
        // Iterate through the array of TokenAmount structs
        for (uint256 i; i < length;) {
            address token = tokenAmount[i].token;
            uint256 amount = tokenAmount[i].amount;
            if (token == address(0)) {
                // Native token (ETH) withdrawal
                recipient.safeTransferETH(amount);
            } else {
                // ERC20 token withdrawal
                token.safeTransfer(recipient, amount);
            }
            emit Withdrawn(token, amount);
            unchecked {
                i++;
            }
        }
    }

    /// @notice Unwraps WETH into ETH
    /// @param WETH address
    /// @param amount Amount of WETH to unwrap
    function unwrapWETH(address WETH, uint256 amount) external onlyOwner {
        // Withdraw WETH to ETH
        IWETH(WETH).withdraw(amount);
    }

    /// @notice Wraps ETH into WETH using funds from the contract
    /// @param WETH address
    /// @param amount Amount of ETH to wrap
    function wrapWETH(address WETH, uint256 amount) external onlyOwner {
        // Deposit ETH to WETH
        IWETH(WETH).deposit{ value: amount }();
    }

    /* //////////////////////////////////////////////////////////////
                                 RELAY
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes calldata on the Warp Routerr.
    /// @dev Doesn't allow using an ETH amount stored in the contract.
    /// @dev Selector optimized to be 0x00000000
    function relayERC202076776083() external payable onlyTrustedRelayer {
        address router = RHINESTONE_ROUTER;
        // Execute the calldata on the Warp Routerr
        assembly {
            // Get calldata size minus
            // the function selector (first 4 bytes)
            let s := sub(calldatasize(), 0x04)
            // Copy calldata to memory
            calldatacopy(0x00, 0x04, s)
            // Call the Warp Routerr with the copied calldata, bubble revert if the call failed
            if iszero(call(gas(), router, 0x00, 0x00, s, 0x00, 0x00)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /// @notice Executes calldata on the Warp Routerr.
    /// @dev Allows using an ETH amount stored in the contract along with the call by encoding an
    ///      amount in the 12 bytes after the function selector.
    ///      [0x00000096](4)[callvalue](12)[calldata]
    /// @dev Selector optimized to be 0x00000096
    function relayETH7172445() external payable onlyTrustedRelayer {
        address router = RHINESTONE_ROUTER;
        // Execute the calldata on the Warp Routerr
        assembly {
            // Get calldata size minus
            // the function selector (first 4 bytes)
            // and the callvalue (next 12 bytes)
            let s := sub(calldatasize(), 0x10)
            // Copy calldata to memory
            calldatacopy(0x00, 0x10, s)
            // Call the Warp Routerr with the copied calldata, bubble revert if the call failed
            if iszero(call(gas(), router, shr(160, calldataload(0x04)), 0x00, s, 0x00, 0x00)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /* //////////////////////////////////////////////////////////////
                               MULTICALL
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes a multicall using provided calldata
    /// @param calls An array of Execution structs containing target, value, and callData
    function multicall(Execution[] calldata calls) external payable onlyTrustedRelayer {
        assembly {
            // Get the length of the calls array
            let len := calls.length
            // Pointer to the start of the calls array
            let ptr := calls.offset
            // Each element is a 0x20 offset to an Execution struct
            let end := add(ptr, mul(len, 0x20))

            // Iterate through each call
            for { } 1 { } {
                // Load the offset to this Execution struct
                let executionOffset := add(calls.offset, calldataload(ptr))

                // Load target (first field)
                let target := calldataload(executionOffset)

                // Load value (second field)
                let value := calldataload(add(executionOffset, 0x20))

                // Load callData offset (third field)
                let callDataOffset := calldataload(add(executionOffset, 0x40))

                // Calculate actual callData location
                let callDataPtr := add(executionOffset, callDataOffset)
                let callDataLen := calldataload(callDataPtr)
                let callDataStart := add(callDataPtr, 0x20)

                // Copy calldata to memory
                calldatacopy(0x00, callDataStart, callDataLen)

                // Execute the call
                if iszero(call(gas(), target, value, 0x00, callDataLen, 0x00, 0x00)) {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }

                // Move to next offset pointer
                ptr := add(ptr, 0x20)

                // Break if we've processed all calls
                if iszero(lt(ptr, end)) { break }
            }
        }
    }

    /* //////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to receive ETH.
    receive() external payable { }

    /* //////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets approval for the Warp Routerr to spend tokens.
    /// @param tokenAmount The array of TokenAmount structs containing token addresses and amounts.
    /// @param router The address of the Warp Routerr.
    function _setApprovalForRouter(TokenAmount[] calldata tokenAmount, address router) internal {
        uint256 length = tokenAmount.length;
        // Iterate through the array of TokenAmount structs
        for (uint256 i; i < length;) {
            address token = tokenAmount[i].token;
            uint256 amount = tokenAmount[i].amount;
            // Set approval for each token to the Warp Routerr
            token.safeApprove(router, amount);
            // Emit the Approved event
            emit Approved(token, amount, router);
            unchecked {
                i++;
            }
        }
    }
}
