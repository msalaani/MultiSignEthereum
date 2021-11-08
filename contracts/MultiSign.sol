// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract MultiSign {


  // constatnts
  bytes32 NAME_HASH = 0xa2743967920baf970a18574423a5e903484167f01ff6c1b931ebc9e87d7792b9;
  bytes32 VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;
  bytes32 SALT = 0x591f92c04bedf51c4d4ab63da86ce895de5a497600061375b667f522f38e3ada;

  // events
  event Deposit(address indexed sender, uint amount, uint balance);
  event SubmitTransaction(
      address indexed owner,
      uint indexed txIndex,
      address indexed to,
      uint value,
      bytes data
  );
  event ConfirmTransaction(address indexed owner, uint indexed txIndex);
  event RevokeConfirmation(address indexed owner, uint indexed txIndex);
  event ExecuteTransaction(address indexed owner, uint indexed txIndex, bool success);

  address[] public owners; // list of owners
  mapping (address => bool) isOwner; // only unique owners
  uint public numConfirmationsRequired; // Threshold

  mapping(uint => mapping(address => bool)) public isConfirmed; // testing if transaction is confirmed
  mapping (uint => bool ) public existingTX; 
  struct Transaction {
    //uint id;
    address to;
    uint value;
    bytes data;
    bool executed;
    uint numConfirmations;
  } // transaction attributes

  // functions for hashing and verifiying
  //begin
  // modif2, replacing string memory
  function hashTX(bytes memory _message)
  public
  pure
  returns (bytes32){
    return keccak256(abi.encodePacked(_message));
  }

  function EthSgTXHsh(bytes32 _messageHash)
  public
  pure
  returns (bytes32)
  {
    return keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32",_messageHash)
      );
  }

  // using double hashing for data taking 32bytes long
  // the same as hashmessage in web3
  function EthSgTXHsh2(bytes memory _messageHash)
  public
  pure
  returns (bytes32)
  {
    return keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32",_messageHash)
      );
  }
  
  function TXSgHsh(Transaction memory _transaction)
  public
  pure
  //view
  returns (bytes32)
  {
    return keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32",
        _transaction.to,
        _transaction.value,
        _transaction.data
        )
      );
  }

  function getTXHashfromID(uint _txIndex)
  public
  view
  txExists(_txIndex)
  returns (bytes32)
  {
    return TXSgHsh(transactions[0]);
  }

  function checkSignature(bytes32 h, uint8 v, bytes32 r, bytes32 s)
  public
  pure
  returns (address signer)
  {
      
    bytes32 prefixedHash = EthSgTXHsh(h);  
    signer = ecrecover(prefixedHash, v, r, s);
    return signer;
  }  
  // end

  Transaction[] public transactions; // transactions list

  constructor( address[] memory _owners, uint _numConfirmationsRequired) {
    require( _owners.length > 0, "Owners required!" );
    require( _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of required confirmations!" );
    

    for (uint i = 0; i < _owners.length; i++){
      address owner = _owners[i];

      require(owner != address(0), "Invalid owner!");
      require( !isOwner[owner], "Owner not unique!" );
      isOwner[owner] = true;
      owners.push(owner); // adding owner
    } 

    numConfirmationsRequired = _numConfirmationsRequired; // setting threshold
  }


  modifier onlyOwner () {
    require (isOwner[msg.sender], "Not Owner!");
    _;
  }

  // first solution to find if transaction exists
  modifier txExists( uint _txIndex ) {
    require( _txIndex < transactions.length );
    _;
  }

  // second solution to find if transaction exists
  /*
  function setTXInd (uint _txIndex) public {
    existingTX[ _txIndex ] = true;
  }

  function txExist ( uint _txIndex ) public returns (bool) {
    return existingTX[ _txIndex ];
  }
  */
  // end solution

  // if tx is not executed
  modifier notExecuted( uint _txIndex ) {
    require( !transactions[_txIndex].executed, "TX already executed!" );
    _;
  }

  // if tx not confirmed
  modifier notConfirmed( uint _txIndex ){
    require(!isConfirmed[_txIndex][msg.sender], "TX already confirmed!");
    _;
  }

  // other owners confirm
  function confirmTransaction( uint _txIndex )
  public
  onlyOwner
  txExists(_txIndex)
  notExecuted(_txIndex)
  notConfirmed(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    isConfirmed[_txIndex][msg.sender] = true;
    transaction.numConfirmations += 1;
    emit ConfirmTransaction(msg.sender, _txIndex);
  }

  // if enough owners agree we execute
  // modif1: adding tx verif
  // modif1, adding params sigvrs
  function executeTransaction( uint _txIndex, uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS)
  public
  payable
  onlyOwner
  txExists(_txIndex)
  notExecuted(_txIndex)
  {
    // modif1
    // begin
    require(sigR.length == sigS.length && sigR.length == sigV.length && sigV.length >= numConfirmationsRequired, "Not matching sizes!");
    //  end
    require (transactions[_txIndex].numConfirmations >= numConfirmationsRequired && transactions[_txIndex].numConfirmations <= owners.length, "Invalid number of confirmations when execution!");
    Transaction storage transaction = transactions[_txIndex];
    // modif 1
    //bytes32 txhash = hashTX(transaction.data);
    // bytes32 txhash = EthSgTXHsh2(transaction.data);
    bytes32 txhash = TXSgHsh(transaction);

    for (uint i = 0; i < numConfirmationsRequired; i++) {
      address recoveredAddress = checkSignature(txhash, sigV[i], sigR[i], sigS[i]);
      if (!(isOwner[recoveredAddress])){
        transactions[_txIndex].numConfirmations -= 1;
        revert("TX Verification FAILED!");
    }
    }
    // end modif1
    
    // call using payable address
    address payable receiverAddr = payable(transaction.to);
    // for ol versions
    //address payable receiverAddr = address(uint160(transaction.to));
    (bool success, ) = receiverAddr.call(abi.encode(transaction.data));
      
    require(success, "TX failed!");
    transaction.executed = true;
    emit ExecuteTransaction(msg.sender, _txIndex, true);
    //emit ExecuteTransaction(msg.sender, _txIndex);
  }

  // signer revokes transaction
  function revokeConfirmation(uint _txIndex)
      public
      onlyOwner
      txExists(_txIndex)
      notExecuted(_txIndex)
  {
      Transaction storage transaction = transactions[_txIndex];

      require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

      transaction.numConfirmations -= 1;
      isConfirmed[_txIndex][msg.sender] = false;

      emit RevokeConfirmation(msg.sender, _txIndex);
  }

  // owner propse transaction
  function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

  function getTransaction(uint _txIndex)
      public
      view
      returns (
          address to,
          uint value,
          bytes memory data,
          bool executed,
          uint numConfirmations
      )
  {
      Transaction storage transaction = transactions[_txIndex];

      return (
          transaction.to,
          transaction.value,
          transaction.data,
          transaction.executed,
          transaction.numConfirmations
      );
  }

  function getOwners()
  public
  view
  returns (address[] memory)
  {
    return owners;
  }

  // for testing
  function gettrd(uint _txIndex)
  public
  view
  returns (bytes32)
  {
    Transaction storage transaction = transactions[_txIndex];
    bytes32 txhash = EthSgTXHsh2(transaction.data);
    //bytes32 txhash = EthSgTXHsh(txhash);
    return txhash;
  }

  function getthisbal()
  public
  view
  returns (uint) {
    return address(this).balance ;
  } 

  // end testing
  
  receive() external payable {
      emit Deposit(msg.sender, msg.value, address(this).balance);
  }
}
