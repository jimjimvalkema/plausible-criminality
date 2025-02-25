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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MerkleStateBase} from "./MerkleStateBase.sol";


//shadowFilledSubtrees
//shadowRoots
//shadowCurrentRootIndex
//shadowNextIndex
abstract contract ShadowBalanceTree is MerkleStateBase {
  // constructor(uint32 _levels) {
  //   for (uint32 i = 0; i < levels; i++) {
  //     shadowFilledSubtrees[i] = zeros(i);
  //   }

  //   shadowRoots[0] = zeros(levels);
  // }
  // the following variables are made public for easier testing and debugging and
  // are not supposed to be accessed in regular code

  // shadowFilledSubtrees and shadowRoots could be bytes32[size], but using mappings makes it cheaper because
  // it removes index range check on every interaction
  mapping(uint256 => uint256) public shadowFilledSubtrees;
  mapping(uint256 => uint256) public shadowRoots;

  uint32 public shadowCurrentRootIndex = 0;
  uint32 public shadowNextIndex = 0;

  // constructor(uint32 _levels) {
  //   require(_levels > 0, "_levels should be greater than zero");
  //   require(_levels < 32, "_levels should be less than 32");
  //   levels = _levels;

  //   for (uint32 i = 0; i < _levels; i++) {
  //     shadowFilledSubtrees[i] = zeros(i);
  //   }

  //   shadowRoots[0] = zeros(_levels);
  // }

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