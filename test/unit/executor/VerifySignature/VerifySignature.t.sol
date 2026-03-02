// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { ValidateSignature } from "src/executor/VerifySignature/VerifySignature.sol";
import { SmartExecutionLib } from "@rhinestone/compact-utils/src/common/SmartExecutionLib.sol";
import { Types } from "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import { IEmissary } from "@rhinestone/compact-utils/src/interfaces/IEmissary.sol";
import { ISmartSessionEmissary } from "@rhinestone/compact-utils/src/interfaces/ISmartSessionEmissary.sol";
import { ITheCompact } from "the-compact/interfaces/ITheCompact.sol";
import { EmissaryStatus } from "the-compact/types/EmissaryStatus.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

/* //////////////////////////////////////////////////////////////
                            MOCKS
//////////////////////////////////////////////////////////////*/

/// @notice Mock TheCompact that returns configurable emissary status
contract MockTheCompactForVerify {
    address public emissaryToReturn;
    bool public shouldRevert;

    function setEmissary(address _emissary) external {
        emissaryToReturn = _emissary;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function getEmissaryStatus(address, bytes12) external view returns (EmissaryStatus, uint256, address) {
        if (shouldRevert) revert("getEmissaryStatus reverted");
        return (EmissaryStatus.Enabled, 0, emissaryToReturn);
    }
}

/// @notice Mock Emissary with configurable verifyClaim return
contract MockEmissaryForVerify is IEmissary {
    bool public shouldReturnValid;
    bool public shouldRevert;

    function setValid(bool _valid) external {
        shouldReturnValid = _valid;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function verifyClaim(address, bytes32, bytes32, bytes calldata, bytes12) external view override returns (bytes4) {
        if (shouldRevert) revert("verifyClaim reverted");
        return shouldReturnValid ? this.verifyClaim.selector : bytes4(0xFFFFFFFF);
    }
}

/// @notice Mock SmartSessionEmissary with configurable verifyExecution return
contract MockSmartSessionEmissaryForVerify is ISmartSessionEmissary {
    bool public shouldReturnValid;
    bool public shouldRevert;

    function setValid(bool _valid) external {
        shouldReturnValid = _valid;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function verifyExecution(address, bytes32, bytes calldata, Types.Operation calldata) external view override returns (bytes4) {
        if (shouldRevert) revert("verifyExecution reverted");
        return shouldReturnValid ? this.verifyExecution.selector : bytes4(0xFFFFFFFF);
    }
}

/// @notice Mock account implementing ERC-1271
contract Mock1271AccountForVerify is IERC1271 {
    bool public sigIsValid;

    constructor(bool _isValid) {
        sigIsValid = _isValid;
    }

    function setSigIsValid(bool _isValid) external {
        sigIsValid = _isValid;
    }

    function isValidSignature(bytes32, bytes memory) external view override returns (bytes4) {
        return sigIsValid ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @notice Test harness that exposes ValidateSignature._isValidSignature
contract TestValidateSignature is ValidateSignature {
    constructor(address compact, address smartSessionEmissary) ValidateSignature(compact, smartSessionEmissary) { }

    function isValidSignature(
        address account,
        bytes12 lockTag,
        bytes32 digest,
        bytes32 claimHash,
        Types.Operation calldata ops,
        bytes calldata signature
    )
        external
        returns (bool)
    {
        return _isValidSignature(account, lockTag, digest, claimHash, ops, signature);
    }
}

/* //////////////////////////////////////////////////////////////
                            BASE TEST
//////////////////////////////////////////////////////////////*/

contract VerifySignature_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                               STATE
    //////////////////////////////////////////////////////////////*/

    TestValidateSignature internal verifier;
    MockTheCompactForVerify internal mockCompact;
    MockEmissaryForVerify internal mockEmissary;
    MockSmartSessionEmissaryForVerify internal mockSmartSessionEmissary;
    Mock1271AccountForVerify internal validAccount;
    Mock1271AccountForVerify internal invalidAccount;

    bytes12 internal lockTag = bytes12(uint96(0x123456));
    bytes32 internal digest = keccak256("test digest");
    bytes32 internal claimHash = keccak256("test claim");
    bytes internal defaultSig = hex"aabbccdd";

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        mockCompact = new MockTheCompactForVerify();
        mockEmissary = new MockEmissaryForVerify();
        mockSmartSessionEmissary = new MockSmartSessionEmissaryForVerify();

        verifier = new TestValidateSignature(address(mockCompact), address(mockSmartSessionEmissary));

        validAccount = new Mock1271AccountForVerify(true);
        invalidAccount = new Mock1271AccountForVerify(false);

        // Default: emissary returns valid, and is configured
        mockEmissary.setValid(true);
        mockCompact.setEmissary(address(mockEmissary));
        mockSmartSessionEmissary.setValid(true);
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildOps(SmartExecutionLib.SigMode sigMode) internal pure returns (Types.Operation memory) {
        return Types.Operation({
            data: abi.encodePacked(uint8(SmartExecutionLib.Type.ERC7579), uint8(sigMode), hex"00")
        });
    }
}
