// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.4;

/// @title FAsset. An ERC20 token with past block memory that supports voting 
/// @author Carson Case
contract FAsset{
    
    /// @notice public state variables
    uint256 public decimals;
    uint256 public supply;
    string public name;
    string public symbol;
    uint256 percentPercision;
    uint256 delegatingLimit = 5;
    uint256 delegationTableCount = 1;

    //mapping of users which holds the current information on them
    mapping(address => user) users;
    //struct for user which holds various information about a user inlcuding balance
    struct user{
        uint256 balance;
        uint256 delegationPointer;
        uint256 percentShareOfOwnTokens;
        uint256 delegationCount;
    }

    //mapping of checkpoints which hold past user information from past blocks
    mapping(address => checkpoint[]) checkpoints;
    //struct for checkpoint
    struct checkpoint{
        uint256 blockNumber;
        user u;
    }

    //mapping for the delegation pointers to a delegation array
    mapping(uint256=>delegation[]) delegationTables;
    //struct for a delegation. Each user has an array of delegations which shows who has granted them how much percent voting power
    struct delegation{
        address grantedBy;
        uint256 percentAmmount;
    }

    //Mapping for erc20 transfer approvals
    mapping(address => mapping(address => uint256)) approved;

    ////////////////////
    ///constructor
    ///////////////////
    
    /// @notice ERC20 is $FASS with a simple dev fee
    /// @param _decimals is the number of decimals token can be broken into
    /// @param _devFee is the dev fee given in whole tokens (not decimals)
    /// @param _precision is the number of digits allowed in percent calculation
    /// @param _delegationLimit is the number of accounts each person can delegate to (5)
    /// @param _name is the tokens name
    /// @param _symbol is the tokens symbol
    constructor(
        uint256 _decimals,
        uint256 _devFee,
        uint256 _precision,
        uint256 _delegationLimit,
        string memory _name,
        string memory _symbol
        ){
        decimals = _decimals;
        percentPercision = _precision;
        delegatingLimit = _delegationLimit;
        name = _name;
        symbol = _symbol;
        _mint(msg.sender,_devFee);
    }

    ////////////////////
    ///ERC20 methods
    ////////////////////  

    /// @notice totalSupply gets total supply of tokens
    /// @return uint256 as supply
    function totalSupply() public view returns(uint256){
        return supply;
    }

    /// @notice returns balance of an account
    /// @param _who as who to return the balance of
    /// @return uint256 as balance
    function balanceOf(address _who) public view returns(uint256){
        return users[_who].balance;
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
        require(users[msg.sender].balance >= _ammount, "from address does not have the tokens required for this transaction");
        
        users[msg.sender].balance -= _ammount;
        users[_receiver].balance += _ammount;
        
        _set2Checkpoints(msg.sender, _receiver);

        emit Transfer(msg.sender, _receiver, _ammount);
        return true;
    }
    
    /// @notice transfer tokens from one person to another
    /// @param _from is who from
    /// @param _to is who to
    /// @param _ammount is how much
    /// @return bool if successful
    function transferFrom(address _from, address _to, uint256 _ammount) public returns(bool){
        uint256 allowed = approved[_from][_to];
        require(allowed >= _ammount,"Transaction of this size not approved"); 
        require(users[_from].balance >= _ammount,"from address does not have the tokens required for this transaction");
                
        users[_from].balance -= _ammount;
        users[_to].balance += _ammount;
        
        _set2Checkpoints(_from, _to);

        approved[_from][_to] = allowed - _ammount;
        
        emit Transfer(_from,_to,_ammount);
        
        return true;
    }

    ////////////////////
    ///New Functions
    ////////////////////
    
    /// @notice balanceOfAt gets balance at a particular block
    /// @param _who is who to look up 
    /// @param _block is the block number to lookup
    /// @return uint256 as balance
    function balanceOfAt(address _who, uint _block) public view returns(uint256){
        uint256 i = _search(checkpoints[_who],_block,0,checkpoints[_who].length);

        return (checkpoints[_who][i].u.balance);
    }

    /// @notice votePowerAt gets the vote power at a certain block. Looks up the current 
    /// @notice note the return is a percentage as defined by precision! Not a value
    /// @param _who is who to look up
    /// @param _block is the block to look at
    /// @return uint256 of what the vote power was. This will need to be divided by percent precision
    function votePowerAt(address _who, uint _block) public view returns(uint256){
        //The long process of getting the delegation array at a certain block...
        uint256 cpIndex = _search(checkpoints[_who],_block, 0, checkpoints[_who].length);
        uint256 p = checkpoints[_who][cpIndex].u.delegationPointer;
        delegation[] memory arr = delegationTables[p];

        //Sum starts with share of own tokens
        uint256 sum = _getShare(_who) * balanceOfAt(_who, _block);

        //Then add up the percent ownership * balance of those delegating to you

        for(uint i; i < arr.length; i++){
            uint256 percentOwnership = arr[i].percentAmmount;
            address ownershipOf = arr[i].grantedBy;
            sum +=  percentOwnership * balanceOfAt(ownershipOf,_block);
        }


        return(sum);

    }
    
    /// @notice delegate lets you delegate tokens to annother account
    /// @param _to is who to delegate to
    /// @param _percent is how much percent to delegate (in human readable percentages)
    function delegate(address _to, uint256 _percent) public{
        //NOTE this if statement handles removing delegations
        //This was thrown together last minute and really not quality code
        //Ideally I'd like to put this and the delegation bellow in private functions to simplify things
        //and also modify the _search() function (which has Olog(n) complexity as opppsed to this On) to search for any value
        //and use that to do a binary search here
        //Note to self to come back and work on this if I ever want to show this code off
        if(_percent == 0){
            delegation[] memory dt = delegationTables[users[_to].delegationPointer];
            for(uint i = 0; i < dt.length; i++){
                if(dt[i].grantedBy == msg.sender){
                    delete delegationTables[users[_to].delegationPointer][i];
                    _setShare(msg.sender,dt[i].percentAmmount,true);
                    _setCheckpoint(_to);
                }
            }
        }else{
            require(_percent <= 10**percentPercision, "cannot delegate more than 100%");
            require(users[_to].delegationCount < delegatingLimit,"you can only delegate to 5 people at most");
            require(_getShare(msg.sender) >= _percent, "You cannot delegate more than 100% of your token voting share");
            users[msg.sender].delegationCount++;
            
            //Subtract the percent from the sender's vote power
            _setShare(msg.sender, _percent, false);  //false for subtraction

            //If receiver has no delgations set up new delegation table/pointer
            if(users[_to].delegationPointer == 0){
                _initDelegationTable(_to);
            }

            //Add the percent to the receiver's delegation table
            delegationTables[users[_to].delegationPointer].push(
                delegation(
                msg.sender,
                _percent
                )
            );

            //Set a checkpoint after doing this
            _setCheckpoint(_to);
        }
    }


    /// @notice mint new tokens
    /// @param _ammount is how much to mint
    /// @param _to to who to mint to
    function _mint(address _to, uint256 _ammount) internal{
        require(_to != address(0), "cannot mint to 0 address");
        supply += _ammount;
        
        users[_to].balance += _ammount;

        _setCheckpoint(_to);

        emit Transfer(address(0),_to,_ammount);
    }

    ////////////////////
    ///helper functions
    ////////////////////
    
    /// @notice setCheckpoint creates a checkpoint for an address each time it's balance is modified
    /// @param _who is who we're noting
    function _setCheckpoint(address _who) internal{
        emit CheckpointSet(uint256(block.number),users[_who].balance);
        //If it's the first block push in an empty balance at 0 first
        if(checkpoints[_who].length == 0){
            checkpoints[_who].push(
                checkpoint(
                    0,
                    user(
                        0,
                        0,
                        0,
                        0
                    )
                )
            );
        }

        //Either way. Next push updated checkpoint
        checkpoints[_who].push(
            checkpoint({
                blockNumber: uint256(block.number),
                 u: user({
                    balance: users[_who].balance,
                    delegationPointer: users[_who].delegationPointer,
                    percentShareOfOwnTokens: users[_who].percentShareOfOwnTokens,
                    delegationCount: users[_who].delegationCount++
                 }) 
            })
        );

    }

    /// @notice sets checkpoints for a transfer where 2 people need them set
    /// @param _1 is first person
    /// @param _2 is second person
    function _set2Checkpoints(address _1, address _2) public{
        _setCheckpoint(_1);
        _setCheckpoint(_2);
    }

    /// @notice searches an array for the closest value below or equal to the target
    /// @param _arr is the array to search
    /// @param _target is the target to search for
    /// @param _start is the begining of the array to search (0 usually)
    /// @param _end is the end of the array to search (_arr.length usually)
    /// @return uint256 is the index in the array
    function _search(checkpoint[] memory _arr, uint256 _target, uint256 _start, uint256 _end) private view returns(uint256){
        if((_start + 1) == _end || _start == _end || _arr[_start].blockNumber == _target){
            return _start;
        }
        uint256 mid = ((_end - _start)/2)+_start;
        
        if(_target < _arr[mid].blockNumber){
            return _search(_arr,_target,_start,mid);
        }else{
            return _search(_arr,_target,mid,_end);
        }
    }
   
    /// @notice Helper function to get the share of voting someone has undelegated at a certain block
    /// @param _who is who to check
    /// @return uint256 of what percent is left to share
    function _getShare(address _who) private view returns(uint256){
        return((10**percentPercision)-users[_who].percentShareOfOwnTokens);
    }

    /// @notice helper function to set the current own voting share of someone
    /// @param _who is who
    /// @param _ammount is how much percent to change (remember to _toPercent() before passing in)
    /// @param _addition is a bool to signify if operation is + or -
    function _setShare(address _who, uint256 _ammount, bool _addition) private{
        if(_addition){
            require(int256(users[_who].percentShareOfOwnTokens) - int256(_ammount) >= 0);
            users[_who].percentShareOfOwnTokens -= _ammount;
        }else{
            require(users[_who].percentShareOfOwnTokens + _ammount <= 10**percentPercision);
            users[_who].percentShareOfOwnTokens += _ammount;
        }
    }

    /// @notice sets up new delegation table for a user
    /// @param _who is who to set up for
    function _initDelegationTable(address _who) private{
        users[_who].delegationPointer = delegationTableCount++;
    }

    ////////////////////
    ///Events
    ////////////////////    
    
    event Approval(address, address, uint256);
    event Transfer(address, address, uint256);
    event CheckpointSet(uint256, uint256);
    event Test(uint256);


}