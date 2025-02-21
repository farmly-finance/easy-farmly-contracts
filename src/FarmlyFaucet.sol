pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FarmlyFaucet is Ownable {
    struct Token {
        IERC20 token;
        uint256 amount;
    }

    Token[] public tokens;
    mapping(address => bool) public claimed;
    address[] public users;

    constructor(Token[] memory _tokens) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokens.push(_tokens[i]);
        }
    }

    function claim() external {
        require(!claimed[msg.sender], "Already claimed");
        claimed[msg.sender] = true;
        users.push(msg.sender);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].token.transfer(msg.sender, tokens[i].amount);
        }
    }

    function getUsers() external view returns (address[] memory) {
        return users;
    }

    function getTokens() external view returns (Token[] memory) {
        return tokens;
    }

    function getClaimed() external view returns (bool) {
        return claimed[msg.sender];
    }

    function getUsersLength() external view returns (uint256) {
        return users.length;
    }

    function getTokensLength() external view returns (uint256) {
        return tokens.length;
    }

    function transferTokens(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }
}
