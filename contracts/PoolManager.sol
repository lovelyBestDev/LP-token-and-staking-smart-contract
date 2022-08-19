// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

// import "./TokenManager.sol";
import "./Pool.sol";
import "./LPtoken.sol";

contract PoolManager {
    mapping(address => mapping(address => address)) pools;
    
    event CreateNewPool(string t1, string t2, address p_addr);
    event RemovePool(string t1, string t2, address p_addr);

    Token_manager TM;

    constructor (address _tokenManagerAddr) {
        TM = Token_manager(_tokenManagerAddr);
    }


    //@@ this function is for creating new liquidity pool into pool list
    function createPool(string calldata _token1, string calldata _token2) external {
        require(createNewPoolAvailable(_token1, _token2), "That pool is already exists.");


        Pool newPool = new Pool(TM.getTokenAddress(_token1), TM.getTokenAddress(_token2));
        LPtoken newLP = new LPtoken(string(abi.encodePacked(_token1, '-', _token2)), string(abi.encodePacked(_token1, '-', _token2)), address(newPool));
        newPool.setLPtoken(address(newLP));
        newPool.transferOwnership(msg.sender);


        pools[TM.getTokenAddress(_token1)][TM.getTokenAddress(_token2)] = address(newPool); //address(newPool);

        emit CreateNewPool(_token1, _token2, address(newPool));
    }




    //@@ this function is for getting the address of certain liquidity pool
    function getPoolAddress(string calldata _token1, string calldata _token2) external view returns(address){
        require(pools[TM.getTokenAddress(_token1)][TM.getTokenAddress(_token2)] != address(0));

        return pools[TM.getTokenAddress(_token1)][TM.getTokenAddress(_token2)];
    }



    //@@ this function is for getting if there is certain liquidity pool
    // this function is used before creating new pool
    // if there is certain pool that you will create,  you can't create new pool
    function createNewPoolAvailable(string calldata _token1, string calldata _token2) public view returns(bool) {
        if(pools[TM.getTokenAddress(_token1)][TM.getTokenAddress(_token2)] == address(0)) {
            return true;
        } else {
            return false;
        }
    }
}