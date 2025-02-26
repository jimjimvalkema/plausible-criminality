// https://tornado.cash
/*
 * d888888P                                           dP              a88888b.                   dP
 *    88                                              88             d8'   `88                   88
 *    88    .d8888b. 88d888b. 88d888b. .d8888b. .d888b88 .d8888b.    88        .d8888b. .d8888b. 88d888b.
 *    88    88'  `88 88'  `88 88'  `88 88'  `88 88'  `88 88'  `88    88        88'  `88 Y8ooooo. 88'  `88
 *    88    88.  .88 88       88    88 88.  .88 88.  .88 88.  .88 dP Y8.   .88 88.  .88       88 88    88
 *    dP    `88888P' dP       dP    dP `88888P8 `88888P8 `88888P' 88  Y88888P' `88888P8 `88888P' dP    dP
 * ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
 * and a little bit of ultraAnon :D
 */

// inspired by tornadocashes merkle tree with history but it allows leafs to change after they're added
// https://github.com/tornadocash/tornado-core/blob/master/contracts/MerkleTreeWithHistory.sol
// also emits events on every insert here instead of the parent contract

// renamed 
// incomBal specific state
  // incomBalFilledSubtrees
  // incomBalRoots
  // incomBalCurrentRootIndex
  // incomBalNextIndex

// incomBal specific write functions
  // _incomBalInsert
  // _incomBalUpdate

// incomBal specific read functions
  // incomBalIsKnownRoot
  // incomBalGetLastRoot

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MerkleStateBase} from "./MerkleStateBase.sol";


// shadow specific state
  // shadowFilledSubtrees
  // shadowRoots
  // shadowCurrentRootIndex
  // shadowNextIndex

// shadow specific write functions
  // _shadowInsert

// shadow specific read functions
  // shadowIsKnownRoot
  // shadowGetLastRoot

// shadow specific hashing
  // hashPublicBalanceLeaf
abstract contract IncomingBalanceTree is MerkleStateBase {
  event IncomBalNewLeaf(uint256 indexed leaf, uint32 leafIndex, uint256 timestamp);
  event IncomBalUpdatedLeaf(uint256 indexed leaf, uint32 leafIndex, uint256 timestamp);

  mapping(uint256 => mapping(uint256=> uint256)) public incomBalAllFilledSubtrees; // TODO should be a flat array somehow
  mapping(uint256 => uint256) public incomBalRoots;
  uint32 public incomBalCurrentRootIndex = 0;
  uint32 public incomBalNextIndex = 0;

  // insert new leaf
  function _incomBalInsert(uint256 _leaf) internal returns (uint32 index) {
    uint32 _nextIndex = incomBalNextIndex;
    require(_nextIndex != uint32(2)**levels, "Merkle tree is full. No more leaves can be added");
    uint32 currentIndex = _nextIndex;
    uint256 currentLevelHash = _leaf;
    uint256 left;
    uint256 right;

    for (uint32 i = 0; i < levels; i++) {
      incomBalAllFilledSubtrees[i][currentIndex] = currentLevelHash;
      if (currentIndex % 2 == 0) {
        left = currentLevelHash;
        right = zeros(i);
      } else {
        left = incomBalAllFilledSubtrees[i][currentIndex-1];
        right = currentLevelHash;
        require(left != 0, "cant use a 0 value from incomBalAllFilledSubtrees"); //TODO this is sanity check can we remove it?
        
      }
      currentLevelHash = hashLeftRight(left, right);
      currentIndex /= 2;
    }

    uint32 newRootIndex = (incomBalCurrentRootIndex + 1) % ROOT_HISTORY_SIZE;
    incomBalCurrentRootIndex = newRootIndex;
    incomBalRoots[newRootIndex] = currentLevelHash;
    incomBalNextIndex = _nextIndex + 1;

    emit IncomBalNewLeaf(_leaf, _nextIndex, block.timestamp);
    return _nextIndex;
  }

  // update existing leaf
  function _incomBalUpdate(uint256 _leaf, uint32 _index) internal {
    require(_index < incomBalNextIndex, "can only update existing values");
    uint32 currentIndex = _index;
    uint256 currentLevelHash = _leaf;
    uint256 left;
    uint256 right;

    for (uint32 i = 0; i < levels; i++) {
      incomBalAllFilledSubtrees[i][currentIndex] = currentLevelHash;
      if (currentIndex % 2 == 0) {
        left = currentLevelHash;
        right = incomBalAllFilledSubtrees[i][currentIndex+1];
        if(right==0) { //double check this shit.
          right = zeros(i);
        }
        require(right != 0, "right cant be 0 value from incomBalAllFilledSubtrees"); //TODO this is sanity check can we remove it?
      } else {
        left = incomBalAllFilledSubtrees[i][currentIndex-1];
        // if(left==0) { is it safe to remove this? left should alway be filled
        //   left = zeros(i);
        // }
        right = currentLevelHash;

        require(left != 0, "left cant be 0 value from incomBalAllFilledSubtrees"); //TODO this is sanity check can we remove it?
      }
      currentLevelHash = hashLeftRight(left, right);
      currentIndex /= 2;
    }

    uint32 newRootIndex = (incomBalCurrentRootIndex + 1) % ROOT_HISTORY_SIZE;
    incomBalCurrentRootIndex = newRootIndex;
    incomBalRoots[newRootIndex] = currentLevelHash;

    emit IncomBalUpdatedLeaf(_leaf, _index, block.timestamp);
  }


  /**
    @dev Whether the root is present in the root history
  */
  function incomBalIsKnownRoot(uint256 _root) public view returns (bool) {
    if (_root == 0) {
      return false;
    }
    uint32 _currentRootIndex = incomBalCurrentRootIndex;
    uint32 i = _currentRootIndex;
    do {
      if (_root ==  incomBalRoots[i]) {
        return true;
      }
      if (i == 0) {
        i = ROOT_HISTORY_SIZE;
      }
      i--;
    } while (i != _currentRootIndex);
    return false;
  }

  /**
    @dev Returns the last root
  */
  function incomBalGetLastRoot() public view returns (uint256) {
    return  incomBalRoots[incomBalCurrentRootIndex];
  }
}