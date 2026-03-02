interface IAdapterDriver {
    function getSelectors() external view returns (bytes4[] memory _fillSelectors, bytes4[] memory _claimSelectors);
}

