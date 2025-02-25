/*
use dep::ScrollStorageProver::{hash_node_key_from_mapping, leaf_to_storage_root, get_state_root};
use dep::ScrollStorageProver::{Hash_path_proof, Hash_paths_state_proof, Account_preimage_excl_storage};
use dep::std::field::bytes32_to_field;
use dep::std::hash::poseidon;
use dep::std::hash::keccak256;
*/
use dep::merkle::compute_merkle_root;

// 54 is the highest value that still run in noirjs wasm
// might be enough since it can support scroll up to 18014398 billion account and for the contract to have 18014398 billion different slots
// splitting the proof up into account, storage proof seperately could increase the depth to 108 which would be 324518553000000000000 billion slots

// MAX_HASH_PATH_SIZE can be up to 32 to be proven in the browser. 248 to cover the full tree
// the account tree depth of sepolia is 23
/*
global MAX_HASH_PATH_SIZE: u32 = 32; //248;//32; //this is the max tree depth in scroll: https://docs.scroll.io/en/technology/sequencer/zktrie/#tree-construction
global MAX_RLP_SIZE: u32 = 650; //1000; //should be enough scroll mainnet wasn't going above 621, my guess is 673 bytes max + rlp over head. idk what overhead is tho.
// TODO actually find out what the largest value could be 

global PADDED_CONTRACT_ADDRESS: [u8;32] = [33,208,131,41,94,37,81,229,129,92,47,11,76,183,61,226,83,145,6,183,0,0,0,0,0,0,0,0,0,0,0,0];// 0x21d083295e2551e5815c2f0b4cb73de2539106b7000000000000000000000000
global BALANCES_SLOT:[u8;32]  = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
global PARTIAL_NULLIFIERS_SLOT:[u8;32]  = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6];
global COMPRESSED_KECCAK_CODE_HASH: Field = 0x0e8e0b42b49cc167cf5bd04ee737d0b1e1312e5cc11f8817612271f464fc2924;
global POSEIDON_CODE_HASH: Field = 0x0e630c824b73bb5c6321b6342d9f22ae2deeb567cd23d85a80ff0dbeff4ec533;

struct Contract_proof_data<let R:u32> {
    balance: Field,
    nonce_codesize_0: Field,
    header_rlp: [u8;R],
    header_rlp_len: u32,
}
*/

fn get_burn_address(secret: Field) -> [u8; 32] {
    let hash:[u8; 32] = poseidon::bn254::hash_1([secret]).to_be_bytes(); //.as_array();
    let mut burn_address:[u8;32] = [0; 32];

    // replace last 12 bytes with zero since address is only 20 bytes (noir doesnt support a nicer method hence whacky for loop)
    for index in 0..20 {
        burn_address[index+12] = hash[index];
    }
    burn_address
}

// 

// remove everything with storage proof and change to merkle proof
// private spend tree leaf hashing pos_hash
// pub accont tree leaf

// exection flow
// have 2 circuits, private and public transfer
// both mains take the root nodes of both pub and private account trees
// also take the leaf of the user
// rebuild account tree using user's leaf
// require(rebuilt_root == passed in root)
// thats it

// nonce makes sure the hash is never the same even when the amount is different
// secret is so others cant try and find the pre-image (since this hash is posted onchain)
fn hash_nullifier_value(amount: Field, nonce: Field, secret: Field) -> Field {
    poseidon::bn254::hash_3([amount, nonce, secret])
}

// nonce makes sure the hash is never the same even when the amount is different
// secret is so others cant try and find the pre-image (since this hash is posted onchain)
fn hash_nullifier_key(nonce: Field, secret: Field) -> Field {
    poseidon::bn254::hash_2([nonce, secret])
}

fn lower_then_or_equal(a: Field, b: Field) -> bool {
    !std::field::bn254::gt(a, b)
}
/*
//TODO remane nullifierId -> nullifierKey and nullifier -> nullifierValue
fn main(
    //----- public inputs
    remint_address: pub Field,// the address to re-mint to (only used to assert it's not 0x0)
    withdraw_amount: pub Field,
    nullifier_value: pub Field,
    nullifier_key: pub Field,
    storage_root: pub Field,
    //-----very privacy sensitive data -----
    secret: Field,//burnaddress is der ived from secret // TODO instead of using a secrets use public cryptography shit so hardware wallets dont have to create a whole ass proof. Also makes complexity lower for hot wallets to ensure safety and better compatability with metamasksnap.
    burned_balance: [u8; 32], //TODO split into fields constraint golf or just as a field (also gas golf) (assumes a balance never > FIELD_LIMIT)
    nonce: Field, // nonce to create a nulliefier from to track encrypted spend_amounts
    prev_nullifier_key: Field, // just here for the storage proof of prev_nullifier, since prev_nullifier already contains all info
    prev_spend_amount: Field,
    burn_addr_storage_proof: Hash_path_proof<MAX_HASH_PATH_SIZE>,
    prev_nullifier_storage_proof: Hash_path_proof<MAX_HASH_PATH_SIZE>,
) {
    // to prevent the proof being stolen from the mempool and used for a differen withdraw address
    // TODO check if you realy need to do this? Tornadocash something similair tho.
    assert(remint_address != 0x0);

    //------------ storage proof of mapping(burn_address -> burned_balance) ------------
    // burn_address = our secret commitment
    let burn_address:[u8;32] = get_burn_address(secret);

    // storage proof
    let storage_node_key_burn_addr: Field = hash_node_key_from_mapping(
        burn_address, 
        BALANCES_SLOT
    );
    let storage_root_burn_addr = leaf_to_storage_root(
        storage_node_key_burn_addr, 
        burned_balance, 
        burn_addr_storage_proof
    );
    assert(storage_root_burn_addr == storage_root, "given storage_root doesnt match computed storage_root from the burn_address storage proof");

    //--------prev nullifier------------
    if (nonce != 0) {
        // verify that the nullifier exist onchain with a storage proof
        // cant do this outside the circuit since that links prev_nullifier_key with the nullifier_key
        let prev_nullifier_value: [u8;32] = hash_nullifier_value(prev_spend_amount, nonce - 1, secret).to_be_bytes();

        // storage proof
        let storage_node_key_prev_nullifier: Field = hash_node_key_from_mapping(
            prev_nullifier_key.to_be_bytes(), 
            PARTIAL_NULLIFIERS_SLOT
        );
        let storage_root_prev_nullifier_key = leaf_to_storage_root(
            storage_node_key_prev_nullifier, 
            prev_nullifier_value, 
            prev_nullifier_storage_proof
        );

        assert(storage_root_prev_nullifier_key == storage_root, "given storage_root doesnt match computed storage_root from the prev_nullifier storage proof");

    } else {
        // we dont need to check prev_nullifier_key since it doenst exist and we can keep prev_spend_amount at 0
        // TODO make the nullifier proof a recursive proof so the first tx is ~2x faster to proof
    }

    // ----- Current Nullifier-------------
    // @WARNING TODO watch out for overflows (solution?: make sure max supply of coin is < FIELD_LIMIT inside contract)
    let new_spend_amount: Field = withdraw_amount + prev_spend_amount;
    //new_spend_amount < burned_balance
    // TODO this burns 1 wei because i cant do <=
    // should i just do new_spend_amount == new_spend_amount || secret < new_spend_amount
    assert(lower_then_or_equal(new_spend_amount, bytes32_to_field(burned_balance)), "withdraw_amount too large, new_spend_amount is larger than burned_balance");
    let computed_nullifier_value: Field = hash_nullifier_value(new_spend_amount, nonce, secret);
    assert(
        computed_nullifier_value == nullifier_value, "public input: nullifier_value, doesnt match the one computed in the circuit"
    );

    // ----- nullifier_key -------------
    let computed_nullifier_key = hash_nullifier_key(nonce, secret);
    assert(computed_nullifier_key == nullifier_key, "computed nullifier doesnt match provided nullifier");
}
*/

fn new_main<let N: u32>(
    // ----- public inputs -----
    transfer_amount: pub Field,
    // Poseidon(prev_shadow_bal + transfer_amt, prev_nonce + 1, Secret)
    nullifier_value: pub Field,
    // Poseidon(prev_nonce + 1, Secret)
    nullifier_key: pub Field,
    shadow_balance_root: pub Field,
    public_balance_root: pub Field,
    // we need this in the proof otherwise someone can steal it an change the account
    // TODO: should strip this down to 20 bytes to be ethereum compatible
    recipient_account: pub Field,

    // ----- very privacy sensitive data -----
    // information that could be used to id sender
    // hashes needed to re-construct the merkle root for both trees

    // if this was public somone would be able to link youre previous txns together
    prev_shadow_balance_merkle_proof: [Field; N],
    prev_public_balance_merkle_proof: [Field; N],
    // poseidon(Secret)
    sender_account: Field,
    // private key
    secret: Field,
    // public balance
    public_balance: Field,
    // num txns
    prev_nonce: Field,
    // total amount privately sent
    prev_shadow_balance: Field,
    // position of the account from the array that holds the merkle roots
    // just for merkle proof
    shadow_balance_index: Field,
    public_balance_index: Field,
) {

    // verify nullifier value
    let computed_nullifier_value = poseidon::bn254::hash_3([prev_shadow_balance + transfer_amount, prev_nonce + 1, secret]);
    assert(computed_nullifier_value == nullifier_value, "nullifier value computed in circuit doesn't match nullifier value passed in as parameter");

    // verify nullifier key
    let computed_nullifier_key = poseidon::bn254::hash_2([prev_nonce + 1, secret]);
    assert(computed_nullifier_key == nullifier_key, "nullifier key computed in circuit doesn't match nullifier key passed in as parameter");

    // verify shadow balance tree root
    let shadow_balance_leaf = poseidon::bn254::hash2([nullifier_key, nullifier_value]);
    let computed_shadow_balance_root = compute_merkle_root(shadow_balance_leaf, shadow_balance_index, shadow_balance_merkle_proof);
    assert(computed_shadow_balance_root == shadow_balance_root, "computed shadow balance tree root doesn't match shadow balance tree root passed in as parameter")

    // verify public balance tree root
    let public_balance_leaf = poseidon::bn254::hash2(account, public_balance);
    let computed_public_balance_root = compute_merkle_root(public_balance_leaf, public_balance_index, public_balance_merkle_proof);
    assert(computed_public_balance_root == public_balance_root, "computed public balance tree root doesn't match shadow balance tree root passed in as parameter")

    // make sure user has enough funds to send
    let new_shadow_balance = prev_shadow_balance + transfer_amount;
    let spendable_balance = public_balance - new_shadow_balance;
    assert(lower_then_or_equal(transfer_amount, spendable_balance), "not enough funds to transfer");

}

#[test]
fn test_hashing() {
    let nonce = 0;
    let secret = 123;
    let address = get_burn_address(secret);
    let nullifier = hash_nullifier_key(nonce, secret);
    println(address);
    println(nullifier);
}

#[test]
fn test_get_state_root() {
    let header_rlp:[u8;607] = [
        249, 2, 92, 160, 239, 37, 169, 176, 180, 227, 63, 164, 8, 23, 74, 123, 2, 50, 96, 72, 192, 223, 169, 179, 175, 31, 225, 216, 123, 74, 73, 232, 114, 130, 59, 90, 160, 29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 160, 22, 96, 101, 252, 118, 165, 64, 236, 30, 201, 68, 228, 168, 228, 9, 200, 217, 97, 91, 119, 98, 21, 4, 239, 255, 21, 78, 1, 50, 248, 232, 248, 160, 136, 102, 42, 69, 64, 99, 89, 76, 135, 191, 116, 65, 216, 161, 127, 113, 49, 212, 190, 59, 37, 30, 139, 65, 60, 85, 44, 161, 45, 226, 246, 216, 160, 158, 25, 2, 237, 43, 125, 57, 186, 32, 212, 200, 246, 195, 128, 119, 200, 198, 67, 196, 165, 185, 217, 54, 244, 106, 106, 21, 249, 173, 46, 18, 143, 185, 1, 0, 0, 2, 16, 0, 4, 0, 0, 64, 0, 0, 32, 0, 0, 128, 64, 32, 0, 4, 0, 0, 34, 0, 32, 16, 8, 16, 18, 0, 0, 80, 1, 1, 5, 16, 0, 0, 32, 2, 8, 0, 16, 0, 128, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 32, 2, 4, 0, 0, 0, 4, 0, 32, 0, 0, 0, 0, 128, 0, 4, 112, 32, 0, 2, 0, 0, 8, 0, 0, 0, 0, 0, 0, 8, 16, 0, 0, 0, 0, 160, 1, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 66, 16, 0, 16, 0, 0, 4, 0, 0, 0, 8, 8, 0, 0, 0, 64, 32, 16, 64, 0, 0, 0, 0, 16, 0, 0, 2, 0, 0, 1, 4, 0, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 8, 129, 128, 0, 0, 0, 0, 7, 65, 2, 64, 130, 0, 0, 1, 32, 0, 64, 0, 16, 0, 0, 0, 0, 0, 32, 0, 2, 0, 32, 64, 0, 16, 0, 0, 0, 0, 0, 0, 0, 32, 32, 0, 0, 34, 0, 0, 0, 32, 0, 0, 128, 2, 1, 0, 64, 0, 0, 20, 0, 0, 32, 0, 0, 8, 0, 0, 0, 16, 0, 0, 32, 0, 128, 16, 0, 132, 0, 0, 0, 2, 0, 0, 4, 0, 0, 2, 4, 0, 0, 0, 0, 32, 17, 0, 128, 0, 0, 0, 32, 0, 12, 0, 0, 0, 2, 131, 98, 190, 31, 131, 152, 150, 128, 131, 14, 199, 206, 132, 102, 104, 97, 14, 184, 97, 216, 131, 5, 3, 32, 132, 103, 101, 116, 104, 136, 103, 111, 49, 46, 50, 48, 46, 49, 133, 108, 105, 110, 117, 120, 0, 0, 0, 0, 0, 0, 0, 98, 35, 151, 26, 49, 19, 62, 111, 213, 69, 22, 123, 70, 156, 179, 46, 68, 8, 66, 169, 246, 237, 189, 150, 167, 155, 212, 142, 202, 153, 105, 118, 50, 142, 15, 6, 182, 252, 51, 82, 55, 245, 167, 10, 219, 154, 87, 83, 247, 147, 198, 131, 202, 118, 201, 93, 24, 196, 4, 87, 170, 156, 181, 215, 1, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 0, 0, 0, 0, 0, 0, 0, 0
    ];

    let state_root:Field = 0x166065fc76a540ec1ec944e4a8e409c8d9615b77621504efff154e0132f8e8f8;

    let state_root_rlp = get_state_root(header_rlp);
    assert(
        bytes32_to_field(state_root_rlp) == state_root, "state root doesnt match. Did the header layout change?"
    );
}

#[test]
fn test_main() {
    //----- public inputs
    let remint_address: Field = 0x93211e420c8F552a0e4836f84892a0D4eb5D6D54;
    let withdraw_amount:  Field = 0x8ac7230489e80000;
    let nullifier: Field = 0x212456bab521c4afa65cca2751d74f7cbac9ba747d7bc3c21be994b886a7bfe1;
    let nullifier_key: Field = 0x0a2fdf0860adb5ea719794ecf7ec81cc57e56f1846e1508a7fa6448d36cd9624;
    //let block_hash: [u8; 32] = [0x40,0x60,0xee,0xf3,0xb5,0xa5,0xf2,0x87,0x02,0x74,0xb0,0x30,0xe8,0xd8,0x3c,0x69,0xd2,0xf2,0x13,0xfe,0x4d,0x1b,0xd8,0x41,0xea,0x9b,0xe2,0x90,0x7f,0x79,0xc9,0x5d];
    let storage_root: Field = 0x1acea27e9cfb8fd7576d57d039f4c77e0d8edeb1d056bcc5213b7a65842cd900;
    
    //-----private inputs -----
    let secret: Field  = 0x1cf2c2021c2e15a1c61547a32a6295078aacf089edb3cc66fd992f627f30f824;
    let burned_balance: [u8; 32]  = [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x16,0xc4,0xab,0xbe,0xbe,0xa0,0x10,0x00,0x00];
    let nonce: Field = 3;
    let prev_nullifier_key: Field = 0x1546f8d229c5a0943586cd5261ab4adbf995e849976a689a6055a32d4fae8337;
    let prev_spend_amount: Field = 30000000000000000000;

    let burn_addr_storage_proof =  Hash_path_proof {
            hash_path:  [0x271dcf322b72eadde439e5f2fe303af0d6ab3fa6c79a9466704a4791f85af7b3,0x0000000000000000000000000000000000000000000000000000000000000000,0x2bff2dd5919b91b80722debba0da0ba15eb2ac950ba965c07cde492494242177,0x29e2f4c47f71ee542e6ab5571f0eda8230b57f3166178244ea0603655ec82ddb,0x037babdabb3dd50298f663dcfb1124a68a0f2b80dcd4a949f797a188e6c93964,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            node_types: [7,8,9,9,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            leaf_type:  0x04,
            real_hash_path_len: 5,
            hash_path_bools:  [false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false],
    };
    let prev_nullifier_storage_proof = Hash_path_proof {
            hash_path:  [0x0b740b3b3c51a59c48c9eb1463d725ce7cac0bc306988485c1faab915d162544,0x1994aab20b7fed2fe15b917c4582250c146700553fefaf41449237bc67053b13,0x1792184d393ac7d787217a5704feca25054d79efa6d99dc0dac728234f2f5f7f,0x0e8a61ecf3189248e1aaa0c3fa333cc207b3b871c3b83621040e845bcc8fa7f3,0x1221df3235836747f28777f8eb3c78979ad8f4cb70c1d4bc63142116258d60b8,0x22766d6b32b905252b05efb58814689ccc270cf5b526e9779ec552a279ff8cd5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            node_types: [6,9,7,9,9,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            leaf_type:  0x04,
            real_hash_path_len: 6,
            hash_path_bools:  [false,false,true,false,true,true,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false],
    };

    main(
        //----- public inputs
        remint_address,
        withdraw_amount,
        nullifier,
        nullifier_key,
        storage_root,
        //-----private inputs -----
        secret,
        burned_balance,
        nonce,
        prev_nullifier_key,
        prev_spend_amount,
        burn_addr_storage_proof,
        prev_nullifier_storage_proof,
    );
}


 