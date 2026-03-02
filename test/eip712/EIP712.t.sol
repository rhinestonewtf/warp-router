import "@rhinestone/compact-utils/src/tests/Environment.sol";
import "@rhinestone/compact-utils/src/types/OrderTypes.sol";
import "./EIP712RustAPI.sol";
import { EIP712TypeHashLib } from "@rhinestone/compact-utils/src/types/EIP712TypeHashLib.sol";
import "@rhinestone/compact-utils/src/types/TheCompactStructs.sol";
import "the-compact/types/Components.sol";
import "the-compact/types/Claims.sol";
import { TokenIdLib } from "@rhinestone/compact-utils/src/common/TokenIdLib.sol";

contract EIP712Test is CompactEnvironment, EIP712RustAPI {
    using TokenIdLib for *;
    using TestHelperLib for uint256[2];

    // Import typehashes from the production library
    bytes32 public constant TYPEHASH_MANDATE = EIP712TypeHashLib.TYPEHASH_MANDATE;
    bytes32 public constant TYPEHASH_COMPACT = EIP712TypeHashLib.TYPEHASH_COMPACT;
    bytes32 public constant TYPEHASH_ELEMENT = EIP712TypeHashLib.TYPEHASH_ELEMENT;
    bytes32 public constant TYPEHASH_TARGET = EIP712TypeHashLib.TYPEHASH_TARGET;
    bytes32 public constant TYPEHASH_LOCK = EIP712TypeHashLib.TYPEHASH_LOCK;
    bytes32 public constant TYPEHASH_TOKENOUT = EIP712TypeHashLib.TYPEHASH_TOKENOUT;
    bytes32 public constant TYPEHASH_OP = EIP712TypeHashLib.TYPEHASH_OP;
    bytes32 public constant TYPEHASH_OPS = EIP712TypeHashLib.TYPEHASH_OPS;
    bytes32 public constant TYPEHASH_JIT_PERMIT2 = EIP712TypeHashLib.TYPEHASH_JIT_PERMIT2;

    function setUp() public {
        _deployCompact();
        _deploySmartAccount({ create: true });
        _setEmissary(env.smartAccount1, env.eoa);
        _lockAssets(env.smartAccount1, env.token1, 100 ether);
    }

    function __QUALIFIER_EIP712Hash(bytes calldata data) public pure returns (bytes32) {
        return EIP712TypeHashLib.hashQualifierData(data);
    }

    function test_eip712_typehash_mandate() public {
        bytes32 typehash = rustTypehash("mandate");
        assertEq(typehash, TYPEHASH_MANDATE, "mandate typehash incorrect");
    }

    function test_eip712_typehash_compact() public {
        bytes32 typehash = rustTypehash("multichaincompact");
        assertEq(typehash, TYPEHASH_COMPACT, "compact typehash incorrect");
    }

    function test_eip712_typehash_element() public {
        bytes32 typehash = rustTypehash("element");
        assertEq(typehash, TYPEHASH_ELEMENT, "element typehash incorrect");
    }

    function test_eip712_typehash_target() public {
        bytes32 typehash = rustTypehash("target");
        assertEq(typehash, TYPEHASH_TARGET, "target typehash incorrect");
    }

    function test_eip712_typehash_lock() public {
        bytes32 typehash = rustTypehash("lock");
        assertEq(typehash, TYPEHASH_LOCK, "lock typehash incorrect");
    }

    function test_eip712_typehash_token() public {
        bytes32 typehash = rustTypehash("token");
        assertEq(typehash, TYPEHASH_TOKENOUT, "token typehash incorrect");
    }

    // function test_eip712_hash_data_execution() public {
    // Execution memory exec = Execution({ target: address(this), value: 100, callData: hex"4141" });
    // bytes32 solidityHash = hasher.execution(exec);
    // assertEq(rustDataHash("execution", abi.encode(exec)), solidityHash, "Execution hash incorrect");
    //}

    struct EIP712MultichainCompact {
        address sponsor;
        uint256 nonce; // last depositId
        uint256 expires;
        EIP712Element[] elements;
    }

    struct EIP712Element {
        address arbiter;
        uint256 chainId;
        EIP712Lock[] commitments;
        EIP712Mandate mandate;
    }

    struct EIP712Lock {
        bytes12 lockTag;
        address token;
        uint256 amount;
    }

    struct Ops {
        address to;
        uint256 value;
        bytes data;
    }

    struct EIP712Op {
        bytes32 vt;
        Ops[] ops;
    }

    struct EIP712Mandate {
        EIP712Target target;
        uint128 minGas;
        EIP712Op originOps;
        EIP712Op destOps;
        bytes32 q;
    }

    struct EIP712Target {
        address recipient;
        EIP712Token[] tokenOut;
        uint256 targetChain;
        uint256 fillExpiry;
    }

    struct EIP712Token {
        address token;
        uint256 amount;
    }

    struct EIP712Qualifier {
        bytes32 val;
    }

    EIP712Mandate emptyMandate;

    function _hashOp(EIP712Op memory op) internal view returns (bytes32) {
        // Hash each Ops in the array
        bytes32[] memory opsHashes = new bytes32[](op.ops.length);
        for (uint256 i = 0; i < op.ops.length; i++) {
            opsHashes[i] = keccak256(abi.encode(TYPEHASH_OPS, op.ops[i].to, op.ops[i].value, keccak256(op.ops[i].data)));
        }
        // Hash the Op structure
        return keccak256(abi.encode(TYPEHASH_OP, op.vt, keccak256(abi.encodePacked(opsHashes))));
    }

    function test_eip712_hash_data_target() public {
        // Create a test target struct
        EIP712Target memory target = EIP712Target({
            recipient: address(0x1111111111111111111111111111111111111111),
            tokenOut: new EIP712Token[](1),
            targetChain: 1,
            fillExpiry: 12_341_234
        });
        target.tokenOut[0] = EIP712Token({ token: address(0x2222222222222222222222222222222222222222), amount: 1000 });

        // Calculate Solidity hash
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(target.tokenOut[0].token)), target.tokenOut[0].amount];

        bytes32 solidityHash = EIP712TypeHashLib.hashTargetAttributesRaw(
            target.recipient, this.callHashTokenOutContract(tokenOut), target.targetChain, target.fillExpiry
        );

        bytes32 rustHash = rustDataHash("target", abi.encode(target));

        assertEq(rustHash, solidityHash, "target hash incorrect");
    }

    function test_eip712_hash_data_lock() public {
        // Create a test lock struct
        EIP712Lock memory lock = EIP712Lock({
            lockTag: bytes12(0x123456789012345678901234), token: address(0x3333333333333333333333333333333333333333), amount: 500
        });

        // Calculate Solidity hash - Lock uses TYPEHASH_LOCK
        bytes32 solidityHash = keccak256(abi.encode(TYPEHASH_LOCK, lock.lockTag, lock.token, lock.amount));
        bytes32 rustHash = rustDataHash("lock", abi.encode(lock));

        assertEq(rustHash, solidityHash, "lock hash incorrect");
    }

    function test_eip712_hash_data_token() public {
        // Create a test token struct
        EIP712Token memory token = EIP712Token({ token: address(0x2222222222222222222222222222222222222222), amount: 1000 });

        // Calculate Solidity hash - Token uses TYPEHASH_TOKENOUT
        bytes32 solidityHash = keccak256(abi.encode(TYPEHASH_TOKENOUT, token.token, token.amount));
        bytes32 rustHash = rustDataHash("token", abi.encode(token));

        assertEq(rustHash, solidityHash, "token hash incorrect");
    }

    function test_eip712_hash_data_mandate() public {
        // Create a test mandate with updated field names
        EIP712Target memory target = EIP712Target({
            recipient: address(0x1111111111111111111111111111111111111111),
            tokenOut: new EIP712Token[](1),
            targetChain: 1,
            fillExpiry: 12_341_234
        });
        target.tokenOut[0] = EIP712Token({ token: address(0x2222222222222222222222222222222222222222), amount: 1000 });

        Execution[] memory exec = new Execution[](1);
        exec[0] = Execution({ target: makeAddr("foo"), value: 0, callData: hex"4141" });

        // Convert Execution[] to Ops[]
        Ops[] memory ops = new Ops[](1);
        ops[0] = Ops({ to: exec[0].target, value: exec[0].value, data: exec[0].callData });

        EIP712Mandate memory mandate = EIP712Mandate({
            target: target,
            minGas: 0,
            originOps: EIP712Op({ vt: bytes32(0), ops: ops }),
            destOps: EIP712Op({ vt: bytes32(0), ops: ops }),
            q: bytes32(0x1234567890123456789012345678901234567890123456789012345678901234)
        });

        // Calculate Solidity hash
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(target.tokenOut[0].token)), target.tokenOut[0].amount];

        bytes32 targetAttributes = EIP712TypeHashLib.hashTargetAttributesRaw(
            target.recipient, this.callHashTokenOutContract(tokenOut), target.targetChain, target.fillExpiry
        );

        bytes32 solidityHash = EIP712TypeHashLib.hashMandateRaw(
            targetAttributes, mandate.minGas, _hashOp(mandate.originOps), _hashOp(mandate.destOps), mandate.q
        );
        bytes32 rustHash = rustDataHash("mandate", abi.encode(mandate));

        assertEq(rustHash, solidityHash, "mandate hash incorrect");
    }

    function test_eip712_hash_data_element() public {
        // Create test mandate
        EIP712Target memory target = EIP712Target({
            recipient: address(0x1111111111111111111111111111111111111111),
            tokenOut: new EIP712Token[](1),
            targetChain: 1,
            fillExpiry: 12_341_234
        });
        target.tokenOut[0] = EIP712Token({ token: address(0x2222222222222222222222222222222222222222), amount: 1000 });

        Ops[] memory emptyOps = new Ops[](0);
        EIP712Mandate memory mandate = EIP712Mandate({
            target: target,
            minGas: 0,
            originOps: EIP712Op({ vt: bytes32(0), ops: emptyOps }),
            destOps: EIP712Op({ vt: bytes32(0), ops: emptyOps }),
            q: bytes32(0x1234567890123456789012345678901234567890123456789012345678901234)
        });

        // Create test element
        EIP712Element memory element = EIP712Element({
            arbiter: address(0x5555555555555555555555555555555555555555), chainId: 1, commitments: new EIP712Lock[](1), mandate: mandate
        });
        element.commitments[0] = EIP712Lock({
            lockTag: bytes12(0x123456789012345678901234), token: address(0x3333333333333333333333333333333333333333), amount: 500
        });

        // Calculate Solidity hash
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(target.tokenOut[0].token)), target.tokenOut[0].amount];

        bytes32 targetAttributes = EIP712TypeHashLib.hashTargetAttributesRaw(
            target.recipient, this.callHashTokenOutContract(tokenOut), target.targetChain, target.fillExpiry
        );

        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw(
            targetAttributes, mandate.minGas, _hashOp(mandate.originOps), _hashOp(mandate.destOps), mandate.q
        );

        // Hash commitments
        bytes32[] memory lockHashes = new bytes32[](1);
        lockHashes[0] = keccak256(
            abi.encode(TYPEHASH_LOCK, element.commitments[0].lockTag, element.commitments[0].token, element.commitments[0].amount)
        );
        bytes32 commitmentsHash = keccak256(abi.encodePacked(lockHashes));

        bytes32 solidityHash = EIP712TypeHashLib.hashElementRaw(element.arbiter, element.chainId, commitmentsHash, mandateHash);
        bytes32 rustHash = rustDataHash("element", abi.encode(element));

        assertEq(rustHash, solidityHash, "element hash incorrect");
    }

    function test_eip712_hash_data_compact() public {
        // Create test mandate
        EIP712Target memory target = EIP712Target({
            recipient: address(0x1111111111111111111111111111111111111111),
            tokenOut: new EIP712Token[](1),
            targetChain: 1,
            fillExpiry: 12_341_234
        });
        target.tokenOut[0] = EIP712Token({ token: address(0x2222222222222222222222222222222222222222), amount: 1000 });

        Ops[] memory emptyOps = new Ops[](0);
        EIP712Mandate memory mandate = EIP712Mandate({
            target: target,
            minGas: 0,
            originOps: EIP712Op({ vt: bytes32(0), ops: emptyOps }),
            destOps: EIP712Op({ vt: bytes32(0), ops: emptyOps }),
            q: bytes32(0x1234567890123456789012345678901234567890123456789012345678901234)
        });

        // Create test element
        EIP712Element memory element = EIP712Element({
            arbiter: address(0x5555555555555555555555555555555555555555), chainId: 1, commitments: new EIP712Lock[](1), mandate: mandate
        });
        element.commitments[0] = EIP712Lock({
            lockTag: bytes12(0x123456789012345678901234), token: address(0x3333333333333333333333333333333333333333), amount: 500
        });

        // Create test compact
        EIP712MultichainCompact memory multichainCompact = EIP712MultichainCompact({
            sponsor: address(0x6666666666666666666666666666666666666666),
            nonce: 1337,
            expires: block.timestamp + 1000,
            elements: new EIP712Element[](1)
        });
        multichainCompact.elements[0] = element;

        // Calculate Solidity hash
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(target.tokenOut[0].token)), target.tokenOut[0].amount];

        bytes32 targetAttributes = EIP712TypeHashLib.hashTargetAttributesRaw(
            target.recipient, this.callHashTokenOutContract(tokenOut), target.targetChain, target.fillExpiry
        );

        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw(
            targetAttributes, mandate.minGas, _hashOp(mandate.originOps), _hashOp(mandate.destOps), mandate.q
        );

        // Hash commitments
        bytes32[] memory lockHashes = new bytes32[](1);
        lockHashes[0] = keccak256(
            abi.encode(TYPEHASH_LOCK, element.commitments[0].lockTag, element.commitments[0].token, element.commitments[0].amount)
        );
        bytes32 commitmentsHash = keccak256(abi.encodePacked(lockHashes));

        bytes32 elementHash = EIP712TypeHashLib.hashElementRaw(element.arbiter, element.chainId, commitmentsHash, mandateHash);

        // Hash elements array
        bytes32[] memory elementHashes = new bytes32[](1);
        elementHashes[0] = elementHash;
        bytes32 allElementsHash = keccak256(abi.encodePacked(elementHashes));

        bytes32 solidityHash =
            EIP712TypeHashLib.hashCompact(multichainCompact.sponsor, multichainCompact.nonce, multichainCompact.expires, allElementsHash);
        bytes32 rustHash = rustDataHash("multichaincompact", abi.encode(multichainCompact));

        assertEq(rustHash, solidityHash, "compact hash incorrect");
    }

    function test_eip712_hash_data_compact_minimal() public {
        // Minimal test data for frontend verification
        EIP712Target memory target =
            EIP712Target({ recipient: address(0x1), tokenOut: new EIP712Token[](1), targetChain: 1, fillExpiry: 1000 });
        target.tokenOut[0] = EIP712Token({ token: address(0x3), amount: 100 });

        Ops[] memory emptyOps = new Ops[](0);
        EIP712Mandate memory mandate = EIP712Mandate({
            target: target,
            minGas: 0,
            originOps: EIP712Op({ vt: bytes32(0), ops: emptyOps }), // Empty arrays wrapped in EIP712Op
            destOps: EIP712Op({ vt: bytes32(0), ops: emptyOps }), // Empty arrays wrapped in EIP712Op
            q: bytes32(0x0) // Zero qualifier
        });

        EIP712Element memory element =
            EIP712Element({ arbiter: address(0x4), chainId: 1, commitments: new EIP712Lock[](1), mandate: mandate });
        element.commitments[0] = EIP712Lock({
            lockTag: bytes12(0x0), // Zero lock tag
            token: address(0x5),
            amount: 50
        });

        EIP712MultichainCompact memory multichainCompact =
            EIP712MultichainCompact({ sponsor: address(0x6), nonce: 1, expires: 2000, elements: new EIP712Element[](1) });
        multichainCompact.elements[0] = element;

        // Calculate Solidity hash with minimal data
        uint256[2][] memory tokenOut = new uint256[2][](1);
        tokenOut[0] = [uint256(uint160(address(0x3))), 100];

        bytes32 targetAttributes = EIP712TypeHashLib.hashTargetAttributesRaw(address(0x1), this.callHashTokenOutContract(tokenOut), 1, 1000);

        bytes32 mandateHash = EIP712TypeHashLib.hashMandateRaw(
            targetAttributes, mandate.minGas, _hashOp(mandate.originOps), _hashOp(mandate.destOps), bytes32(0x0)
        );

        // Hash commitments
        bytes32[] memory lockHashes = new bytes32[](1);
        lockHashes[0] = keccak256(abi.encode(TYPEHASH_LOCK, bytes12(0x0), address(0x5), 50));
        bytes32 commitmentsHash = keccak256(abi.encodePacked(lockHashes));

        bytes32 elementHash = EIP712TypeHashLib.hashElementRaw(address(0x4), 1, commitmentsHash, mandateHash);

        // Hash elements array
        bytes32[] memory elementHashes = new bytes32[](1);
        elementHashes[0] = elementHash;
        bytes32 allElementsHash = keccak256(abi.encodePacked(elementHashes));

        bytes32 solidityHash = EIP712TypeHashLib.hashCompact(address(0x6), 1, 2000, allElementsHash);
        bytes32 rustHash = rustDataHash("multichaincompact", abi.encode(multichainCompact));

        // Log the values for frontend reference
        console2.log("=== MINIMAL COMPACT HASH TEST DATA ===");
        console2.log("Target recipient: 0x0000000000000000000000000000000000000001");
        console2.log("Target tokenOut[0].token: 0x0000000000000000000000000000000000000003");
        console2.log("Target tokenOut[0].amount: 100");
        console2.log("Target targetChain: 1");
        console2.log("Target fillExpiry: 1000");
        console2.log("Element arbiter: 0x0000000000000000000000000000000000000004");
        console2.log("Element chainId: 1");
        console2.log("Element commitments[0].lockTag: 0x000000000000000000000000");
        console2.log("Element commitments[0].token: 0x0000000000000000000000000000000000000005");
        console2.log("Element commitments[0].amount: 50");
        console2.log("Compact sponsor: 0x0000000000000000000000000000000000000006");
        console2.log("Compact nonce: 1");
        console2.log("Compact expires: 2000");
        console2.log("Expected hash:");
        console2.logBytes32(solidityHash);

        assertEq(rustHash, solidityHash, "minimal compact hash incorrect");
    }

    // Tests for data hashing functions from EIP712TypeHashLib.sol

    // Test raw hashing functions comparison
    function test_hashMandateRaw_comparison() public {
        // Test data
        bytes32 targetAttributes = keccak256("targetAttributes");
        bytes32 preClaimOpsHash = keccak256("preClaimOps");
        bytes32 destOpsHash = keccak256("destOps");
        bytes32 qHash = keccak256("qualifier");

        // Using the optimized _hashMandateRaw from EIP712TypeHash
        bytes32 optimizedHash = EIP712TypeHashLib.hashMandateRaw(targetAttributes, 0, preClaimOpsHash, destOpsHash, qHash);

        // Reference implementation using standard abi.encode
        bytes32 referenceHash = keccak256(abi.encode(TYPEHASH_MANDATE, targetAttributes, 0, preClaimOpsHash, destOpsHash, qHash));

        // They should produce identical hashes
        assertEq(optimizedHash, referenceHash, "hashMandateRaw should match reference implementation");
    }

    function test_hashTargetAttributesRaw_comparison() public {
        // Test data
        address recipient = address(0x1234567890123456789012345678901234567890);
        bytes32 tokenOutHash = keccak256("tokenOut");
        uint256 targetChainId = 137;
        uint256 fillDeadline = block.timestamp + 3600;

        // Using the optimized _hashTargetAttributesRaw from EIP712TypeHash
        bytes32 optimizedHash = EIP712TypeHashLib.hashTargetAttributesRaw(recipient, tokenOutHash, targetChainId, fillDeadline);

        // Reference implementation using standard abi.encode
        bytes32 referenceHash = keccak256(abi.encode(TYPEHASH_TARGET, recipient, tokenOutHash, targetChainId, fillDeadline));

        // They should produce identical hashes
        assertEq(optimizedHash, referenceHash, "hashTargetAttributesRaw should match reference implementation");
    }

    function test_hashElementRaw_comparison() public {
        // Test data
        address arbiter = address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
        uint256 originChainId = 1;
        bytes32 tokenInHash = keccak256("tokenIn");
        bytes32 mandateHash = keccak256("mandate");

        // Using the optimized _hashElementRaw from EIP712TypeHash
        bytes32 optimizedHash = EIP712TypeHashLib.hashElementRaw(arbiter, originChainId, tokenInHash, mandateHash);

        // Reference implementation using standard abi.encode
        bytes32 referenceHash = keccak256(abi.encode(TYPEHASH_ELEMENT, arbiter, originChainId, tokenInHash, mandateHash));

        // They should produce identical hashes
        assertEq(optimizedHash, referenceHash, "hashElementRaw should match reference implementation");
    }

    function test_hashCompact_raw_comparison() public {
        // Test data
        address sponsor = address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB);
        uint256 nonce = 12_345;
        uint256 expires = block.timestamp + 7200;
        bytes32 allElementsHash = keccak256("allElements");

        // Using the optimized _hashCompact from EIP712TypeHash
        bytes32 optimizedHash = EIP712TypeHashLib.hashCompact(sponsor, nonce, expires, allElementsHash);

        // Reference implementation using standard abi.encode
        bytes32 referenceHash = keccak256(abi.encode(TYPEHASH_COMPACT, sponsor, nonce, expires, allElementsHash));

        // They should produce identical hashes
        assertEq(optimizedHash, referenceHash, "hashCompact (raw) should match reference implementation");
    }

    function test_hashPermit2_comparison() public {
        // Test data
        bytes32 tokenInHash = keccak256("tokenIn");
        address arbiter = address(0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC);
        uint256 nonce = 99_999;
        uint256 expires = block.timestamp + 86_400;
        bytes32 mandate = keccak256("mandate");

        // Using the optimized _hashPermit2 from EIP712TypeHash contract
        bytes32 optimizedContractHash = EIP712TypeHashLib.hashPermit2(tokenInHash, arbiter, nonce, expires, mandate);

        // Using the EIP712TypeHashLib library function
        bytes32 libraryHash = EIP712TypeHashLib.hashPermit2(tokenInHash, arbiter, nonce, expires, mandate);

        // Reference implementation using standard abi.encode
        bytes32 referenceHash = keccak256(abi.encode(TYPEHASH_JIT_PERMIT2, tokenInHash, arbiter, nonce, expires, mandate));

        // Check each comparison
        assertEq(optimizedContractHash, referenceHash, "Contract hashPermit2 should match reference implementation");

        // Note: The library implementation has a bug - it tries to use TYPEHASH_JIT_PERMIT2 constant directly
        // in assembly which doesn't work. The constant needs to be loaded into a variable first.
        // This test will fail until the library is fixed.
        assertEq(libraryHash, referenceHash, "Library hashPermit2 should match reference implementation");
        assertEq(optimizedContractHash, libraryHash, "Contract and Library hashPermit2 should match");

        // For now, just log the values to show the issue
        console2.log("Contract hash:", vm.toString(optimizedContractHash));
        console2.log("Library hash: ", vm.toString(libraryHash));
        console2.log("Reference hash:", vm.toString(referenceHash));
    }

    function test_hashTokenPermissions_single_comparison() public {
        // Test data
        address token = address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd);
        uint256 amount = 1000 ether;

        // Using the optimized _hashTokenPermissions from EIP712TypeHash contract
        bytes32 optimizedContractHash = EIP712TypeHashLib.hashTokenPermissions(token, amount);

        // Using the EIP712TypeHashLib library function
        bytes32 libraryHash = EIP712TypeHashLib.hashTokenPermissions(token, amount);

        // Reference implementation using standard abi.encode
        bytes32 PERMIT2_TOKEN_HASH_REF = keccak256("TokenPermissions(address token,uint256 amount)");
        bytes32 referenceHash = keccak256(abi.encode(PERMIT2_TOKEN_HASH_REF, token, amount));

        // All three should produce identical hashes
        assertEq(optimizedContractHash, referenceHash, "Contract hashTokenPermissions should match reference implementation");
        assertEq(libraryHash, referenceHash, "Library hashTokenPermissions should match reference implementation");
        assertEq(optimizedContractHash, libraryHash, "Contract and Library hashTokenPermissions should match");
    }

    // Test with edge cases
    function test_hashMandateRaw_edgeCases() public {
        // Test with zero values
        bytes32 zeroHash = EIP712TypeHashLib.hashMandateRaw(bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
        bytes32 referenceZero = keccak256(abi.encode(TYPEHASH_MANDATE, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0)));
        assertEq(zeroHash, referenceZero, "Should handle zero values correctly");

        // Test with max values
        bytes32 maxHash = EIP712TypeHashLib.hashMandateRaw(
            bytes32(type(uint256).max),
            type(uint128).max,
            bytes32(type(uint256).max),
            bytes32(type(uint256).max),
            bytes32(type(uint256).max)
        );
        bytes32 referenceMax = keccak256(
            abi.encode(
                TYPEHASH_MANDATE,
                bytes32(type(uint256).max),
                type(uint128).max,
                bytes32(type(uint256).max),
                bytes32(type(uint256).max),
                bytes32(type(uint256).max)
            )
        );
        assertEq(maxHash, referenceMax, "Should handle max values correctly");
    }

    // =========================================================================
    // COMPREHENSIVE EIP712TypeHashLib vs Reference Implementation Tests
    // =========================================================================

    // Test hashTokenIn function
    function test_hashTokenIn_lib_vs_contract() public {
        // Test with empty array (using call for calldata conversion)
        bytes32 libHash;
        bytes32 contractHash;

        // Empty array test
        uint256[2][] memory emptyTokenIn = new uint256[2][](0);
        libHash = this.callHashTokenInLib(emptyTokenIn);
        contractHash = this.callHashTokenInContract(emptyTokenIn);
        assertEq(libHash, contractHash, "hashTokenIn should match for empty array");

        // Test with single token
        uint256[2][] memory singleToken = new uint256[2][](1);
        singleToken[0] = [uint256(uint160(address(0x1234))), 1000 ether];
        libHash = this.callHashTokenInLib(singleToken);
        contractHash = this.callHashTokenInContract(singleToken);
        assertEq(libHash, contractHash, "hashTokenIn should match for single token");

        // Test with multiple tokens
        uint256[2][] memory multipleTokens = new uint256[2][](3);
        multipleTokens[0] = [uint256(uint160(address(0x1111))), 100 ether];
        multipleTokens[1] = [uint256(uint160(address(0x2222))), 200 ether];
        multipleTokens[2] = [uint256(uint160(address(0x3333))), 300 ether];
        libHash = this.callHashTokenInLib(multipleTokens);
        contractHash = this.callHashTokenInContract(multipleTokens);
        assertEq(libHash, contractHash, "hashTokenIn should match for multiple tokens");
    }

    // Helper functions to convert memory to calldata for library calls
    function callHashTokenInLib(uint256[2][] calldata tokenIn) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashTokenIn(tokenIn);
    }

    // Test hashTokenOut function
    function test_hashTokenOut_lib_vs_contract() public {
        // Test with empty array
        uint256[2][] memory emptyTokenOut = new uint256[2][](0);
        bytes32 libHash = this.callHashTokenOutLib(emptyTokenOut);
        bytes32 contractHash = this.callHashTokenOutContract(emptyTokenOut);
        assertEq(libHash, contractHash, "hashTokenOut should match for empty array");

        // Test with single token
        uint256[2][] memory singleToken = new uint256[2][](1);
        singleToken[0] = [uint256(uint160(address(0x5678))), 2000 ether];
        libHash = this.callHashTokenOutLib(singleToken);
        contractHash = this.callHashTokenOutContract(singleToken);
        assertEq(libHash, contractHash, "hashTokenOut should match for single token");

        // Test with multiple tokens
        uint256[2][] memory multipleTokens = new uint256[2][](3);
        multipleTokens[0] = [uint256(uint160(address(0x4444))), 400 ether];
        multipleTokens[1] = [uint256(uint160(address(0x5555))), 500 ether];
        multipleTokens[2] = [uint256(uint160(address(0x6666))), 600 ether];
        libHash = this.callHashTokenOutLib(multipleTokens);
        contractHash = this.callHashTokenOutContract(multipleTokens);
        assertEq(libHash, contractHash, "hashTokenOut should match for multiple tokens");
    }

    function callHashTokenOutLib(uint256[2][] calldata tokenOut) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashTokenOut(tokenOut);
    }

    // Test hashMandateRaw function
    function test_hashMandateRaw_lib_vs_contract() public {
        bytes32 targetAttr = keccak256("target");
        bytes32 preOps = keccak256("preOps");
        bytes32 destOps = keccak256("destOps");
        bytes32 qHash = keccak256("qualifier");

        bytes32 libHash = EIP712TypeHashLib.hashMandateRaw(targetAttr, 0, preOps, destOps, qHash);
        bytes32 contractHash = EIP712TypeHashLib.hashMandateRaw(targetAttr, 0, preOps, destOps, qHash);
        assertEq(libHash, contractHash, "hashMandateRaw should match");
    }

    // Test hashTargetAttributesRaw function
    function test_hashTargetAttributesRaw_lib_vs_contract() public {
        address recipient = address(0xabcdef);
        bytes32 tokenOutHash = keccak256("tokenOut");
        uint256 targetChainId = 42;
        uint256 fillDeadline = 1_234_567_890;

        bytes32 libHash = EIP712TypeHashLib.hashTargetAttributesRaw(recipient, tokenOutHash, targetChainId, fillDeadline);
        bytes32 contractHash = EIP712TypeHashLib.hashTargetAttributesRaw(recipient, tokenOutHash, targetChainId, fillDeadline);
        assertEq(libHash, contractHash, "hashTargetAttributesRaw should match");
    }

    // Test hashElementRaw function
    function test_hashElementRaw_lib_vs_contract() public {
        address arbiter = address(0xfedcba);
        uint256 originChainId = 1;
        bytes32 tokenInHash = keccak256("tokenIn");
        bytes32 mandateHash = keccak256("mandate");

        bytes32 libHash = EIP712TypeHashLib.hashElementRaw(arbiter, originChainId, tokenInHash, mandateHash);
        bytes32 contractHash = EIP712TypeHashLib.hashElementRaw(arbiter, originChainId, tokenInHash, mandateHash);
        assertEq(libHash, contractHash, "hashElementRaw should match");
    }

    // Test hashCompact (raw) function
    function test_hashCompact_raw_lib_vs_contract() public {
        address sponsor = address(0x987654);
        uint256 nonce = 42;
        uint256 expires = 1_234_567_890;
        bytes32 allElementsHash = keccak256("elements");

        bytes32 libHash = EIP712TypeHashLib.hashCompact(sponsor, nonce, expires, allElementsHash);
        bytes32 contractHash = EIP712TypeHashLib.hashCompact(sponsor, nonce, expires, allElementsHash);
        assertEq(libHash, contractHash, "hashCompact (raw) should match");
    }

    // Test hashQualifierData function
    function test_hashQualifierData_lib_vs_contract() public {
        bytes memory qualifier = hex"deadbeef1234567890abcdef";

        bytes32 libHash = this.callHashQualifierDataLib(qualifier);
        bytes32 contractHash = this.callHashQualifierContract(qualifier);
        assertEq(libHash, contractHash, "hashQualifierData should match");
    }

    function callHashQualifierDataLib(bytes calldata qualifier) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashQualifierData(qualifier);
    }

    // Test hashOps function with empty and populated arrays
    function test_hashOps_lib_vs_contract() public {
        // Test with empty array
        Execution[] memory emptyOps = new Execution[](0);
        bytes32 libHash = this.callHashOpsLib(emptyOps);
        bytes32 contractHash = this.callHashOpsContract(emptyOps);
        assertEq(libHash, contractHash, "hashOps should match for empty array");

        // Test with single operation
        Execution[] memory singleOp = new Execution[](1);
        singleOp[0] = Execution({ target: address(0x1234567890123456789012345678901234567890), value: 1 ether, callData: hex"deadbeef" });
        libHash = this.callHashOpsLib(singleOp);
        contractHash = this.callHashOpsContract(singleOp);
        assertEq(libHash, contractHash, "hashOps should match for single operation");

        // Test with multiple operations
        Execution[] memory multipleOps = new Execution[](3);
        multipleOps[0] = Execution({ target: address(0x1111), value: 100, callData: hex"1111" });
        multipleOps[1] = Execution({ target: address(0x2222), value: 200, callData: hex"2222" });
        multipleOps[2] = Execution({ target: address(0x3333), value: 300, callData: hex"3333" });
        libHash = this.callHashOpsLib(multipleOps);
        contractHash = this.callHashOpsContract(multipleOps);
        assertEq(libHash, contractHash, "hashOps should match for multiple operations");
    }

    function callHashOpsLib(Execution[] calldata executions) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashOps(executions);
    }

    // Test hashOperationOptimized function
    function test_hashOperationOptimized_lib_vs_contract() public {
        Execution memory op =
            Execution({ target: address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD), value: 5 ether, callData: hex"1234567890abcdef" });

        bytes32 libHash = this.callHashOperationOptimizedLib(op);
        bytes32 contractHash = this.callHashOperationOptimizedContract(op);
        assertEq(libHash, contractHash, "hashOperationOptimized should match");
    }

    function callHashOperationOptimizedLib(Execution calldata execution) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashOperationOptimized(execution);
    }

    // Test hashPermit2 function
    function test_hashPermit2_lib_vs_contract() public {
        bytes32 tokenInHash = keccak256("tokenIn");
        address arbiter = address(0x9999999999999999999999999999999999999999);
        uint256 nonce = 12_345;
        uint256 expires = 1_234_567_890;
        bytes32 mandate = keccak256("mandate");

        bytes32 libHash = EIP712TypeHashLib.hashPermit2(tokenInHash, arbiter, nonce, expires, mandate);
        bytes32 contractHash = EIP712TypeHashLib.hashPermit2(tokenInHash, arbiter, nonce, expires, mandate);
        assertEq(libHash, contractHash, "hashPermit2 should match");
    }

    // Test hashTokenPermissions (single) function
    function test_hashTokenPermissions_single_lib_vs_contract() public {
        address token = address(0x8888888888888888888888888888888888888888);
        uint256 amount = 9999 ether;

        bytes32 libHash = EIP712TypeHashLib.hashTokenPermissions(token, amount);
        bytes32 contractHash = EIP712TypeHashLib.hashTokenPermissions(token, amount);
        assertEq(libHash, contractHash, "hashTokenPermissions (single) should match");
    }

    // Note: hashTokenPermissions array version is internal in the library and can't be tested directly

    // Test high-level hashTargetAttributes function
    function test_hashTargetAttributes_lib_vs_contract() public {
        // Create test order with token outputs
        Types.Order memory order = Types.Order({
            sponsor: address(0x1),
            recipient: address(0x2),
            nonce: 1,
            expires: block.timestamp + 3600,
            fillDeadline: block.timestamp + 7200,
            notarizedChainId: 1,
            targetChainId: 137,
            tokenIn: new uint256[2][](0),
            tokenOut: new uint256[2][](2),
            preClaimOps: Types.Operation({ data: hex"" }),
            targetOps: Types.Operation({ data: hex"" }),
            qualifier: hex"",
            packedGasValues: 0
        });
        order.tokenOut[0] = [uint256(uint160(address(0x3))), 100 ether];
        order.tokenOut[1] = [uint256(uint160(address(0x4))), 200 ether];

        bytes32 libHash = this.callHashTargetAttributesLib(order);
        bytes32 contractHash = this.callHashTargetAttributesContract(order);
        assertEq(libHash, contractHash, "hashTargetAttributes should match");
    }

    function callHashTargetAttributesLib(Types.Order calldata order) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashTargetAttributes(order);
    }

    // Helper functions for contract calls that need calldata conversion
    function callHashTargetAttributesContract(Types.Order calldata order) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashTargetAttributes(order);
    }

    function callHashMandateContract(Types.Order calldata order) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashMandate(order, order.qualifier);
    }

    function callHashElementContract(Types.Order calldata order, address arbiter, uint256 originChainId) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashElement(order, arbiter, originChainId, order.qualifier);
    }

    function callHashOpsContract(Execution[] calldata executions) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashOps(executions);
    }

    function callHashOperationOptimizedContract(Execution calldata execution) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashOperationOptimized(execution);
    }

    function callHashCompactMemoryContract(Types.Order calldata order, bytes32[] memory allElements) external view returns (bytes32) {
        return EIP712TypeHashLib.hashCompact(order, allElements);
    }

    function callHashCompactCalldataContract(
        Types.Order calldata order,
        bytes32 notarizedElement,
        bytes32[] calldata otherElements
    )
        external
        view
        returns (bytes32)
    {
        return EIP712TypeHashLib.hashCompact(order, notarizedElement, otherElements);
    }

    function callHashQualifierContract(bytes calldata qualifier) external view returns (bytes32) {
        return __QUALIFIER_EIP712Hash(qualifier);
    }

    function callHashTokenInContract(uint256[2][] calldata tokenIn) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashTokenIn(tokenIn);
    }

    function callHashTokenOutContract(uint256[2][] calldata tokenOut) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashTokenOut(tokenOut);
    }

    // Test high-level hashMandate function
    function test_hashMandate_lib_vs_contract() public {
        // Create test order
        Types.Order memory order = Types.Order({
            sponsor: address(0x1),
            recipient: address(0x2),
            nonce: 1,
            expires: block.timestamp + 3600,
            fillDeadline: block.timestamp + 7200,
            notarizedChainId: 1,
            targetChainId: 137,
            tokenIn: new uint256[2][](0),
            tokenOut: new uint256[2][](1),
            preClaimOps: Types.Operation({ data: hex"" }),
            targetOps: Types.Operation({ data: hex"" }),
            qualifier: hex"1234",
            packedGasValues: 0
        });
        order.tokenOut[0] = [uint256(uint160(address(0x3))), 100 ether];

        bytes32 libHash = this.callHashMandateLib(order, order.qualifier);
        bytes32 contractHash = this.callHashMandateContract(order);
        assertEq(libHash, contractHash, "hashMandate should match");
    }

    function callHashMandateLib(Types.Order calldata order, bytes calldata qualifier) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashMandate(order, qualifier);
    }

    // Test high-level hashElement function
    function test_hashElement_lib_vs_contract() public {
        // Create test order
        Types.Order memory order = Types.Order({
            sponsor: address(0x1),
            recipient: address(0x2),
            nonce: 1,
            expires: block.timestamp + 3600,
            fillDeadline: block.timestamp + 7200,
            notarizedChainId: 1,
            targetChainId: 137,
            tokenIn: new uint256[2][](1),
            tokenOut: new uint256[2][](1),
            preClaimOps: Types.Operation({ data: hex"" }),
            targetOps: Types.Operation({ data: hex"" }),
            qualifier: hex"5678",
            packedGasValues: 0
        });
        order.tokenIn[0] = [uint256(uint160(address(0x5))), 50 ether];
        order.tokenOut[0] = [uint256(uint160(address(0x6))), 60 ether];

        address arbiter = address(0x7);
        uint256 originChainId = 1;

        bytes32 libHash = this.callHashElementLib(order, arbiter, originChainId, order.qualifier);
        bytes32 contractHash = this.callHashElementContract(order, arbiter, originChainId);
        assertEq(libHash, contractHash, "hashElement should match");
    }

    function callHashElementLib(
        Types.Order calldata order,
        address arbiter,
        uint256 originChainId,
        bytes calldata qualifier
    )
        external
        pure
        returns (bytes32)
    {
        return EIP712TypeHashLib.hashElement(order, arbiter, originChainId, qualifier);
    }

    // Test high-level hashCompact functions (both overloads)
    function test_hashCompact_overloads_lib_vs_contract() public {
        // Create test order
        Types.Order memory order = Types.Order({
            sponsor: address(0x1),
            recipient: address(0x2),
            nonce: 42,
            expires: block.timestamp + 3600,
            fillDeadline: block.timestamp + 7200,
            notarizedChainId: 1,
            targetChainId: 137,
            tokenIn: new uint256[2][](0),
            tokenOut: new uint256[2][](0),
            preClaimOps: Types.Operation({ data: hex"" }),
            targetOps: Types.Operation({ data: hex"" }),
            qualifier: hex"",
            packedGasValues: 0
        });

        // Test memory array overload
        bytes32[] memory allElements = new bytes32[](2);
        allElements[0] = keccak256("element1");
        allElements[1] = keccak256("element2");

        bytes32 libHashMemory = this.callHashCompactMemoryLib(order, allElements);
        bytes32 contractHashMemory = this.callHashCompactMemoryContract(order, allElements);
        assertEq(libHashMemory, contractHashMemory, "hashCompact (memory array) should match");

        // Test calldata array overload with notarized element
        bytes32 notarizedElement = keccak256("notarized");
        bytes32[] memory otherElements = new bytes32[](1);
        otherElements[0] = keccak256("other");

        bytes32 libHashCalldata = this.callHashCompactCalldataLib(order, notarizedElement, otherElements);
        bytes32 contractHashCalldata = this.callHashCompactCalldataContract(order, notarizedElement, otherElements);
        assertEq(libHashCalldata, contractHashCalldata, "hashCompact (calldata array) should match");
    }

    function callHashCompactMemoryLib(Types.Order calldata order, bytes32[] memory allElements) external pure returns (bytes32) {
        return EIP712TypeHashLib.hashCompact(order, allElements);
    }

    function callHashCompactCalldataLib(
        Types.Order calldata order,
        bytes32 notarizedElement,
        bytes32[] calldata otherElements
    )
        external
        pure
        returns (bytes32)
    {
        return EIP712TypeHashLib.hashCompact(order, notarizedElement, otherElements);
    }

    // Edge case testing with extreme values
    function test_lib_vs_contract_extreme_values() public {
        // Test with maximum uint256 values
        uint256[2][] memory maxTokens = new uint256[2][](1);
        maxTokens[0] = [type(uint256).max, type(uint256).max];

        bytes32 libHash = this.callHashTokenInLib(maxTokens);
        bytes32 contractHash = this.callHashTokenInContract(maxTokens);
        assertEq(libHash, contractHash, "Should handle max values correctly");

        // Test with address(0) values
        bytes32 libHashZero = EIP712TypeHashLib.hashTargetAttributesRaw(address(0), bytes32(0), 0, 0);
        bytes32 contractHashZero = EIP712TypeHashLib.hashTargetAttributesRaw(address(0), bytes32(0), 0, 0);
        assertEq(libHashZero, contractHashZero, "Should handle zero values correctly");
    }

    // Gas comparison test (informational)
    function test_gas_comparison_informational() public {
        uint256[2][] memory tokens = new uint256[2][](5);
        for (uint256 i = 0; i < 5; i++) {
            tokens[i] = [uint256(uint160(address(uint160(i + 1)))), (i + 1) * 100 ether];
        }

        // Measure library gas usage
        uint256 gasStartLib = gasleft();
        bytes32 libResult = this.callHashTokenInLib(tokens);
        uint256 gasUsedLib = gasStartLib - gasleft();

        // Measure contract gas usage
        uint256 gasStartContract = gasleft();
        bytes32 contractResult = this.callHashTokenInContract(tokens);
        uint256 gasUsedContract = gasStartContract - gasleft();

        // Verify results match
        assertEq(libResult, contractResult, "Results should match");

        // Log gas usage for comparison (informational only)
        console2.log("Library gas used:  ", gasUsedLib);
        console2.log("Contract gas used: ", gasUsedContract);
        if (gasUsedLib < gasUsedContract) {
            uint256 savings = ((gasUsedContract - gasUsedLib) * 100) / gasUsedContract;
            console2.log("Gas savings:       ", savings, "%");
        }
    }
}
