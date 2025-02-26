// SPDX-License-Identifier: MIT 
pragma solidity 0.8.28;

import {ShadowBalanceTree} from "./ShadowBalanceTree.sol";
import {IncomingBalanceTree} from "./IncomingBalanceTree.sol";
import {ERC20} from "./ERC20.sol";
import {MerkleStateBase} from "./MerkleStateBase.sol";

import "poseidon-solidity/PoseidonT3.sol";

contract UltraAnon is ERC20, ShadowBalanceTree, IncomingBalanceTree {
    mapping (address=>uint32) public merkleIndexOfAccount; // 0 == doesn't exist, realIndex = merkleIndexOfAccount[_address]-1
                                                            // this because mapping will return 0 by default even if it was never set
      
    //_levels = depth of the tree                                                        
    constructor(uint32 _levels) ERC20("UltraAnon", "ULTR") MerkleStateBase(_levels) {
        // initialize IncomingBalanceTree
        for (uint32 i = 0; i < levels; i++) {
            incomBalAllFilledSubtrees[i][0] = zeros(i);
        }
        incomBalRoots[0] = zeros(levels);

        // initialize ShadowBalanceTree
        for (uint32 i = 0; i < levels; i++) {
            shadowFilledSubtrees[i] = zeros(i);
        }
        shadowRoots[0] = zeros(levels);
    }
    
    function privateTransfer() public {
        // TODO
        // check roots
        // check doesn't exist yet nullifierKey

        // format public inputs(transferAmount, nullifierValue, nullifierKey, shadowBalanceRoot, incomingBalanceRoot, recipientAccount)
        // verify proof

        // function add nullifier 
            // add nullifier 
            // nullifiers[nullifierKey] = nullifierValue

            // insert into shadowBalanceTree
            // uint256 shadowBalanceLeaf = hashShadowBalanceLeaf(nullifierKey, nullifierValue);
            // _shadowBalanceInsert(shadowBalanceLeaf)
            
            // track nullifierKey -> amountSpent, so user can reproduce their shadowBalance
            // emit event nullifierKeyAdded(nullifierKey indexed, transferAmount)
            // also track amount spend per nullifierKey so its easier to sync
    }

    function hashIncomBalTreeLeaf(address _address, uint256 _balance) public pure returns(uint256){
        uint256[2] memory preimg = [uint256(uint160(_address)), _balance];
        return  PoseidonT3.hash(preimg);
    }

    function hashShadowBalanceLeaf(uint256 nullifierKey, uint256 nullifierValue) public pure returns(uint256){
        uint256[2] memory preimg = [nullifierKey, nullifierValue];
        return  PoseidonT3.hash(preimg);
    }

    function _updateIncomingBalanceTree(address _address, uint256 _newBalance) private {
        uint32 addressIndex = merkleIndexOfAccount[_address];
        uint256 leaf =  hashIncomBalTreeLeaf(_address, _newBalance);
        if (addressIndex == 0) { // 0= not in here yet
            uint32 index = _incomBalInsert(leaf);
            merkleIndexOfAccount[_address] = index+1;
        } else {
            _incomBalUpdate(leaf, addressIndex-1);
        }

    }

    //WARNING public mint functionl, anyone can call this!!
    function mint(address account, uint256 value) public {
        _mint(account,value);
    }


    // TODO does this override work when its outside of the contract using this function?
    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) override internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                uint256 newBalance = fromBalance - value;
                _balances[from] = newBalance;
                // only incoming so we don't update from (its outgoing for out "from" guy)
                //_updateIncomingBalanceTree(from, newBalance);
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                uint256 newBalance = _balances[to] + value;
                _balances[to] = newBalance;
                _updateIncomingBalanceTree(to, newBalance);
            }
        }

        emit Transfer(from, to, value);
    }


}

