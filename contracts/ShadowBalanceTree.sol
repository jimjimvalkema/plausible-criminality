// https://tornado.cash
/*
 * d888888P                                           dP              a88888b.                   dP
 *    88                                              88             d8'   `88                   88
 *    88    .d8888b. 88d888b. 88d888b. .d8888b. .d888b88 .d8888b.    88        .d8888b. .d8888b. 88d888b.
 *    88    88'  `88 88'  `88 88'  `88 88'  `88 88'  `88 88'  `88    88        88'  `88 Y8ooooo. 88'  `88
 *    88    88.  .88 88       88    88 88.  .88 88.  .88 88.  .88 dP Y8.   .88 88.  .88       88 88    88
 *    dP    `88888P' dP       dP    dP `88888P8 `88888P8 `88888P' 88  Y88888P' `88888P8 `88888P' dP    dP
 * ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
 */

// just like tornadocashes MerkleTreeWith history but some variable renamed to prevent conflicts during inheritance when using 2 trees in the contract
// https://github.com/tornadocash/tornado-core/blob/master/contracts/MerkleTreeWithHistory.sol
// also emits events on every insert here instead of the parent contract

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MerkleStateBase} from "./MerkleStateBase.sol";

// renamed 
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
abstract contract ShadowBalanceTree is MerkleStateBase {
  event ShadowNewLeaf(uint256 indexed leaf, uint32 leafIndex, uint256 timestamp);

  mapping(uint256 => uint256) public shadowFilledSubtrees;
  mapping(uint256 => uint256) public shadowRoots;

  uint32 public shadowCurrentRootIndex = 0;
  uint32 public shadowNextIndex = 0;

  function _shadowInsert(uint256 _leaf) internal returns (uint32 index) {
    uint32 _nextIndex = shadowNextIndex;
    require(_nextIndex != uint32(2)**levels, "Merkle tree is full. No more leaves can be added");
    uint32 currentIndex = _nextIndex;
    uint256 currentLevelHash = _leaf;
    uint256 left;
    uint256 right;

    for (uint32 i = 0; i < levels; i++) {
      if (currentIndex % 2 == 0) {
        left = currentLevelHash;
        right = zeros(i);
        shadowFilledSubtrees[i] = currentLevelHash;
      } else {
        left = shadowFilledSubtrees[i];
        right = currentLevelHash;
      }
      currentLevelHash = hashLeftRight(left, right);
      currentIndex /= 2;
    }

    uint32 newRootIndex = (shadowCurrentRootIndex + 1) % ROOT_HISTORY_SIZE;
    shadowCurrentRootIndex = newRootIndex;
    shadowRoots[newRootIndex] = currentLevelHash;
    shadowNextIndex = _nextIndex + 1;
    emit ShadowNewLeaf(_leaf, _nextIndex, block.timestamp);
    return _nextIndex;
  }

  /**
    @dev Whether the root is present in the root history
  */
  function shadowIsKnownRoot(uint256 _root) public view returns (bool) {
    if (_root == 0) {
      return false;
    }
    uint32 _currentRootIndex = shadowCurrentRootIndex;
    uint32 i = _currentRootIndex;
    do {
      if (_root == shadowRoots[i]) {
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
  function shadowGetLastRoot() public view returns (uint256) {
    return shadowRoots[shadowCurrentRootIndex];
  }
}