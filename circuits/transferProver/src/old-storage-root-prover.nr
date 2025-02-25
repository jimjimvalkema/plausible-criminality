use dep::ScrollStorageProver::{
    Account_preimage_excl_storage, hash_node_key_account, Hash_path_proof, leaf_to_state_root,
    set_state_root,
};
use dep::std::hash::keccak256;

global MAX_HASH_PATH_SIZE: u32 = 64; //248;//32; //this is the max tree depth in scroll: https://docs.scroll.io/en/technology/sequencer/zktrie/#tree-construction
global MAX_RLP_SIZE: u32 = 850;

// proofs that a state_root from a specified contract is part the block with that blockhash
fn main(
    storage_root: pub Field,
    block_hash: pub [u8; 32],
    padded_contract: pub [u8; 32], // it is possible to make this a Field but you would need to supply it in reverse because the zeros are padded at the end which causes it to go over the Field limit
    account_preimage: Account_preimage_excl_storage,
    account_proof: Hash_path_proof<MAX_HASH_PATH_SIZE>,
    header_rlp: [u8; MAX_RLP_SIZE],
    header_rlp_len: u32,
) {
    // merkle proof from account to the state_root
    // to proof that our storage_root from that contract is part of the ethereum state
    let account_node_key: Field = hash_node_key_account(padded_contract);
    let state_root: Field = leaf_to_state_root(
        account_node_key,
        account_preimage,
        storage_root,
        account_proof,
    );

    // proof that state_root is inside the blockhash
    let new_header_rlp: [u8; MAX_RLP_SIZE] = set_state_root(header_rlp, state_root.to_be_bytes());
    let computed_block_hash: [u8; 32] = keccak256(new_header_rlp, header_rlp_len);

    // check
    assert(
        block_hash == computed_block_hash,
        "block hash from proof doesnt match the block hash provided",
    );
}

#[test]
fn test_main() {
    let storage_root: Field = 0x1acea27e9cfb8fd7576d57d039f4c77e0d8edeb1d056bcc5213b7a65842cd900;
    let block_hash: [u8; 32] = [
        0x40, 0x60, 0xee, 0xf3, 0xb5, 0xa5, 0xf2, 0x87, 0x02, 0x74, 0xb0, 0x30, 0xe8, 0xd8, 0x3c,
        0x69, 0xd2, 0xf2, 0x13, 0xfe, 0x4d, 0x1b, 0xd8, 0x41, 0xea, 0x9b, 0xe2, 0x90, 0x7f, 0x79,
        0xc9, 0x5d,
    ];
    let padded_contract: [u8; 32] = [
        33, 208, 131, 41, 94, 37, 81, 229, 129, 92, 47, 11, 76, 183, 61, 226, 83, 145, 6, 183, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
    let account_preimage = Account_preimage_excl_storage {
        // = the whole account leaf preimage except storage hash since we need to compute it later here
        compressed_keccak_code_hash: 0x0e8e0b42b49cc167cf5bd04ee737d0b1e1312e5cc11f8817612271f464fc2924, // cannot be change afaik unless maybe self destruct but that is silly
        poseidon_code_hash: 0x0e630c824b73bb5c6321b6342d9f22ae2deeb567cd23d85a80ff0dbeff4ec533,
        nonce_codesize_0: 0x0000000000000000000000000000000000000000000010140000000000000001, // only changes if the contract creates another contract: https://ethereum.org/en/developers/docs/accounts/#an-account-examined
        balance: 0x00, // always changes
    };
    let account_proof = Hash_path_proof {
        hash_path: [
            0x0b2247fce447f1671dd6d174be45b074fd89a6330b08ab2c87496dee6f03115e,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x2614c322fa1f971ce06d0c8fc2ab71bd13aac9e3a1bed9a69079a751275090e6,
            0x0103d17039f4bfb2134f878fddb08dc0f9919cc8177f195e2c21fd036d70e4d8,
            0x0bd0af6c5f4ac2609f47db7358b32af8707d9b1f1ea8816c43aaf088420c2a82,
            0x1876a6e0855526abd8bcbf767b7a467eadd99f56e18e89cc8f18e8d523621e65,
            0x17837b58b18c4fe6f293bb55920a56bf1733a70feed305e4ee807739d594d3b7,
            0x1e89d0ca62cf848177514f72239d630fc57864865dc889f656595d0dedcfe03c,
            0x24f5e254afbd2370fe36aab6d1a03f93c48f29a9cc60f56275a4a530f64f898f,
            0x245536539214afb67ba8c93f6f8bb5052b4d6c83468cfec754d137ae1cc7cec2,
            0x27ebaf0af037f48257d57cbfba74c0a006558633204390caacf3db1d5c65b07e,
            0x28f5020177be2ed30dddd260de462f2579c2d4bb122155124101bb8acf219a94,
            0x16a327dc5939dfd27bd90050baf91ee38546f140503161a0a754024837e09bb3,
            0x2d9d973280548b9501fbc42e50d14c6c09ed30087dbed6583edc5f72f9c9e3b3,
            0x1e38ae00c9d40824a4c6ea5c837a892ae1370c1ddb0b2f69f2334d67bdb4b1df,
            0x10fb06ec6d590d63efd1df5fee4e45e895c6c1e7d7c919522da0ed385139563f,
            0x1301413522e53da157c1757272fa2f1541b42d74eb6c010233b5f0e87ec40ed0,
            0x094cb1ae53b96f40b137c2dc5b659d6de3aae90e8f897882528dc509fef9acdf,
            0x2634dfe5f14fee94cd389e331c5a4492f50806970c524b2e56279de1bed5d93f,
            0x05d288c9cd54ee7b9cb7e1f1ae7e1ba224bc84462f6896af1672611c1a312014,
            0x1cdea36b73ebeb92696b6d7742cf491a3c80eb928170b995c3b36c82038535fb,
            0x16b46259455ce43f114a34d3b2e443994e4930aa944372351536d0c4f49c3ec1,
            0x14ccc4fe67292c6bf607664f80b0d4963e3ec3499178d736e2bad1b0626c6bee,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
        ],
        node_types: [
            6, 7, 8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0,
        ],
        leaf_type: 0x04,
        real_hash_path_len: 23,
        hash_path_bools: [
            false, true, false, false, true, true, true, false, true, true, true, false, false,
            true, false, false, true, false, false, true, false, false, true, false, false, false,
            false, false, false, false, false, false, false, false, false, false, false, false,
            false, false, false, false, false, false, false, false, false, false, false, false,
            false, false, false, false, false, false, false, false, false, false, false, false,
            false, false,
        ],
    };
    let header_rlp: [u8; MAX_RLP_SIZE] = [
        249, 2, 96, 160, 163, 70, 1, 115, 111, 44, 209, 25, 220, 10, 0, 137, 30, 102, 152, 63, 255,
        188, 83, 2, 219, 56, 72, 25, 8, 55, 82, 16, 185, 69, 41, 21, 160, 29, 204, 77, 232, 222,
        199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116, 19,
        240, 161, 66, 253, 64, 212, 147, 71, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 160, 9, 38, 193, 3, 56, 5, 151, 175, 35, 243, 38, 34, 84, 243, 253, 248, 51, 18,
        239, 166, 202, 92, 186, 98, 171, 153, 41, 75, 31, 0, 235, 193, 160, 253, 148, 252, 193, 46,
        3, 213, 157, 166, 1, 195, 2, 41, 39, 38, 214, 181, 92, 15, 240, 204, 195, 21, 108, 137, 70,
        70, 41, 186, 149, 234, 242, 160, 17, 55, 158, 130, 75, 112, 246, 28, 120, 22, 41, 103, 240,
        203, 75, 132, 245, 246, 232, 132, 198, 126, 87, 214, 235, 253, 247, 181, 243, 214, 156, 89,
        185, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 0,
        0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 131, 121, 116, 229, 131, 152, 150, 128,
        130, 150, 126, 132, 103, 144, 254, 187, 184, 97, 216, 131, 5, 8, 0, 132, 103, 101, 116, 104,
        136, 103, 111, 49, 46, 50, 49, 46, 49, 133, 108, 105, 110, 117, 120, 0, 0, 0, 0, 0, 0, 0,
        156, 57, 27, 94, 45, 143, 46, 3, 10, 133, 208, 207, 150, 42, 11, 237, 119, 3, 194, 218, 11,
        192, 27, 44, 62, 136, 106, 253, 36, 120, 128, 184, 28, 160, 172, 40, 196, 253, 196, 95, 191,
        8, 169, 91, 24, 173, 174, 54, 24, 225, 40, 65, 240, 89, 254, 76, 19, 165, 166, 58, 232, 138,
        40, 4, 1, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 136, 0, 0, 0, 0, 0, 0, 0, 0, 132, 2, 138, 204, 21, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
    let header_rlp_len: u32 = 611;

    main(
        storage_root,
        block_hash,
        padded_contract,
        account_preimage,
        account_proof,
        header_rlp,
        header_rlp_len,
    );
}

