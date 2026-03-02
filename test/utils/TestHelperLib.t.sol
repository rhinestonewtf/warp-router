import "forge-std/Test.sol";
import { TestHelperLib } from "@rhinestone/compact-utils/src/tests/Environment.sol";
import { Bytes32ArrayLib } from "@rhinestone/compact-utils/src/common/Bytes32ArrayLib.sol";

contract TestHelperLibTest is Test {
    using Bytes32ArrayLib for bytes32[];
    using TestHelperLib for bytes32[];

    function setUp() public { }

    function test_first(bytes32[] calldata array, bytes32 element) public {
        bytes32[] memory out = array.insertAt(0, element);

        (, bytes32[] memory without) = out.withoutIndex(0);

        assertEq(keccak256(abi.encodePacked(array)), keccak256(abi.encodePacked(without)));
    }
}
