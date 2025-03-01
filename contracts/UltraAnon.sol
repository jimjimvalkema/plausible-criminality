// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ShadowBalanceTree} from "./ShadowBalanceTree.sol";
import {IncomingBalanceTree} from "./IncomingBalanceTree.sol";
import {ModifiedERC20} from "./ModifiedERC20.sol";
import {MerkleStateBase} from "./MerkleStateBase.sol";

import "poseidon-solidity/PoseidonT3.sol";

interface IUltraVerifier {
    function verify(
        bytes calldata _proof,
        bytes32[] calldata _publicInputs
    ) external view returns (bool);
}

contract UltraAnon is ModifiedERC20, ShadowBalanceTree, IncomingBalanceTree {
    event NullifierAdded(uint256 indexed nullifierKey, uint256 amountSent);

    mapping(address => uint32) public merkleIndexOfAccount; // 0 == doesn't exist, realIndex = merkleIndexOfAccount[_address]-1
    // this because mapping will return 0 by default even if it was never set

    mapping(address => uint256) public incomingBalance; // Increases on receiving private and public txns


    mapping(uint256 => uint256) public nullifiers; // nullifierKey=>nullifierValue

    address public privateTransferVerifier;
    address public publicTransferVerifier;

    //_levels = depth of the tree
    constructor(
        uint32 _levels,
        address _privateTransferVerifier,
        address _publicTransferVerifier
    ) ModifiedERC20("UltraAnon", "ULTR") MerkleStateBase(_levels) {
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

        privateTransferVerifier = _privateTransferVerifier;
        publicTransferVerifier = _publicTransferVerifier;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */

    function publicTransfer(
        address to,
        uint256 value,
        uint256 nullifierValue,
        uint256 nullifierKey,
        uint256 shadowBalanceRoot,
        uint256 incomingBalanceRoot,
        address owner,
        bytes calldata proof
    ) external override returns (bool) {
        //check roots
        require(
            shadowIsKnownRoot(shadowBalanceRoot),
            "shadowBalance root is not known by the contract. Its either stale or invalid"
        );
        require(
            incomBalIsKnownRoot(incomingBalanceRoot),
            "incomingBalance root is not known by the contract. Its either stale or invalid"
        );

        addNullifier(nullifierKey, nullifierValue);
        // track nullifierKey -> amountSpent, so user can reproduce their shadowBalance
        emit NullifierAdded(nullifierKey, value);
        // maybe also track amount spend per nullifierKey inside mapping so its easier to sync?

        _transfer(owner, to, value);

        require(
            verifyPublicTransferProof(
                value,
                nullifierValue,
                nullifierKey,
                shadowBalanceRoot,
                incomingBalanceRoot,
                to,
                owner,
                proof
            ),
            "Was not able to verify proof. Owner might not have enough funds to transfer"
        );

        return true;
    }

    function verifyPublicTransferProof(
        uint256 transferAmount,
        uint256 nullifierValue,
        uint256 nullifierKey,
        uint256 previousShadowBalanceRoot,
        uint256 incomingBalanceRoot,
        address recipientAccount,
        address senderAccount,
        bytes calldata proof
    ) internal view returns (bool) {
        bytes32[] memory publicInputs = new bytes32[](7);

        // Convert each input to bytes32 and add to array
        publicInputs[0] = bytes32(transferAmount);
        publicInputs[1] = bytes32(nullifierValue);
        publicInputs[2] = bytes32(nullifierKey);
        publicInputs[3] = bytes32(previousShadowBalanceRoot);
        publicInputs[4] = bytes32(incomingBalanceRoot);

        // For addresses, we need to convert them to uint256 first
        // by padding them with zeros on the left
        publicInputs[5] = bytes32(uint256(uint160(recipientAccount)));
        publicInputs[6] = bytes32(uint256(uint160(senderAccount)));

        return
            IUltraVerifier(publicTransferVerifier).verify(proof, publicInputs);
    }

    function privateTransfer(
        address to,
        uint256 value,
        uint256 nullifierValue,
        uint256 nullifierKey,
        uint256 shadowBalanceRoot,
        uint256 incomingBalanceRoot,
        bytes calldata proof
    ) external override returns (bool) {
        //check roots
        require(
            shadowIsKnownRoot(shadowBalanceRoot),
            "shadowBalance root is not known by the contract. Its either stale or invalid"
        );
        require(
            incomBalIsKnownRoot(incomingBalanceRoot),
            "incomingBalance root is not known by the contract. Its either stale or invalid"
        );

        addNullifier(nullifierKey, nullifierValue);
        // track nullifierKey -> amountSpent, so user can reproduce their shadowBalance
        emit NullifierAdded(nullifierKey, value);
        // maybe also track amount spend per nullifierKey inside mapping so its easier to sync?

        // update the balance (cant use _transfer or _update since those need a from address )
        _balances[to] = _balances[to] + value;
        _updateIncomingBalanceTree(to, _balances[to]);
        incomingBalance[to] += value;

        emit Transfer(address(0), to, value);

        require(
            verifyPrivateTransferProof(
                value,
                nullifierValue,
                nullifierKey,
                shadowBalanceRoot,
                incomingBalanceRoot,
                to,
                proof
            ),
            "Was not able to verify proof. Owner might not have enough funds to transfer"
        );

        return true;
    }

    function verifyPrivateTransferProof(
        uint256 transferAmount,
        uint256 nullifierValue,
        uint256 nullifierKey,
        uint256 previousShadowBalanceRoot,
        uint256 incomingBalanceRoot,
        address recipientAccount,
        bytes calldata proof
    ) internal view returns (bool) {
        bytes32[] memory publicInputs = new bytes32[](6);

        // Convert each input to bytes32 and add to array
        publicInputs[0] = bytes32(transferAmount);
        publicInputs[1] = bytes32(nullifierValue);
        publicInputs[2] = bytes32(nullifierKey);
        publicInputs[3] = bytes32(previousShadowBalanceRoot);
        publicInputs[4] = bytes32(incomingBalanceRoot);

        // For addresses, we need to convert them to uint256 first
        // by padding them with zeros on the left
        publicInputs[5] = bytes32(uint256(uint160(recipientAccount)));

        return
            IUltraVerifier(privateTransferVerifier).verify(proof, publicInputs);
    }

    function addNullifier(
        uint256 nullifierKey,
        uint256 nullifierValue
    ) private {
        // check that nullifierKey doesn't exist yet
        require(
            nullifiers[nullifierKey] == 0,
            "nullifierKey cant be used twice"
        );

        // add nullifier
        nullifiers[nullifierKey] = nullifierValue;

        // insert into shadowBalanceTree
        uint256 shadowBalanceLeaf = hashShadowBalanceLeaf(
            nullifierKey,
            nullifierValue
        );
        _shadowInsert(shadowBalanceLeaf);
    }

    function hashIncomBalTreeLeaf(
        address _address,
        uint256 _balance
    ) public pure returns (uint256) {
        uint256[2] memory preimg = [uint256(uint160(_address)), _balance];
        return PoseidonT3.hash(preimg);
    }

    function hashShadowBalanceLeaf(
        uint256 nullifierKey,
        uint256 nullifierValue
    ) public pure returns (uint256) {
        uint256[2] memory preimg = [nullifierKey, nullifierValue];
        return PoseidonT3.hash(preimg);
    }

    function _updateIncomingBalanceTree(
        address _address,
        uint256 _newBalance
    ) private {
        uint32 addressIndex = merkleIndexOfAccount[_address];
        uint256 leaf = hashIncomBalTreeLeaf(_address, _newBalance);
        if (addressIndex == 0) {
            // 0= not in here yet
            uint32 index = _incomBalInsert(leaf);
            merkleIndexOfAccount[_address] = index + 1;
        } else {
            _incomBalUpdate(leaf, addressIndex - 1);
        }
    }

    //WARNING public mint functionl, anyone can call this!!
    function mint(address account, uint256 value) public {
        _mint(account, value);
    }

    // TODO does this override work when its outside of the contract using this function?
    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual override {
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
                incomingBalance[to] += value;
                _updateIncomingBalanceTree(to, incomingBalance[to]);

            }
        }
        emit Transfer(from, to, value);
    }
}
