pragma solidity >=0.4.22 <0.6.0; //solidity version

import "./SafeMath.sol";
import "./TRC20.sol";
import "./TronCat.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import "./StringUtils.sol";

contract TronCatV2 is Ownable,Pausable,TRC20  {
    
   using SafeMath for uint256;
  

   TronCat tc_v1;
 
    string public symbol;
    string public name;
    uint8 public decimals;
    
    uint256 public min_cat_bet_amount = 10 * 10 ** 6;
    uint256 public max_cat_bet_amount = 1000 * 10 ** 6;
    uint256 public min_dice_bet_amount = 10 * 10 ** 6;
    uint256 public max_dice_bet_amount = 20000 * 10 ** 6;
    
    uint256 public totalCatBet;
    uint256 public totalDiceBet;
    uint256 public totalCatWon;
    uint256 public totalDiceWon;
    
    uint256 public numberOfCatBets;
    uint256 public numberOfDiceBets;
    
    uint256 private constant _totalSupply = 10000000000000000 ;// 10 B
    uint256 private  _miningSupply;
    uint256 private _referralSupply = 100000000000000;// 100M
    
    
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
    
    struct InvitedAccounts{
        address[] invitees;
    }
    
    struct Invitation{
        address inviter;
        uint256 referred_time;
        bool referred_status;
    }
    
    
 
    mapping(address => uint256) balances; 
    mapping(address => bool) migration_from_v1;
    mapping (address => mapping (address => uint256)) allowed;
    
    mapping(string => mapping(address => BetDetails))  bet_round_info; // CAT
    mapping(string => mapping(address => WonDetails))  won_round_info;
    mapping(string => FailedAccounts) failed_round_info;
    
 
  
    mapping (address => address) inviter; // child -> parent
    mapping(address => Invitation) invitation_details;// (child -> invitation)
    mapping(address => InvitedAccounts) invitee_list; // parent-> child addresses
    mapping(address => uint256) contributionsCollected; // how much inviter collected from contributers
    
    
    constructor (address _deployed_contract_address) public {
         tc_v1 = TronCat(_deployed_contract_address);
         balances[owner] = tc_v1.balanceOf(owner); // remaining balances of owner in v1 contract
    
         symbol = tc_v1.symbol();
         name = tc_v1.name();
         decimals = uint8(tc_v1.decimals());
         totalCatBet = tc_v1.totalBet();
         totalCatWon = tc_v1.totalWon();
         numberOfCatBets = tc_v1.numberOfBets();
         _miningSupply = tc_v1.remainingTokens();
    }
    
  
    
    modifier whenMiningNotFinished(){
        uint256 mined_tokens = _miningSupply;
        require(mined_tokens != 0);
        _;
    }
    
    
    event Migration(string old_version, string new_version,address indexed token_holder);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event BetPlaced(string round,uint256 time,address indexed from, uint256 bet_value, string game);
    event WinTransfer(string round,address indexed to, uint256 won_value,string game);
    event ReferralSet(address indexed inviter, address indexed invitee);
    
    
    
    
   function totalSupply() public pure returns (uint256) {
      return _totalSupply;
   }

   function balanceOf(address tokenOwner) public view returns (uint256) {
      if(tokenOwner == owner){
          return balances[owner];
      }
      if (!migration_from_v1[tokenOwner]) {
        return tc_v1.balanceOf(tokenOwner) + balances[tokenOwner];
       }
       return balances[tokenOwner];
   }


   function transfer(address receiver, uint256 numTokens) public whenNotPaused returns (bool) {
     require(numTokens <= balanceOf(msg.sender),'No Enough Tokens');
     balances[msg.sender] = balances[msg.sender].sub(numTokens);
     balances[receiver] = balances[receiver].add(numTokens);
     emit Transfer(msg.sender, receiver, numTokens);
     return true;
   }

   function transferFrom(address from, address to, uint256 tokens) public whenNotPaused returns (bool) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
   }

   function approve(address spender, uint256 tokens) public whenNotPaused returns (bool) {
     allowed[msg.sender][spender] = tokens;
     emit Approval(msg.sender, spender, tokens);
     return true;
   }
   
   
   function allowance(address _owner, address _spender) public view returns (uint256) {
     return allowed[_owner][_spender];
   }
   
   
   
   function migrateBalanceV1V2(address _holder) public onlyOwner whenNotPaused returns (bool){
        if (!migration_from_v1[_holder]) {
        balances[_holder] += tc_v1.balanceOf(_holder);
        migration_from_v1[_holder] = true;
        emit Migration("V1","V2",_holder);
        return true;
      }
   }
   
   function getV2InternalBalance(address _holder) public view onlyOwner whenNotPaused returns (uint256){
       return balances[_holder];
   }
   
   
   

    function remainingTokens() public view returns(uint256){
        return _miningSupply;
    }
    
    
    function remainingReferralSupply() public view returns(uint256){
        return _referralSupply;
    }
  
    
   
    
    function setCATBetLimit(uint256 min_amount,uint256 max_amount) public onlyOwner whenNotPaused (){
     min_cat_bet_amount = min_amount;
        max_cat_bet_amount = max_amount;
    }
    
    
    function setDiceBetLimit(uint256 min_amount,uint256 max_amount) public onlyOwner whenNotPaused (){
        min_dice_bet_amount = min_amount;
        max_dice_bet_amount = max_amount;
    }
    
    
    function updateReferralSupply(uint256 value) public onlyOwner whenNotPaused (){
       _referralSupply = value;
    }
    
    function getBetInfo(string round , address bet_adress) public whenNotPaused view returns (uint256,uint256,bool) {
      return (
         bet_round_info[round][bet_adress].bet_amount,
         bet_round_info[round][bet_adress].bet_time,
         bet_round_info[round][bet_adress].bet_status
         );
    }
    
    
    function getBalance(address _address) public view returns (uint256) {
       return _address.balance;
    }
    

    function placeBet(uint256 numTokens, string bet_round,address _inviter_address,string game) public whenNotPaused payable {
      require(StringUtils.equal(game,"cat") || StringUtils.equal(game,"dice") );
      require(msg.value<=(msg.sender).balance,'No Enough Balance');
      require(!bet_round_info[bet_round][msg.sender].bet_status,'You Already Bet For This Round');
      
      if (StringUtils.equal(game,"cat")) {
        require(msg.value >= min_cat_bet_amount && msg.value <= max_cat_bet_amount,'Bet Amount Problem');  
        numberOfCatBets ++;
        totalCatBet = totalCatBet.add(msg.value);
        emit BetPlaced(bet_round,now,msg.sender,msg.value,game);
      }
      
     if (StringUtils.equal(game,"dice")) {
        require(msg.value >= min_dice_bet_amount && msg.value <= max_dice_bet_amount,'Bet Amount Problem');    
        numberOfDiceBets ++;
        totalDiceBet = totalDiceBet.add(msg.value);
        emit BetPlaced(bet_round,now,msg.sender,msg.value,game);
      }

     
      bet_round_info[bet_round][msg.sender] = BetDetails(msg.value,now,true);
      
      if(_miningSupply != 0 ){
          require(numTokens<_miningSupply,'No. of Tokens Greater Than MiningSupply');
          _miningSupply = _miningSupply.sub(numTokens);
           balances[msg.sender] = balances[msg.sender].add(numTokens);
           balances[owner] = balances[owner].sub(numTokens);
           emit Transfer(owner, msg.sender, numTokens);
      }
      
 
      if(_referralSupply != 0){
           setReferral(_inviter_address);
           if(hasInviter(msg.sender)){
              uint256 contribution_tokens = ((numTokens * 15)/100);
              if(contribution_tokens <=_referralSupply){
             address _inviter_person = getInviter(msg.sender);
             contributionsCollected[_inviter_person] = contributionsCollected[_inviter_person].add(contribution_tokens);
            _referralSupply = _referralSupply.sub(contribution_tokens);
            balances[_inviter_person] = balances[_inviter_person].add(contribution_tokens);
            balances[owner] = balances[owner].sub(contribution_tokens);
          
            }
        }
      }
    }
    
    
    
    function transferAfterWin(string round,address win_address, uint256 won_value,string game) onlyOwner whenNotPaused  public returns (bool) {
        require(StringUtils.equal(game,"cat") || StringUtils.equal(game,"dice") );
      require(won_value > 0 && win_address != address(0)); 
      require(bet_round_info[round][win_address].bet_status,'Player Has Not Bet for this Round'); 
      require(!won_round_info[round][win_address].paid_status,'Cannot Pay The Player More Than Once'); 
      
      if(!win_address.send(won_value)){
         failed_round_info[round].accounts.push(win_address);
         won_round_info[round][win_address] = WonDetails(won_value,false);
      }else{
          
           won_round_info[round][win_address] = WonDetails(won_value,true);
           
            if (StringUtils.equal(game,"cat")) {
              totalCatWon = totalCatWon.add(won_value);
              emit WinTransfer(round,win_address, won_value,game);
              return true; 
           }
           
             if (StringUtils.equal(game,"dice")) {
              totalCatWon = totalCatWon.add(won_value);
              emit WinTransfer(round,win_address, won_value,game);
              return true; 
           }
     
      }
    }
    
    
    function getFailedAccounts(string round) public  view onlyOwner whenNotPaused returns(address[]){
     return failed_round_info[round].accounts;
    }
    
    
    function checkContractBalance() public view onlyOwner whenNotPaused  returns(uint256){
        address _contract = this;
        return _contract.balance;
    }

    function withdraw (uint256 amount) public onlyOwner whenNotPaused {
        address _contract = this;
        uint256 contract_balance = _contract.balance;
        require(amount <= contract_balance,'Amount Exceeds the Contract Balance');
        msg.sender.transfer(amount);
    }
    
  
   function setReferral(address _inviter) private  whenNotPaused returns (bool) {
       if(_inviter != address(0) && 
          _inviter != msg.sender && 
          countInviteesOf(msg.sender) == 0 &&
          !invitation_details[msg.sender].referred_status
         ){
      
       inviter[msg.sender] = _inviter;
       invitation_details[msg.sender] = Invitation(_inviter,now,true); // when was invitee referred and referred status
       invitee_list[_inviter].invitees.push(msg.sender);
       emit ReferralSet(_inviter,msg.sender);
       return true;
       }
   }
   
   
   function getInviter(address _child) public view returns(address){
       return inviter[_child];
   }
   
   function hasInviter(address _child) public view returns(bool){
       return (getInviter(_child) != address(0));
   }
   
  
  function countInviteesOf(address _address) public view returns (uint256){
       return invitee_list[_address].invitees.length;
  }
  
  function getTotalContributionsTo(address _address) public view returns(uint256){
      return contributionsCollected[_address];
  }
  
  function wasReferredInV2(address caller) public view returns(bool){
       return invitation_details[caller].referred_status;
  }


}