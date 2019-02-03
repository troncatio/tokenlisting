pragma solidity >=0.4.22 <0.6.0; //solidity version

contract TokenInterface {
    function totalSupply() public pure returns (uint256);
    function balanceOf(address tokenOwner) public view returns (uint256 balance);
    function transfer(address to, uint256 tokens) public returns (bool success);
    event Transfer(address indexed from, address indexed to, uint256 tokens);
}