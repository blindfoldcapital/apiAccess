
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract BlindfoldAPIAccess {
    address public owner;
    uint256 public price;
    mapping(address => uint256) public subscriptionExpiry;
    mapping(address => bool) public acceptedTokens;

    event Subscribed(address indexed user, uint256 expiry);
    event TokenAdded(address token);
    event TokenRemoved(address token);

    constructor(uint256 _price) {
        owner = msg.sender;
        price = _price;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setPrice(uint256 _price) external onlyOwner {
        price = _price;
    }

    function addAcceptedToken(address token) external onlyOwner {
        acceptedTokens[token] = true;
        emit TokenAdded(token);
    }

    function removeAcceptedToken(address token) external onlyOwner {
        acceptedTokens[token] = false;
        emit TokenRemoved(token);
    }

    function buyAccessWithToken(address token, uint256 amount) external {
        require(acceptedTokens[token], "Token not accepted");
        require(amount >= price, "Insufficient amount");

        IERC20 paymentToken = IERC20(token);
        require(paymentToken.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");
        require(paymentToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        uint256 duration = 30 days;
        if (subscriptionExpiry[msg.sender] > block.timestamp) {
            subscriptionExpiry[msg.sender] += duration;
        } else {
            subscriptionExpiry[msg.sender] = block.timestamp + duration;
        }

        emit Subscribed(msg.sender, subscriptionExpiry[msg.sender]);
    }

    function checkAccess(address user) external view returns (bool) {
        return subscriptionExpiry[user] > block.timestamp;
    }

    function withdrawTokens(address token) external onlyOwner {
        IERC20 paymentToken = IERC20(token);
        uint256 balance = paymentToken.balanceOf(address(this));
        require(paymentToken.transfer(owner, balance), "Withdraw failed");
    }
}
