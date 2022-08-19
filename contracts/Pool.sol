// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface Token_manager {
    function getTokenAddress(string memory _name) external view returns(address);
    function getTokenName(address) external view returns(string memory);
}

interface Chain_link {
    function getAddress(string memory _name) external view returns(address);
}

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId) external view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData() external view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}



contract Pool {
    AggregatorV3Interface private priceFeed;

    Chain_link private CL;
    Token_manager private TM;

    using SafeMath for uint;

    address private owner;

    address private token1;
    address private token2;
    IERC20 private token1_contract;
    IERC20 private token2_contract;

    address private tokenLP;
    IERC20 private tokenLP_contract;

    uint256 private totalRewardAmount1;
    uint256 private totalRewardAmount2;

    uint8 MAX_FEE = 20;

    uint8 private token1Fee = 5;
    uint8 private token2Fee = 5;

    mapping (address => uint) private stakers;

    uint256 private cooldownTime = 30 days;

    //@@ event list
    event Exchange(address fromToken, address toToken, uint amount);
    event TransferOwnership(address owner);
    event NewStaking(address newStaker, uint t1Amount, uint t2Amount);
    event GetReward(address staker, uint time);


    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }


    constructor (address _token1, address _token2) {
        owner = msg.sender;

        token1 = _token1;
        token2 = _token2;
        token1_contract = IERC20(_token1);
        token2_contract = IERC20(_token2);
    }
    

    function setLPtoken(address _LPtoken) external onlyOwner {
        tokenLP = _LPtoken;
        tokenLP_contract = IERC20(tokenLP);
    }



    //@@ this function is for swapping token1 for token2
    // For using this function, you have to pay extra fees
    // Fee rates are different by token address
    function exchange(address _fromToken, address _toToken, uint _amount) public {
        require(_fromToken != address(0), "Token address error.");
        require(_toToken != address(0), "Token address error.");
        require(_amount != 0);

        require(IERC20(_fromToken).allowance(msg.sender, address(this)) >= _amount);

        if(_fromToken == token1 && _toToken == token2) {  // swap token1 for token2

            uint s_amount = _amount.mul(token2_contract.balanceOf(address(this))).div((token1_contract.balanceOf(address(this)).mul(10 ** token1_contract.decimals())));

            uint transactionFee = _amount.mul(token1Fee).div(1000);  // calculate the fee for token1  -  default = 0.5%

            token1_contract.transferFrom(msg.sender, address(this), _amount.add(transactionFee).mul(10 ** token1_contract.decimals()));

            totalRewardAmount1 = totalRewardAmount1.add(transactionFee);  // save totalReward of token1

            token2_contract.transfer(msg.sender, s_amount);

        } else if(_fromToken == token2 && _toToken == token1){  // swap token2 for token1

            uint s_amount = _amount.mul(token1_contract.balanceOf(address(this))).div((token2_contract.balanceOf(address(this)).mul(10 ** token2_contract.decimals())));

            uint transactionFee = _amount.mul(token2Fee).div(1000);  // calculate the fee for token2  -  default = 0.5%

            token2_contract.transferFrom(msg.sender, address(this), _amount.add(transactionFee).mul(10 ** token2_contract.decimals()));

            totalRewardAmount2 = totalRewardAmount2.add(transactionFee);  // save totalReward of token2

            token1_contract.transfer(msg.sender, s_amount);

        }

        stakers[msg.sender] = block.timestamp;

        emit Exchange(_fromToken, _toToken, _amount);
    }




    //@@ this function is for setting fees
    // Warning: if you are not owner, you can't call this function
    // Via this function, owner can change fees for token1 and token2
    function setTokenFee(uint8 _token1Fee, uint8 _token2Fee) external onlyOwner{
        require(MAX_FEE >= _token1Fee && MAX_FEE >= _token2Fee, "New fees are exceed MAX FEE.");

        token1Fee = _token1Fee;
        token2Fee = _token2Fee;
    }




    //@@ this function is for changing owner address
    // Warning: if you are not owner, you can't call this funciton
    function transferOwnership(address newOwner) external onlyOwner{
        owner = newOwner;
        emit TransferOwnership(newOwner);
    }




    //@@ this function is for getting total balance of this pool
    function getPoolTotalBalance() external view returns(uint, uint) {
        return (token1_contract.balanceOf(address(this)), token2_contract.balanceOf(address(this)));
    }



    //@@ this function is for staking into this pool
    // your share in this pool is calculated by the amount of LP token
    // you can receive LP tokens that have same value as tokens you put into this pool
    function staking(uint _token1Amount, uint _token2Amount) external {
        require(!(_token1Amount == 0 && _token2Amount == 0), "No staking.");
        require(token1_contract.allowance(msg.sender, address(this)) >= _token1Amount && token2_contract.allowance(msg.sender, address(this)) >= _token2Amount, "Not approve.");

        token1_contract.transferFrom(msg.sender, address(this), _token1Amount);
        token2_contract.transferFrom(msg.sender, address(this), _token2Amount);

        uint lpToken;

        if(tokenLP_contract.totalSupply() == 0) {
            lpToken = 1000;
        } else {
            lpToken = calcLPAmountFromTokensAmount(_token1Amount, _token2Amount);
        }

        tokenLP_contract.mint(msg.sender, lpToken.mul(tokenLP_contract.decimals()));

        stakers[msg.sender] = block.timestamp;

        if (_token1Amount != 0 && _token2Amount == 0) {
            exchange(token1, token2, _token1Amount / 2);
        } else if (_token1Amount == 0 && _token2Amount != 0) {
            exchange(token2, token1, _token2Amount / 2);
        }

        emit NewStaking(msg.sender, _token1Amount, _token2Amount);
    }




    //@@ this function is for withdrawing the amount you want among you have staked into this pool
    function withdraw(uint amount, uint8 percentage) external {
        require(tokenLP_contract.balanceOf(msg.sender) >= amount, "Your balance is not enough.");
        require(stakers[msg.sender] + cooldownTime >= block.timestamp, "You can't withdraw now.");

        uint token1WillWithdraw = (amount * percentage / 100) * getCurrentLPtokenPrice() / getCurrentToken1Price();
        uint token2WillWithdraw = (amount * (100 - percentage) / 100) * getCurrentLPtokenPrice() / getCurrentToken2Price();

        token1_contract.transfer(msg.sender, token1WillWithdraw);
        token2_contract.transfer(msg.sender, token2WillWithdraw);
        
        tokenLP_contract.burn(address(this), amount);

        stakers[msg.sender] = block.timestamp;
    }



    //@@ this function is for calculating by two tokens' amount
    function calcLPAmountFromTokensAmount(uint _token1Amount, uint _token2Amount) private returns(uint) {
        // uint totalStaking = _token1Amount.mul(getCurrentToken1Price()) + _token2Amount.mul(getCurrentToken2Price());
        return (_token1Amount.mul(getCurrentToken1Price()) + _token2Amount.mul(getCurrentToken2Price())).div(getCurrentLPtokenPrice());
    }


    
    //@@ this function is for getting current price of LP token
    function getCurrentLPtokenPrice() public returns(uint) {
        return 2 * getCurrentToken2Price().mul(token2_contract.balanceOf(address(this))).div(tokenLP_contract.totalSupply());
    }
    
    //@@ this function is for getting current price of token1
    function getCurrentToken1Price() public view returns(uint) {
        return token2_contract.balanceOf(address(this)).div(token1_contract.balanceOf(address(this)));
    }

    //@@ this function is for getting current price of token2
    function getCurrentToken2Price() public returns(uint) {
        priceFeed = AggregatorV3Interface(CL.getAddress(TM.getTokenName(token2)));
        int price;
        (,price,,,) = priceFeed.latestRoundData();
        return uint(price);
    }



    //@@ this function is for calculating exchangeRate
    function exchangeRate() public view returns(uint) {
        // uint rate = token1_contract.balanceOf(address(this)) * 1000000 / token2_contract.balanceOf(address(this));
        return token1_contract.balanceOf(address(this)) * 1000000 / token2_contract.balanceOf(address(this));
    }

}