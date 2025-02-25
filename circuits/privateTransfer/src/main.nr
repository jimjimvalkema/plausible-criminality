use dep::merkle::compute_merkle_root;
use dep::std::hash::poseidon;

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

fn lower_then_or_equal(a: Field, b: Field) -> bool {
    !std::field::bn254::gt(a, b)
}

// TODO: change from public to incoming
fn main(
    // ----- public inputs -----
    transfer_amount: pub Field,
    // Poseidon(prev_shadow_bal + transfer_amt, prev_nonce + 1, Secret)
    nullifier_value: pub Field,
    // Poseidon(prev_nonce + 1, Secret)
    nullifier_key: pub Field,
    prev_shadow_balance_root: pub Field,
    public_balance_root: pub Field,
    // we need this in the proof otherwise someone can steal it an change the account
    // TODO: should strip this down to 20 bytes to be ethereum compatible
    recipient_account: pub Field,
    // ----- very privacy sensitive data -----
    // information that could be used to id sender
    // hashes needed to re-construct the merkle root for both trees
    // if this was public somone would be able to link youre previous txns together
    prev_shadow_balance_merkle_proof: [Field; 32],
    public_balance_merkle_proof: [Field; 32],
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
    prev_shadow_balance_index: Field,
    public_balance_index: Field,
) {
    // verify new nullifier key
    let computed_nullifier_key = poseidon::bn254::hash_2([prev_nonce + 1, secret]);
    assert(
        computed_nullifier_key == nullifier_key,
        "nullifier key computed in circuit doesn't match nullifier key passed in as parameter",
    );

    println(prev_shadow_balance);
    println(transfer_amount);
    println(secret);
    // verify new nullifier value
    let computed_nullifier_value = poseidon::bn254::hash_3([
        prev_shadow_balance + transfer_amount,
        prev_nonce + 1,
        secret,
    ]);
    println(computed_nullifier_value);
    println(nullifier_value);
    assert(
        computed_nullifier_value == nullifier_value,
        "nullifier value computed in circuit doesn't match nullifier value passed in as parameter",
    );

    // compute previous nullifier key & value
    let prev_nullifier_key = poseidon::bn254::hash_2([prev_nonce, secret]);
    let prev_nullifier_value = poseidon::bn254::hash_3([prev_shadow_balance, prev_nonce, secret]);

    // verify previous shadow balance tree root
    let prev_shadow_balance_leaf =
        poseidon::bn254::hash_2([prev_nullifier_key, prev_nullifier_value]);
    let computed_prev_shadow_balance_root = compute_merkle_root(
        prev_shadow_balance_leaf,
        prev_shadow_balance_index,
        prev_shadow_balance_merkle_proof,
    );
    assert(
        computed_prev_shadow_balance_root == prev_shadow_balance_root,
        "computed shadow balance tree root doesn't match shadow balance tree root passed in as parameter",
    );

    // verify public balance tree root
    let public_balance_leaf = poseidon::bn254::hash_2([sender_account, public_balance]);
    let computed_public_balance_root = compute_merkle_root(
        public_balance_leaf,
        public_balance_index,
        public_balance_merkle_proof,
    );
    assert(
        computed_public_balance_root == public_balance_root,
        "computed public balance tree root doesn't match shadow balance tree root passed in as parameter",
    );

    // make sure user has enough funds to send
    let new_shadow_balance = prev_shadow_balance + transfer_amount;
    let spendable_balance = public_balance - new_shadow_balance;
    assert(lower_then_or_equal(transfer_amount, spendable_balance), "not enough funds to transfer");
}

#[test]
fn test_main_simple_merkle() {
    /* Scenario: account A privately sends 5 tokens

    before:
        account A:
            public_bal: 10 private_bal: 0
            nonce: 0
    after:
        account A:
            public_bal: 10
            private_bal: 5
            nonce: 1
    */

    // ----- private inputs -----

    let sender_account = 0x000000000000000000000000000000000000000000000000476f207465616d21;
    let secret = 0x01;

    // ----- public inputs -----
    let transfer_amount = 0x0000000000000000000000000000000000000000000000000000000000000005;
    let nullifier_value = 0x181aa2c05a6aeee42fbca413814be97aa8fd7bfea28054608f637ce56db49eeb;
    let nullifier_key = 0x007af346e2d304279e79e0a9f3023f771294a78acb70e73f90afe27cad401e81;
    let prev_shadow_balance_root =
        0x0da0074206e594435cf1e040dae0c583f637558e4e3b57576ded0777f8004dd1;
    let recipient_account = 0x123;
    let public_balance_root = 0x251c7a2942c4a5fb6f9270ea927fb76a57f6924283076d70804550db0b46cafe;
    let prev_shadow_balance_merkle_proof = [
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x20a3af0435914ccd84b806164531b0cd36e37d4efb93efab76913a93e1f30996,
        0x217126fa352c326896e8c2803eec8fd63ad50cf65edfef27a41a9e32dc622765,
        0x0e28a61a9b3e91007d5a9e3ada18e1b24d6d230c618388ee5df34cacd7397eee,
        0x27953447a6979839536badc5425ed15fadb0e292e9bc36f92f0aa5cfa5013587,
        0x194191edbfb91d10f6a7afd315f33095410c7801c47175c2df6dc2cce0e3affc,
        0x1733dece17d71190516dbaf1927936fa643dc7079fc0cc731de9d6845a47741f,
        0x267855a7dc75db39d81d17f95d0a7aa572bf5ae19f4db0e84221d2b2ef999219,
        0x1184e11836b4c36ad8238a340ecc0985eeba665327e33e9b0e3641027c27620d,
        0x0702ab83a135d7f55350ab1bfaa90babd8fc1d2b3e6a7215381a7b2213d6c5ce,
        0x2eecc0de814cfd8c57ce882babb2e30d1da56621aef7a47f3291cffeaec26ad7,
        0x280bc02145c155d5833585b6c7b08501055157dd30ce005319621dc462d33b47,
        0x045132221d1fa0a7f4aed8acd2cbec1e2189b7732ccb2ec272b9c60f0d5afc5b,
        0x27f427ccbf58a44b1270abbe4eda6ba53bd6ac4d88cf1e00a13c4371ce71d366,
        0x1617eaae5064f26e8f8a6493ae92bfded7fde71b65df1ca6d5dcec0df70b2cef,
        0x20c6b400d0ea1b15435703c31c31ee63ad7ba5c8da66cec2796feacea575abca,
        0x09589ddb438723f53a8e57bdada7c5f8ed67e8fece3889a73618732965645eec,
        0x0064b6a738a5ff537db7b220f3394f0ecbd35bfd355c5425dc1166bf3236079b,
        0x095de56281b1d5055e897c3574ff790d5ee81dbc5df784ad2d67795e557c9e9f,
        0x11cf2e2887aa21963a6ec14289183efe4d4c60f14ecd3d6fe0beebdf855a9b63,
        0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb,
        0x16fdb637c2abf9c0f988dbf2fd64258c46fb6a273d537b2cf1603ea460b13279,
        0x21bbd7e944f6124dad4c376df9cc12e7ca66e47dff703ff7cedb1a454edcf0ff,
        0x2784f8220b1c963e468f590f137baaa1625b3b92a27ad9b6e84eb0d3454d9962,
        0x16ace1a65b7534142f8cc1aad810b3d6a7a74ca905d9c275cb98ba57e509fc10,
        0x2328068c6a8c24265124debd8fe10d3f29f0665ea725a65e3638f6192a96a013,
        0x2ddb991be1f028022411b4c4d2c22043e5e751c120736f00adf54acab1c9ac14,
        0x0113798410eaeb95056a464f70521eb58377c0155f2fe518a5594d38cc209cc0,
        0x202d1ae61526f0d0d01ef80fb5d4055a7af45721024c2c24cffd6a3798f54d50,
        0x23ab323453748129f2765f79615022f5bebd6f4096a796300aab049a60b0f187,
        0x1f15585f8947e378bcf8bd918716799da909acdb944c57150b1eb4565fda8aa0,
        0x1eb064b21055ac6a350cf41eb30e4ce2cb19680217df3a243617c2838185ad06,
    ];
    let public_balance_merkle_proof = [
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x20a3af0435914ccd84b806164531b0cd36e37d4efb93efab76913a93e1f30996,
        0x217126fa352c326896e8c2803eec8fd63ad50cf65edfef27a41a9e32dc622765,
        0x0e28a61a9b3e91007d5a9e3ada18e1b24d6d230c618388ee5df34cacd7397eee,
        0x27953447a6979839536badc5425ed15fadb0e292e9bc36f92f0aa5cfa5013587,
        0x194191edbfb91d10f6a7afd315f33095410c7801c47175c2df6dc2cce0e3affc,
        0x1733dece17d71190516dbaf1927936fa643dc7079fc0cc731de9d6845a47741f,
        0x267855a7dc75db39d81d17f95d0a7aa572bf5ae19f4db0e84221d2b2ef999219,
        0x1184e11836b4c36ad8238a340ecc0985eeba665327e33e9b0e3641027c27620d,
        0x0702ab83a135d7f55350ab1bfaa90babd8fc1d2b3e6a7215381a7b2213d6c5ce,
        0x2eecc0de814cfd8c57ce882babb2e30d1da56621aef7a47f3291cffeaec26ad7,
        0x280bc02145c155d5833585b6c7b08501055157dd30ce005319621dc462d33b47,
        0x045132221d1fa0a7f4aed8acd2cbec1e2189b7732ccb2ec272b9c60f0d5afc5b,
        0x27f427ccbf58a44b1270abbe4eda6ba53bd6ac4d88cf1e00a13c4371ce71d366,
        0x1617eaae5064f26e8f8a6493ae92bfded7fde71b65df1ca6d5dcec0df70b2cef,
        0x20c6b400d0ea1b15435703c31c31ee63ad7ba5c8da66cec2796feacea575abca,
        0x09589ddb438723f53a8e57bdada7c5f8ed67e8fece3889a73618732965645eec,
        0x0064b6a738a5ff537db7b220f3394f0ecbd35bfd355c5425dc1166bf3236079b,
        0x095de56281b1d5055e897c3574ff790d5ee81dbc5df784ad2d67795e557c9e9f,
        0x11cf2e2887aa21963a6ec14289183efe4d4c60f14ecd3d6fe0beebdf855a9b63,
        0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb,
        0x16fdb637c2abf9c0f988dbf2fd64258c46fb6a273d537b2cf1603ea460b13279,
        0x21bbd7e944f6124dad4c376df9cc12e7ca66e47dff703ff7cedb1a454edcf0ff,
        0x2784f8220b1c963e468f590f137baaa1625b3b92a27ad9b6e84eb0d3454d9962,
        0x16ace1a65b7534142f8cc1aad810b3d6a7a74ca905d9c275cb98ba57e509fc10,
        0x2328068c6a8c24265124debd8fe10d3f29f0665ea725a65e3638f6192a96a013,
        0x2ddb991be1f028022411b4c4d2c22043e5e751c120736f00adf54acab1c9ac14,
        0x0113798410eaeb95056a464f70521eb58377c0155f2fe518a5594d38cc209cc0,
        0x202d1ae61526f0d0d01ef80fb5d4055a7af45721024c2c24cffd6a3798f54d50,
        0x23ab323453748129f2765f79615022f5bebd6f4096a796300aab049a60b0f187,
        0x1f15585f8947e378bcf8bd918716799da909acdb944c57150b1eb4565fda8aa0,
        0x1eb064b21055ac6a350cf41eb30e4ce2cb19680217df3a243617c2838185ad06,
    ];
    let public_balance = 0x000000000000000000000000000000000000000000000000000000000000000a;
    let prev_nonce = 0x00;
    let prev_shadow_balance = 0x000000000000000000000000000000000000000000000000000000000000000a;
    let prev_shadow_balance_index = 0;
    let public_balance_index = 0;

    main(
        transfer_amount,
        nullifier_value,
        nullifier_key,
        prev_shadow_balance_root,
        public_balance_root,
        recipient_account,
        prev_shadow_balance_merkle_proof,
        public_balance_merkle_proof,
        sender_account,
        secret,
        public_balance,
        prev_nonce,
        prev_shadow_balance,
        prev_shadow_balance_index,
        public_balance_index,
    );
}
/*
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
    let header_rlp: [u8; 607] = [
        249, 2, 92, 160, 239, 37, 169, 176, 180, 227, 63, 164, 8, 23, 74, 123, 2, 50, 96, 72, 192,
        223, 169, 179, 175, 31, 225, 216, 123, 74, 73, 232, 114, 130, 59, 90, 160, 29, 204, 77, 232,
        222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26, 211, 18, 69, 27, 148, 138, 116,
        19, 240, 161, 66, 253, 64, 212, 147, 71, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 160, 22, 96, 101, 252, 118, 165, 64, 236, 30, 201, 68, 228, 168, 228, 9, 200,
        217, 97, 91, 119, 98, 21, 4, 239, 255, 21, 78, 1, 50, 248, 232, 248, 160, 136, 102, 42, 69,
        64, 99, 89, 76, 135, 191, 116, 65, 216, 161, 127, 113, 49, 212, 190, 59, 37, 30, 139, 65,
        60, 85, 44, 161, 45, 226, 246, 216, 160, 158, 25, 2, 237, 43, 125, 57, 186, 32, 212, 200,
        246, 195, 128, 119, 200, 198, 67, 196, 165, 185, 217, 54, 244, 106, 106, 21, 249, 173, 46,
        18, 143, 185, 1, 0, 0, 2, 16, 0, 4, 0, 0, 64, 0, 0, 32, 0, 0, 128, 64, 32, 0, 4, 0, 0, 34,
        0, 32, 16, 8, 16, 18, 0, 0, 80, 1, 1, 5, 16, 0, 0, 32, 2, 8, 0, 16, 0, 128, 0, 0, 0, 0, 0,
        0, 0, 64, 0, 0, 32, 2, 4, 0, 0, 0, 4, 0, 32, 0, 0, 0, 0, 128, 0, 4, 112, 32, 0, 2, 0, 0, 8,
        0, 0, 0, 0, 0, 0, 8, 16, 0, 0, 0, 0, 160, 1, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 66, 16, 0, 16, 0,
        0, 4, 0, 0, 0, 8, 8, 0, 0, 0, 64, 32, 16, 64, 0, 0, 0, 0, 16, 0, 0, 2, 0, 0, 1, 4, 0, 0, 0,
        0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 8, 129, 128, 0, 0, 0, 0, 7, 65, 2, 64,
        130, 0, 0, 1, 32, 0, 64, 0, 16, 0, 0, 0, 0, 0, 32, 0, 2, 0, 32, 64, 0, 16, 0, 0, 0, 0, 0, 0,
        0, 32, 32, 0, 0, 34, 0, 0, 0, 32, 0, 0, 128, 2, 1, 0, 64, 0, 0, 20, 0, 0, 32, 0, 0, 8, 0, 0,
        0, 16, 0, 0, 32, 0, 128, 16, 0, 132, 0, 0, 0, 2, 0, 0, 4, 0, 0, 2, 4, 0, 0, 0, 0, 32, 17, 0,
        128, 0, 0, 0, 32, 0, 12, 0, 0, 0, 2, 131, 98, 190, 31, 131, 152, 150, 128, 131, 14, 199,
        206, 132, 102, 104, 97, 14, 184, 97, 216, 131, 5, 3, 32, 132, 103, 101, 116, 104, 136, 103,
        111, 49, 46, 50, 48, 46, 49, 133, 108, 105, 110, 117, 120, 0, 0, 0, 0, 0, 0, 0, 98, 35, 151,
        26, 49, 19, 62, 111, 213, 69, 22, 123, 70, 156, 179, 46, 68, 8, 66, 169, 246, 237, 189, 150,
        167, 155, 212, 142, 202, 153, 105, 118, 50, 142, 15, 6, 182, 252, 51, 82, 55, 245, 167, 10,
        219, 154, 87, 83, 247, 147, 198, 131, 202, 118, 201, 93, 24, 196, 4, 87, 170, 156, 181, 215,
        1, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 136, 0, 0, 0, 0, 0, 0, 0, 0,
    ];

    let state_root: Field = 0x166065fc76a540ec1ec944e4a8e409c8d9615b77621504efff154e0132f8e8f8;

    let state_root_rlp = get_state_root(header_rlp);
    assert(
        bytes32_to_field(state_root_rlp) == state_root,
        "state root doesnt match. Did the header layout change?",
    );
}

#[test]
fn test_main() {
    //----- public inputs
    let remint_address: Field = 0x93211e420c8F552a0e4836f84892a0D4eb5D6D54;
    let withdraw_amount: Field = 0x8ac7230489e80000;
    let nullifier: Field = 0x212456bab521c4afa65cca2751d74f7cbac9ba747d7bc3c21be994b886a7bfe1;
    let nullifier_key: Field = 0x0a2fdf0860adb5ea719794ecf7ec81cc57e56f1846e1508a7fa6448d36cd9624;
    //let block_hash: [u8; 32] = [0x40,0x60,0xee,0xf3,0xb5,0xa5,0xf2,0x87,0x02,0x74,0xb0,0x30,0xe8,0xd8,0x3c,0x69,0xd2,0xf2,0x13,0xfe,0x4d,0x1b,0xd8,0x41,0xea,0x9b,0xe2,0x90,0x7f,0x79,0xc9,0x5d];
    let storage_root: Field = 0x1acea27e9cfb8fd7576d57d039f4c77e0d8edeb1d056bcc5213b7a65842cd900;

    //-----private inputs -----
    let secret: Field = 0x1cf2c2021c2e15a1c61547a32a6295078aacf089edb3cc66fd992f627f30f824;
    let burned_balance: [u8; 32] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x16, 0xc4, 0xab, 0xbe, 0xbe, 0xa0, 0x10,
        0x00, 0x00,
    ];
    let nonce: Field = 3;
    let prev_nullifier_key: Field =
        0x1546f8d229c5a0943586cd5261ab4adbf995e849976a689a6055a32d4fae8337;
    let prev_spend_amount: Field = 30000000000000000000;

    let burn_addr_storage_proof = Hash_path_proof {
        hash_path: [
            0x271dcf322b72eadde439e5f2fe303af0d6ab3fa6c79a9466704a4791f85af7b3,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x2bff2dd5919b91b80722debba0da0ba15eb2ac950ba965c07cde492494242177,
            0x29e2f4c47f71ee542e6ab5571f0eda8230b57f3166178244ea0603655ec82ddb,
            0x037babdabb3dd50298f663dcfb1124a68a0f2b80dcd4a949f797a188e6c93964,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ],
        node_types: [
            7, 8, 9, 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0,
        ],
        leaf_type: 0x04,
        real_hash_path_len: 5,
        hash_path_bools: [
            false, false, false, false, false, false, false, false, false, false, false, false,
            false, false, false, false, false, false, false, false, false, false, false, false,
            false, false, false, false, false, false, false, false,
        ],
    };
    let prev_nullifier_storage_proof = Hash_path_proof {
        hash_path: [
            0x0b740b3b3c51a59c48c9eb1463d725ce7cac0bc306988485c1faab915d162544,
            0x1994aab20b7fed2fe15b917c4582250c146700553fefaf41449237bc67053b13,
            0x1792184d393ac7d787217a5704feca25054d79efa6d99dc0dac728234f2f5f7f,
            0x0e8a61ecf3189248e1aaa0c3fa333cc207b3b871c3b83621040e845bcc8fa7f3,
            0x1221df3235836747f28777f8eb3c78979ad8f4cb70c1d4bc63142116258d60b8,
            0x22766d6b32b905252b05efb58814689ccc270cf5b526e9779ec552a279ff8cd5,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ],
        node_types: [
            6, 9, 7, 9, 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0,
        ],
        leaf_type: 0x04,
        real_hash_path_len: 6,
        hash_path_bools: [
            false, false, true, false, true, true, false, false, false, false, false, false, false,
            false, false, false, false, false, false, false, false, false, false, false, false,
            false, false, false, false, false, false, false,
        ],
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

*/

