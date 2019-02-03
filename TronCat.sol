pragma solidity >=0.4.22 <0.6.0; //solidity version

import "./SafeMath.sol";
import "./TokenInterface.sol";

contract TronCat is TokenInterface {
    
    using SafeMath for uint256;
    
    struct BetDetails{
        uint256 bet_amount;
        uint256 bet_time;
        bool bet_status;
    }
    
    struct WonDetails{
        uint256 won_amount;
        bool paid_status;
    }
    
    struct FailedAccounts{
        address[] accounts;
    }
    
    address owner;
   
    string public constant symbol = "CAT";
    string public constant name = "TronCat";
    uint256 public constant decimals = 6;
    uint256 private constant _totalSupply = 10000000000000000 ;// 10 B

    uint256 private  _miningSupply = 2999999999000000; 
   
    
    
    uint256 public max_bet_amount = 6000 * 10 ** decimals;
    uint256 public totalBet;
    uint256 public totalWon;
    uint256 public numberOfBets;
  
    mapping(address => uint256) balances; 
    mapping(uint256 => mapping(address => BetDetails)) bet_round_info;
    mapping(uint256 => mapping(address => WonDetails)) won_round_info;
    mapping(uint256 => FailedAccounts)  failed_round_info;
    
   
  
    constructor () public {
        owner = msg.sender;
        balances[msg.sender] = _totalSupply; 
    }
    
     modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    
    event BetPlaced(uint256 round,uint256 time,address indexed from, uint256 bet_value);
    event WinTransfer(uint256 round,address indexed to, uint256 won_value);
   
    
    /*returns the number of all tokens allocated*/
    function totalSupply() public pure returns (uint256) {
      return _totalSupply;
    }
    
    
    /*Get the token balance for account tokenOwner*/
    function balanceOf(address tokenOwner) public view returns (uint256) {
       return balances[tokenOwner];
    }
    
    
     /*Transfer the balance from token owner's account to the receiver account*/
    function transfer(address receiver, uint256 numTokens) public returns (bool) {
     require(numTokens <= balances[msg.sender]);
     balances[msg.sender] = balances[msg.sender].sub(numTokens);
     balances[receiver] = balances[receiver].add(numTokens);
     emit Transfer(msg.sender, receiver, numTokens);
     return true;
    }
    
 
    
    
    /*returns the number of tokens remaining*/
    function remainingTokens() public view returns(uint256){
        return _miningSupply;
    }

    
    /*Get the wallet balance for the address*/
    function getBalance(address _address) public view returns (uint256) {
        return _address.balance;
    }
    
    
    
    function getBetInfo(uint round , address bet_adress) public view returns (uint256,uint256,bool) {
     return (
         bet_round_info[round][bet_adress].bet_amount,
         bet_round_info[round][bet_adress].bet_time,
         bet_round_info[round][bet_adress].bet_status
         );
    }
    
    function placeBet(uint256 numTokens, uint256 bet_round) public payable {
      require(msg.value > 0 && msg.value <= max_bet_amount);
      require(msg.value<=getBalance(msg.sender));
      require(!bet_round_info[bet_round][msg.sender].bet_status);
      
      numberOfBets++;
      totalBet += msg.value;
      bet_round_info[bet_round][msg.sender] = BetDetails(msg.value,now,true);
      emit BetPlaced(bet_round,now,msg.sender,msg.value);
      if(_miningSupply != 0 ){
          require(numTokens<_miningSupply);
           _miningSupply = _miningSupply.sub(numTokens);
           balances[msg.sender] = balances[msg.sender].add(numTokens);
           balances[owner] = balances[owner].sub(numTokens);
           emit Transfer(owner, msg.sender, numTokens);
      }
    }
    
    
     
    function transferAfterWin(uint256 round,address win_address, uint256 won_value) onlyOwner  public returns (bool) {
        
      require(won_value > 0 && win_address != address(0)); // or require(_to != 0x0);// null address(zero address)
      assert(getBalance(win_address) + won_value > getBalance(win_address)); // Check for overflows
      require(bet_round_info[round][win_address].bet_status); // person's bet_status should be true for that round
      require(!won_round_info[round][win_address].paid_status); // person cannot be paid more than once in the same round
      
      if(!win_address.send(won_value)){
         failed_round_info[round].accounts.push(win_address);
         won_round_info[round][win_address] = WonDetails(won_value,false);
      }else{
           won_round_info[round][win_address] = WonDetails(won_value,true);
         
           totalWon += won_value;
           emit WinTransfer(round,win_address, won_value);
           return true;
      }
    
    }
    
  
    
    function getFailedAccounts(uint256 round) onlyOwner view  public  returns(address[]){
        return failed_round_info[round].accounts;
    }
    
    
 
   function withdraw (uint256 amount) onlyOwner public {
        address _contract = this;
        uint contract_balance = _contract.balance;
        require(amount <= contract_balance);
        msg.sender.transfer(amount);
   }
    

   function checkContractBalance() onlyOwner public view returns(uint256) {
       address _contract = this;
       return _contract.balance;
   }
   
   
}