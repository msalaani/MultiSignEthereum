// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract ReceiverContract {
  event Received(address caller, bytes sender_messager, uint amount, string message);
  bytes mg = msg.data;

  fallback() external payable {
      emit Received(msg.sender, mg, msg.value, "Fallback was called");
  }

  receive() external payable {
    emit Received(msg.sender, mg, msg.value, "Receive was called");
  }

}
