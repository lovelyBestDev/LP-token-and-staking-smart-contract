// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4; 


contract ChainLink {
    address owner;

    mapping (string => address) private chainlink;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }
    
    function init(string[] memory _names, address[] memory _addresses) external onlyOwner returns(bool){
        require(_names.length == _addresses.length, "Please check data again.");

        for(uint i = 0; i < _names.length; i++) {
            chainlink[_names[i]] = _addresses[i];
        }

        return true;
    }

    function setAddress(string memory _name, address _address) external onlyOwner returns(bool) {
        require(_address != address(0));

        chainlink[_name] = _address;

        return true;
    }

    function getAddress(string memory _name) external view returns(address) {
        return chainlink[_name];
    }

    function removeAddress(string memory _name) external onlyOwner returns(bool) {
        delete chainlink[_name];
        return true;
    }
}