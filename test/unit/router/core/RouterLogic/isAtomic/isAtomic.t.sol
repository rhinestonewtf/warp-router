// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Base
import { RouterLogic_Unit_Test } from "../RouterLogic.t.sol";

// Contracts
import { IRouter } from "src/interfaces/IRouter.sol";
import { MockRouterLogic } from "test/utils/mocks/MockRouterLogic.sol";

contract RouterLogic_IsAtomic_Unit_Test is RouterLogic_Unit_Test {
    /* //////////////////////////////////////////////////////////////
                            VALID SIGNATURE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isAtomic_ValidSignature_ReturnsTrue() public {
        bytes memory data = abi.encode("test data");
        bytes32 hash = keccak256(data);
        bytes memory signature = _signAtomicFill(data);

        bool result = routerLogic.exposed_isAtomic(hash, signature);
        assertTrue(result);
    }

    function test_isAtomic_ValidSignature_ThroughRouteFill_Succeeds() public {
        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory atomicSig = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, atomicSig);
    }

    function test_isAtomic_DifferentValidSigner_ReturnsTrue() public {
        // Create a different signer with known private key
        uint256 newSignerPk = 0xB0B;
        address newSigner = vm.addr(newSignerPk);

        MockRouterLogic newRouter = new MockRouterLogic(newSigner, adapterAdder, adapterRemover);

        bytes memory data = abi.encode("test data");
        bytes32 hash = keccak256(data);
        bytes memory signature = _signAtomicFillWithKey(newSignerPk, data);

        bool result = newRouter.exposed_isAtomic(hash, signature);
        assertTrue(result);
    }

    function test_isAtomic_MultipleValidSignatures_AllReturnTrue() public {
        bytes memory data1 = abi.encode("data1");
        bytes memory data2 = abi.encode("data2");
        bytes memory data3 = abi.encode("data3");

        bytes32 hash1 = keccak256(data1);
        bytes32 hash2 = keccak256(data2);
        bytes32 hash3 = keccak256(data3);

        bytes memory sig1 = _signAtomicFill(data1);
        bytes memory sig2 = _signAtomicFill(data2);
        bytes memory sig3 = _signAtomicFill(data3);

        assertTrue(routerLogic.exposed_isAtomic(hash1, sig1));
        assertTrue(routerLogic.exposed_isAtomic(hash2, sig2));
        assertTrue(routerLogic.exposed_isAtomic(hash3, sig3));
    }

    /* //////////////////////////////////////////////////////////////
                            INVALID SIGNATURE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isAtomic_RevertsWhen_WrongSigner() public {
        uint256 wrongSignerPk = 0xBAD;
        address wrongSigner = vm.addr(wrongSignerPk);

        vm.assume(wrongSigner != atomicSigner);

        bytes memory data = abi.encode("test data");
        bytes32 hash = keccak256(data);
        bytes memory wrongSignature = _signAtomicFillWithKey(wrongSignerPk, data);

        assertFalse(routerLogic.exposed_isAtomic(hash, wrongSignature));
    }

    function test_isAtomic_RevertsWhen_WrongSignerThroughRouteFill() public {
        uint256 wrongSignerPk = 0xBAD;

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory wrongSignature = _signAtomicFillWithKey(wrongSignerPk, encodedCalldata);

        _approveTokens(solver, address(routerLogic), 1000 ether);

        vm.expectRevert(IRouter.InvalidAtomicity.selector);
        vm.prank(solver);
        routerLogic.optimized_routeFill921336808(solverContexts, encodedCalldata, wrongSignature);
    }

    function test_isAtomic_RevertsWhen_SignatureForDifferentData() public {
        bytes memory wrongData = abi.encode("different data");
        bytes memory rightData = abi.encode("right data");

        bytes32 rightHash = keccak256(rightData);
        bytes memory signatureForWrongData = _signAtomicFill(wrongData);

        assertFalse(routerLogic.exposed_isAtomic(rightHash, signatureForWrongData));
    }

    function test_isAtomic_RevertsWhen_MalformedSignature() public {
        bytes memory data = abi.encode("test data");
        bytes32 hash = keccak256(data);
        bytes memory malformedSignature = hex"1234"; // Too short

        vm.expectRevert();
        routerLogic.exposed_isAtomic(hash, malformedSignature);
    }

    function test_isAtomic_RevertsWhen_EmptySignature() public {
        bytes memory data = abi.encode("test data");
        bytes32 hash = keccak256(data);
        bytes memory emptySignature = "";

        vm.expectRevert();
        routerLogic.exposed_isAtomic(hash, emptySignature);
    }

    function test_isAtomic_RevertsWhen_InvalidSignatureLength() public {
        bytes memory data = abi.encode("test data");
        bytes32 hash = keccak256(data);

        // Valid signature is 65 bytes, try various wrong lengths
        bytes memory sig32 = new bytes(32);
        bytes memory sig64 = new bytes(64);
        bytes memory sig66 = new bytes(66);

        vm.expectRevert();
        routerLogic.exposed_isAtomic(hash, sig32);

        vm.expectRevert();
        routerLogic.exposed_isAtomic(hash, sig64);

        vm.expectRevert();
        routerLogic.exposed_isAtomic(hash, sig66);
    }

    /* //////////////////////////////////////////////////////////////
                            SIGNER NOT SET TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isAtomic_RevertsWhen_AtomicSignerIsZero() public {
        // Deploy router with zero address as atomic signer
        MockRouterLogic pausedRouter = new MockRouterLogic(address(0), adapterAdder, adapterRemover);

        bytes memory data = abi.encode("test data");
        bytes32 hash = keccak256(data);
        bytes memory signature = _signAtomicFill(data);

        vm.expectRevert(IRouter.AtomicSignerNotSet.selector);
        pausedRouter.exposed_isAtomic(hash, signature);
    }

    function test_isAtomic_RevertsWhen_AtomicSignerIsZero_ThroughRouteFill() public {
        MockRouterLogic pausedRouter = new MockRouterLogic(address(0), adapterAdder, adapterRemover);

        vm.startPrank(adapterAdder);
        pausedRouter.installFillAdapter(bytes2(0x0001), MOCK_FILL_SELECTOR, address(mockFillAdapter));
        vm.stopPrank();

        bytes[] memory solverContexts = new bytes[](1);
        solverContexts[0] = _createSolverContext(keccak256("nonce1"));

        bytes[] memory adapterCalldatas = new bytes[](1);
        adapterCalldatas[0] = _createAdapterCalldata(MOCK_FILL_SELECTOR, keccak256("nonce1"), recipient, _createBasicTokenOut());

        bytes memory encodedCalldata = abi.encode(adapterCalldatas);
        bytes memory signature = _signAtomicFill(encodedCalldata);

        _approveTokens(solver, address(pausedRouter), 1000 ether);

        vm.expectRevert(IRouter.AtomicSignerNotSet.selector);
        vm.prank(solver);
        pausedRouter.optimized_routeFill921336808(solverContexts, encodedCalldata, signature);
    }

    /* //////////////////////////////////////////////////////////////
                        HASH VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isAtomic_DifferentHashesSameData_ReturnsFalse() public {
        bytes memory data = abi.encode("test data");
        bytes32 correctHash = keccak256(data);
        bytes32 wrongHash = keccak256("wrong");
        bytes memory signature = _signAtomicFill(data);

        assertTrue(routerLogic.exposed_isAtomic(correctHash, signature));
        assertFalse(routerLogic.exposed_isAtomic(wrongHash, signature));
    }

    function test_isAtomic_ZeroHash_ValidSignature() public {
        bytes memory data = "";
        bytes32 zeroHash = keccak256(data);
        bytes memory signature = _signAtomicFill(data);

        assertTrue(routerLogic.exposed_isAtomic(zeroHash, signature));
    }

    /* //////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_isAtomic_ValidSignature(bytes memory data) public {
        vm.assume(data.length > 0 && data.length < 10_000);

        bytes32 hash = keccak256(data);
        bytes memory signature = _signAtomicFill(data);

        assertTrue(routerLogic.exposed_isAtomic(hash, signature));
    }

    function testFuzz_isAtomic_RevertsWhen_WrongSigner(uint256 wrongPk, bytes memory data) public {
        wrongPk = bound(wrongPk, 1, type(uint160).max);
        vm.assume(wrongPk != atomicSignerPk);
        vm.assume(data.length > 0 && data.length < 1000);

        address wrongSigner = vm.addr(wrongPk);
        vm.assume(wrongSigner != atomicSigner);

        bytes32 hash = keccak256(data);
        bytes memory wrongSignature = _signAtomicFillWithKey(wrongPk, data);

        assertFalse(routerLogic.exposed_isAtomic(hash, wrongSignature));
    }

    function testFuzz_isAtomic_SignatureForWrongData(bytes memory rightData, bytes memory wrongData) public {
        vm.assume(rightData.length > 0 && rightData.length < 1000);
        vm.assume(wrongData.length > 0 && wrongData.length < 1000);
        vm.assume(keccak256(rightData) != keccak256(wrongData));

        bytes32 rightHash = keccak256(rightData);
        bytes memory signatureForWrongData = _signAtomicFill(wrongData);

        assertFalse(routerLogic.exposed_isAtomic(rightHash, signatureForWrongData));
    }
}
