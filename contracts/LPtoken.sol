// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;


contract LPtoken {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    address public _owner;

    uint256 public _totalSupply;

    string public _name;
    string public _symbol;
    uint8 public _decimals;

    event Transfer(address from, address to, uint amount);
    event Approval(address owner, address spender, uint amount);

    modifier onlyOwner {
        require(_owner == msg.sender);
        _;
    }


    constructor(string memory name_, string memory symbol_, address owner_) {
        _name = name_;
        _symbol = symbol_;
        _owner = owner_;
        _decimals = 18;
    }


    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }


    function transfer(address to, uint256 amount) external returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }


    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }


    function approve(address spender, uint256 amount) external returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }


    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(_allowances[from][to] >= amount);
        _transfer(from, to, amount);
        return true;
    }


    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "LPtoken: transfer from the zero address");
        require(to != address(0), "LPtoken: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "LPtoken: transfer amount exceeds balance");
        
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }


    function mint(address account, uint256 amount) external onlyOwner  {
        require(account != address(0), "LPtoken: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }


    function burn(address account, uint256 amount) external onlyOwner  {
        require(account != address(0), "LPtoken: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "LPtoken: burn amount exceeds balance");
        
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }


    function _approve(address owner, address spender, uint256 amount) internal  {
        require(owner != address(0), "LPtoken: approve from the zero address");
        require(spender != address(0), "LPtoken: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

}