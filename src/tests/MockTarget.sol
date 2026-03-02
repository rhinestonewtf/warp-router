import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract MockTarget {
    uint256 public value;
    uint256 public param;

    event TargetCalled(uint256 value, uint256 param);
    event BalanceOf(address account, uint256 balance);

    function targetFn(uint256 _param) external payable {
        value = msg.value;
        param = _param;
        emit TargetCalled(value, param);
    }

    function deposit(IERC20 token, uint256 amount) external {
        emit BalanceOf(msg.sender, token.balanceOf(msg.sender));
        token.transferFrom(msg.sender, address(this), amount);
    }

    function reverting() external pure {
        revert();
    }

    function getAddress() external view returns (address) {
        return address(this);
    }

    function getBool() external view returns (bool) {
        return param > 0;
    }

    function getBytes32() external pure returns (bytes32) {
        return keccak256("test");
    }

    function getString() external pure returns (string memory) {
        return "hello world";
    }

    function getArray() external view returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](3);
        arr[0] = param;
        arr[1] = param * 2;
        arr[2] = param * 3;
        return arr;
    }

    function getTuple() external view returns (uint256, address, bool) {
        return (param, address(this), param > 0);
    }

    function getBytes() external pure returns (bytes memory) {
        return abi.encode(uint256(123), address(0xdead), "test");
    }
}
