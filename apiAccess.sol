// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract BlindfoldAPIAccess {
    address public owner;
    mapping(address => uint256) public pricePerDay; // Token => Price per day
    mapping(address => uint256) public subscriptionExpiry;
    mapping(address => bool) public acceptedTokens;

    event Subscribed(address indexed user, uint256 expiry);
    event TokenAdded(address token, uint256 pricePerDay);
    event TokenRemoved(address token);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setTokenPrice(address token, uint256 _pricePerDay) external onlyOwner {
        require(_pricePerDay > 0, "Price must be greater than zero");
        acceptedTokens[token] = true;
        pricePerDay[token] = _pricePerDay;
        emit TokenAdded(token, _pricePerDay);
    }

    function removeAcceptedToken(address token) external onlyOwner {
        acceptedTokens[token] = false;
        pricePerDay[token] = 0;
        emit TokenRemoved(token);
    }

    function buyAccessWithToken(address token, uint256 daysToBuy) external {
        require(acceptedTokens[token], "Token not accepted");
        require(daysToBuy > 0, "Must buy at least one day");

        uint256 totalCost = pricePerDay[token] * daysToBuy;
        IERC20 paymentToken = IERC20(token);
        require(paymentToken.allowance(msg.sender, address(this)) >= totalCost, "Insufficient allowance");
        require(paymentToken.transferFrom(msg.sender, address(this), totalCost), "Transfer failed");

        uint256 newExpiry;
        if (subscriptionExpiry[msg.sender] > block.timestamp) {
            newExpiry = subscriptionExpiry[msg.sender] + (daysToBuy * 1 days);
        } else {
            newExpiry = block.timestamp + (daysToBuy * 1 days);
        }
        subscriptionExpiry[msg.sender] = newExpiry;

        emit Subscribed(msg.sender, newExpiry);
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
