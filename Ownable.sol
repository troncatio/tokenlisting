pragma solidity >=0.4.22 <0.6.0;

contract Ownable {
    address internal owner;

    
    constructor() public {
        owner = msg.sender;
    }

    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}