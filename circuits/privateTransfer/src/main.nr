use dep::transfer::transfer;

fn main(
    // ----- public inputs -----
    transfer_amount: pub Field,
    // Poseidon(prev_shadow_bal + transfer_amt, prev_nonce + 1, Secret)
    nullifier_value: pub Field,
    // Poseidon(prev_nonce + 1, Secret)
    nullifier_key: pub Field,
    prev_shadow_balance_root: pub Field,
    incoming_balance_root: pub Field,
    // we need this in the proof otherwise someone can steal it an change the account
    // TODO: should strip this down to 20 bytes to be ethereum compatible
    recipient_account: pub Field,
    // ----- very privacy sensitive data -----
    // information that could be used to id sender
    // hashes needed to re-construct the merkle root for both trees
    // if this was public somone would be able to link youre previous txns together
    prev_shadow_balance_merkle_proof: [Field; 31],
    incoming_balance_merkle_proof: [Field; 31],
    // private key
    secret: Field,
    // poseidon(Secret)
    // only difference between private and public transfer circuits is that this is private or public, respectively
    sender_account: Field,
    // incoming balance
    incoming_balance: Field,
    // num txns
    prev_nonce: Field,
    // total amount privately sent
    prev_shadow_balance: Field,
    // position of the account from the array that holds the merkle roots
    // just for merkle proof
    prev_shadow_balance_index: Field,
    incoming_balance_index: Field,
) {
    // logic for both public and private transfer is the same, the only difference in the functions is the visibility of the
    // `sender_account`, which is private in privateTransfer and public in publicTransfer
    transfer(
        transfer_amount,
        nullifier_value,
        nullifier_key,
        prev_shadow_balance_root,
        incoming_balance_root,
        prev_shadow_balance_merkle_proof,
        incoming_balance_merkle_proof,
        sender_account,
        secret,
        incoming_balance,
        prev_nonce,
        prev_shadow_balance,
        prev_shadow_balance_index,
        incoming_balance_index,
    )
}
