// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.4;

/// @title FAsset. An ERC20 token with past block memory that supports voting 
/// @author Carson Case
contract FAsset{
    
    uint256 decimals;
    uint256 supply;
    string name;
    string symbol;
    

    mapping(address => uint256) balanceOf;
    mapping(address => mapping(address => uint256)) approved;
    
    mapping(address => mapping(uint => uint256)) checkpoints;
    
    ////////////////////
    ///constructor
    ///////////////////
    
    /// @notice ERC20 is $FASS with a simple dev fee
    /// @param _decimals is the number of decimals token can be broken into
    /// @param _devFee is the dev fee given in whole tokens (not decimals)
    /// @param _name is the tokens name
    /// @param _symbol is the tokens symbol
    constructor(
        uint256 _decimals,
        uint256 _devFee,
        string memory _name,
        string memory _symbol
        ){
        decimals = _decimals;
        name = _name;
        symbol = _symbol;
        _mint(msg.sender,1000 * (10**uint256(_decimals)));
    }
    
    ////////////////////
    ///ERC20 methods
    ////////////////////  
    
    /// @notice totalSupply gets total supply of tokens
    /// @return uint256 as supply
    function totalSupply() public view returns(uint256){
        return supply;
    }
    
    /// @notice approve approves the use of tokens from one person to another
    /// @param _receiver is who we're allowing
    /// @param _ammount is how much
    /// @return bool if successful
    function approve(address _receiver, uint256 _ammount) public returns(bool){
        approved[msg.sender][_receiver] = _ammount;
        emit Approval(msg.sender, _receiver, _ammount);
        return true;
    }
    
    /// @notice transfer token to another person
    /// @param _receiver is who's receiving
    /// @param _ammount is how much
    /// @return bool if successful
    function transfer(address _receiver, uint256 _ammount) public returns(bool){
        require(balanceOf[msg.sender] >= _ammount, "from address does not have the tokens required for this transaction");
        require(_ammount > 0, "transaction ammount must be greater than 0");
        
        setCheckpoint(msg.sender);
        setCheckpoint(_receiver);
        
        balanceOf[msg.sender] -= _ammount;
        balanceOf[_receiver] += _ammount;
        
        emit Transfer(msg.sender, _receiver, _ammount);
    }
    
    /// @notice transfer tokens from one person to another
    /// @param _from is who from
    /// @param _to is who to
    /// @param _ammount is how much
    /// @return bool if successful
    function transferFrom(address _from, address _to, uint256 _ammount) public returns(bool){
        uint256 allowed = approved[_from][_to];
        require(allowed >= _ammount,"Transaction of this size not approved"); 
        require(balanceOf[_from] >= _ammount,"from address does not have the tokens required for this transaction");
        require(_ammount > 0, "transaction ammount must be greater than 0");
        
        setCheckpoint(_from);
        setCheckpoint(_to);
        
        balanceOf[_from] -= _ammount;
        balanceOf[_to] += _ammount;
        
        approved[_from][_to] = allowed - _ammount;
        
        emit Transfer(_from,_to,_ammount);
        
        return true;
    }
    
    /// @notice mint new tokens
    /// @param _ammount is how much to mint
    /// @param _to to who to mint to
    function _mint(address _to, uint256 _ammount) internal{
        require(_to != address(0), "cannot mint to 0 address");
        supply += _ammount;
        
        _setCheckpoint(_to);
        balanceOf[_to] += _ammount;
        
        emit Transfer(address(0),_to,_ammount);
    }
    ////////////////////
    ///New Functions
    ////////////////////
    
    /// @notice balanceOfAt gets balance at a particular block
    /// @param _who is who to look up 
    /// @param _block is the block number to lookup
    /// @returns uint256 as balance
    function balanceOfAt(address _who, uint _block) public view returns(uint256){
        return (checkpoints[_who][_block])
    }
    
    ////////////////////
    ///helper functions
    ////////////////////
    
    /// @notice setCheckpoint creates a checkpoint for an address each time it's balance is modified
    /// @param _who is who we're noting
    function _setCheckpoint(address _who) internal{
        uint256 balance = balanceOf[_who];
        checkpoints[_who][block.number] = balance;
    }
    
    
    ////////////////////
    ///Events
    ////////////////////    
    
    event Approval(address, address, uint256);
    event Transfer(address, address, uint256);
}
