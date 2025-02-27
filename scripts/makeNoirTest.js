import { ethers } from "ethers";
/**
 * @typedef  {{
 *        transfer_amount: ethers.BytesLike,
 *        nullifier_value: ethers.BytesLike,
 *        nullifier_key: ethers.BytesLike,
 *        prev_shadow_balance_root: ethers.BytesLike,
 *        incoming_balance_root: ethers.BytesLike,
 *        recipient_account: ethers.AddressLike,
 *        prev_shadow_balance_merkle_proof: ethers.BytesLike[],
 *        incoming_balance_merkle_proof: ethers.BytesLike[],
 *        secret: ethers.BytesLike,
 *        sender_account: ethers.AddressLike,
 *        incoming_balance: ethers.BytesLike,
 *        prev_nonce: ethers.BytesLike,
 *        prev_shadow_balance: ethers.BytesLike,
 *        prev_shadow_balance_index: ethers.BytesLike,
 *        incoming_balance_index: ethers.BytesLike,
 * }} noirJsInputs
 * @param {noirJsInputs} param0 
 */
export function makeNoirTest({noirJsInputs}) {
    return `
#[test]
fn test_main() {
    let sender_account =                    ${noirJsInputs.sender_account};
    let secret =                            ${noirJsInputs.secret};
    let transfer_amount =                   ${noirJsInputs.transfer_amount};
    let nullifier_value =                   ${noirJsInputs.nullifier_value};
    let nullifier_key =                     ${noirJsInputs.nullifier_key};
    let prev_shadow_balance_root =          ${noirJsInputs.prev_shadow_balance_root};
    let incoming_balance_root =             ${noirJsInputs.incoming_balance_root};
    let prev_shadow_balance_merkle_proof =  [${noirJsInputs.prev_shadow_balance_merkle_proof}];
    let incoming_balance_merkle_proof =     [${noirJsInputs.incoming_balance_merkle_proof}];
    let incoming_balance =                  ${noirJsInputs.incoming_balance};
    let prev_nonce =                        ${noirJsInputs.prev_nonce};
    let prev_shadow_balance =               ${noirJsInputs.prev_shadow_balance};
    let prev_shadow_balance_index =         ${noirJsInputs.prev_shadow_balance_index};
    let incoming_balance_index =            ${noirJsInputs.incoming_balance_index};
    let recipient_account =                 ${noirJsInputs.recipient_account};

    main(
        transfer_amount,
        nullifier_value,
        nullifier_key,
        prev_shadow_balance_root,
        incoming_balance_root,
        recipient_account,
        prev_shadow_balance_merkle_proof,
        incoming_balance_merkle_proof,
        secret,
        sender_account,
        incoming_balance,
        prev_nonce,
        prev_shadow_balance,
        prev_shadow_balance_index,
        incoming_balance_index,
    )
}`
}