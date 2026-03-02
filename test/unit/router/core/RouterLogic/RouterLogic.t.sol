// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { Test } from "forge-std/Test.sol";

// Contracts
import { MockRouterLogic } from "test/utils/mocks/MockRouterLogic.sol";
import { MockAdapter } from "test/utils/mocks/MockAdapter.sol";
import { MockERC20 } from "src/tests/MockERC20.sol";

// Libraries
import { AdapterLib } from "src/router/lib/AdapterLib.sol";
import { RouterManagerStorageLib, AdapterConfig } from "src/router/lib/RouterStorageLib.sol";

// Constants
import { Constants } from "src/types/Constants.sol";

contract RouterLogic_Unit_Test is Test {
    /* //////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    MockAdapter internal mockFillAdapter;
    MockAdapter internal mockClaimAdapter;

    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC20 internal token3;

    MockRouterLogic internal routerLogic;

    address internal atomicSigner;
    uint256 internal atomicSignerPk;

    address internal adapterAdder;
    address internal adapterRemover;

    address internal solver;
    address internal recipient;
    address internal user;

    bytes4 internal constant MOCK_FILL_SELECTOR = bytes4(keccak256("mockFill(bytes32,address,uint256[2][])"));
    bytes4 internal constant MOCK_CLAIM_SELECTOR = bytes4(keccak256("mockClaim(bytes32,address,uint256[2][])"));

    /* //////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Set up addresses using proper private keys for signing
        atomicSignerPk = 0xA11CE;
        atomicSigner = vm.addr(atomicSignerPk);

        adapterAdder = makeAddr("adapterAdder");
        adapterRemover = makeAddr("adapterRemover");
        solver = makeAddr("solver");
        recipient = makeAddr("recipient");
        user = makeAddr("user");

        // Deploy MockRouterLogic (exposes internal functions)
        routerLogic = new MockRouterLogic(atomicSigner, adapterAdder, adapterRemover);

        // Deploy mock adapters
        mockFillAdapter = new MockAdapter(address(routerLogic), address(0));
        mockClaimAdapter = new MockAdapter(address(routerLogic), address(0));

        // Deploy mock tokens
        token1 = new MockERC20("Token1", "TK1", 18);
        token2 = new MockERC20("Token2", "TK2", 18);
        token3 = new MockERC20("Token3", "TK3", 18);

        vm.label(address(routerLogic), "RouterLogic");
        vm.label(address(mockFillAdapter), "MockFillAdapter");
        vm.label(address(mockClaimAdapter), "MockClaimAdapter");
        vm.label(address(token1), "Token1");
        vm.label(address(token2), "Token2");
        vm.label(address(token3), "Token3");

        // Fund test accounts
        token1.mint(solver, 1000 ether);
        token2.mint(solver, 1000 ether);
        token3.mint(solver, 1000 ether);

        token1.mint(user, 1000 ether);
        token2.mint(user, 1000 ether);
        token3.mint(user, 1000 ether);

        // Deal ETH to various accounts
        vm.deal(solver, 10 ether);
        vm.deal(user, 10 ether);
        vm.deal(address(routerLogic), 10 ether);

        // Install adapters
        vm.startPrank(adapterAdder);
        routerLogic.installFillAdapter(bytes2(0x0001), MOCK_FILL_SELECTOR, address(mockFillAdapter));
        routerLogic.installClaimAdapter(bytes2(0x0001), MOCK_CLAIM_SELECTOR, address(mockClaimAdapter));
        vm.stopPrank();
    }

    /* //////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createBasicTokenOut() internal view returns (uint256[2][] memory) {
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(token1))), 100 ether];
        return tokenOut;
    }

    function _createMultipleTokenOut() internal view returns (uint256[2][] memory) {
        uint256[2][] memory tokenOut = new uint256[2][](2);
        tokenOut[0] = [uint256(uint160(address(token1))), 50 ether];
        tokenOut[1] = [uint256(uint160(address(token2))), 75 ether];
        return tokenOut;
    }

    function _createSolverContext(bytes32 nonce) internal pure returns (bytes memory) {
        return abi.encode(nonce, "solverData");
    }

    function _signAtomicFill(bytes memory encodedCalldata) internal view returns (bytes memory) {
        bytes32 hash = keccak256(encodedCalldata);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(atomicSignerPk, hash);
        return abi.encodePacked(r, s, v);
    }

    function _signAtomicFillWithKey(uint256 privateKey, bytes memory encodedCalldata) internal pure returns (bytes memory) {
        bytes32 hash = keccak256(encodedCalldata);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }

    function _approveTokens(address from, address spender, uint256 amount) internal {
        vm.startPrank(from);
        token1.approve(spender, amount);
        token2.approve(spender, amount);
        token3.approve(spender, amount);
        vm.stopPrank();
    }

    function _createAdapterCalldata(
        bytes4 selector,
        bytes32 nonce,
        address recip,
        uint256[2][] memory tokenOut
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(selector, nonce, recip, tokenOut);
    }
}
