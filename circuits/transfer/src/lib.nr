use dep::merkle::compute_merkle_root;
use dep::std::hash::poseidon;

fn lower_then_or_equal(a: Field, b: Field) -> bool {
    !std::field::bn254::gt(a, b)
}

// convert 32 byte hash to 20 bytes by chopping off the last 12
fn convert_hash_to_evm_address(hash: Field) -> Field {
    let hash_bytes: [u8; 32] = hash.to_be_bytes();

    // initialize empty byte array
    let mut address: [u8; 32] = [0; 32];
    for i in 0..20 {
        // copy bytes from the hash over to the address, leaving the first 12 bytes as 0
        address[12 + i] = hash_bytes[i];
    }

    Field::from_be_bytes(address)
}

// extracted logic for privateTransfer and publicTransfer.
// all variables in this function can be private because visibility only has an effect on the entrypoint functions, which are
// the main() functions in privateTransfer and publicTransfer.
pub fn transfer(
    transfer_amount: Field,
    // Poseidon(prev_shadow_bal + transfer_amt, prev_nonce + 1, Secret)
    nullifier_value: Field,
    // Poseidon(prev_nonce + 1, Secret)
    nullifier_key: Field,
    prev_shadow_balance_root: Field,
    incoming_balance_root: Field,
    // this is a parameter in private/public transfers but we don't actually use it at all so we can leave it out here
    // recipient_account: Field,
    // information that could be used to id sender
    // hashes needed to re-construct the merkle root for both trees
    // if this was public somone would be able to link youre previous txns together
    prev_shadow_balance_merkle_proof: [Field; 31],
    incoming_balance_merkle_proof: [Field; 31],
    // poseidon(Secret)
    sender_account: Field,
    // private key
    secret: Field,
    // incoming balance
    incoming_balance: Field,
    // num txns
    nonce: Field,
    // total amount privately sent
    prev_shadow_balance: Field,
    // position of the account from the array that holds the merkle roots
    // just for merkle proof
    prev_shadow_balance_index: Field,
    incoming_balance_index: Field,
) {
    // make sure the secret key is from the sender_account by hashing it
    let hashed_secret = poseidon::bn254::hash_1([secret]);
    let computed_sender_account = convert_hash_to_evm_address(hashed_secret);
    assert(
        computed_sender_account == sender_account,
        "hash of secret doesn't match the sender_account.  Make sure the secret is from the sender account",
    );

    // verify new nullifier key
    let computed_nullifier_key = poseidon::bn254::hash_2([nonce, secret]);
    assert(
        computed_nullifier_key == nullifier_key,
        "nullifier key computed in circuit doesn't match nullifier key passed in as parameter",
    );

    // verify new nullifier value
    let computed_nullifier_value = poseidon::bn254::hash_3([
        prev_shadow_balance + transfer_amount,
        nonce,
        secret,
    ]);
    assert(
        computed_nullifier_value == nullifier_value,
        "nullifier value computed in circuit doesn't match nullifier value passed in as parameter",
    );

    if nonce != 0 {
        // compute previous nullifier key & value
        let prev_nullifier_key = poseidon::bn254::hash_2([nonce - 1, secret]);
        let prev_nullifier_value =
            poseidon::bn254::hash_3([prev_shadow_balance, nonce - 1, secret]);

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
            "computed previous shadow balance tree root doesn't match previous shadow balance tree root passed in as parameter",
        );
    }

    // verify incoming balance tree root
    let incoming_balance_leaf = poseidon::bn254::hash_2([sender_account, incoming_balance]);
    println(f"sender_account: {sender_account}");
    println(f"incoming_balance: {incoming_balance}");
    println(f"incoming_balance: {incoming_balance_leaf}");
    let computed_incoming_balance_root = compute_merkle_root(
        incoming_balance_leaf,
        incoming_balance_index,
        incoming_balance_merkle_proof,
    );
    println(f"computed_incoming_balance_leaf: {incoming_balance_leaf}");
    println(f"incoming_balance_index: {incoming_balance_index}");

    println(f"incoming_balance_root: {incoming_balance_root}");
    println(
        f"computed_incoming_balance_root: {computed_incoming_balance_root}",
    );

    assert(
        computed_incoming_balance_root == incoming_balance_root,
        "computed incoming balance tree root doesn't match incoming balance tree root passed in as parameter",
    );

    // make sure user has enough funds to send
    let new_shadow_balance = prev_shadow_balance + transfer_amount;
    assert(
        lower_then_or_equal(new_shadow_balance, incoming_balance),
        "not enough funds to transfer",
    );
}

#[test]
fn test_transfer() {
    /* Scenario: account A privately sends 5 tokens

    before:
        account A:
            incoming_bal: 10
            private_bal: 0
            nonce: 0
    after:
        account A:
            incoming_bal: 10
            private_bal: 5
            nonce: 1
    */

    let sender_account = 0x29176100eaa962bdc1fe6c654d6a3c130e96a4d1;
    let secret = 0x01;
    let transfer_amount = 0x0000000000000000000000000000000000000000000000000000000000000005;
    let nullifier_value = 0x0a336d135f550efc5be349d371ce31288858a0ddd2ad3442bb19d33d5e24f7e4;
    let nullifier_key = 0x007af346e2d304279e79e0a9f3023f771294a78acb70e73f90afe27cad401e81;
    let prev_shadow_balance_root =
        0x1d1ed21618f0912fc3242174b9b33e9f05d8c6f60d21697c3c8cbfca8dfe272f;
    let incoming_balance_root = 0x1ab32fa66d53183dcab6263a4cba066949ca88405ff498e8ebc7bba488b03070;
    let prev_shadow_balance_merkle_proof = [
        // 0x0000000000000000000000000000000000000000000000000000000000000001,
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
    let incoming_balance_merkle_proof = [
        // 0x0000000000000000000000000000000000000000000000000000000000000001,
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
    let incoming_balance = 0x000000000000000000000000000000000000000000000000000000000000000a;
    let prev_nonce = 0x00;
    let prev_shadow_balance = 0x0000000000000000000000000000000000000000000000000000000000000000;
    let prev_shadow_balance_index = 0;
    let incoming_balance_index = 0;

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
    );
}

// test when a user doesn't have enough funds to transfer
#[test(should_fail)]
fn test_transfer_not_enough_funds() {
    // Scenario: account A privately sends 11 tokens but only has an incoming balance of 10

    let sender_account = 0x29176100eaa962bdc1fe6c654d6a3c130e96a4d1;
    let secret = 0x01;
    let transfer_amount = 0x000000000000000000000000000000000000000000000000000000000000000b;
    let nullifier_value = 0x2878bbb29381499707dd573714ba645f437735aaf409e9449580207e67702541;
    let nullifier_key = 0x007af346e2d304279e79e0a9f3023f771294a78acb70e73f90afe27cad401e81;
    let prev_shadow_balance_root =
        0x1d1ed21618f0912fc3242174b9b33e9f05d8c6f60d21697c3c8cbfca8dfe272f;
    let incoming_balance_root = 0x1ab32fa66d53183dcab6263a4cba066949ca88405ff498e8ebc7bba488b03070;
    let prev_shadow_balance_merkle_proof = [
        // 0x0000000000000000000000000000000000000000000000000000000000000001,
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
    let incoming_balance_merkle_proof = [
        // 0x0000000000000000000000000000000000000000000000000000000000000001,
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
    let incoming_balance = 0x000000000000000000000000000000000000000000000000000000000000000a;
    let prev_nonce = 0x00;
    let prev_shadow_balance = 0x0000000000000000000000000000000000000000000000000000000000000000;
    let prev_shadow_balance_index = 0;
    let incoming_balance_index = 0;

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
    );
}

#[test]
fn test_transfer_exactly_enough_funds() {
    // Scenario: account A privately sends 10 tokens and has an incoming balance of 10

    let sender_account = 0x29176100eaa962bdc1fe6c654d6a3c130e96a4d1;
    let secret = 0x01;
    let transfer_amount = 0x000000000000000000000000000000000000000000000000000000000000000a;
    let nullifier_value = 0x210f1ec525c757ecb3460dfca11329911cf0bd48e0ac1bc83174f96fd7d5921e;
    let nullifier_key = 0x007af346e2d304279e79e0a9f3023f771294a78acb70e73f90afe27cad401e81;
    let prev_shadow_balance_root =
        0x1d1ed21618f0912fc3242174b9b33e9f05d8c6f60d21697c3c8cbfca8dfe272f;
    let incoming_balance_root = 0x1ab32fa66d53183dcab6263a4cba066949ca88405ff498e8ebc7bba488b03070;
    let prev_shadow_balance_merkle_proof = [
        // 0x0000000000000000000000000000000000000000000000000000000000000001,
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
    let incoming_balance_merkle_proof = [
        // 0x0000000000000000000000000000000000000000000000000000000000000001,
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
    let incoming_balance = 0x000000000000000000000000000000000000000000000000000000000000000a;
    let prev_nonce = 0x00;
    let prev_shadow_balance = 0x0000000000000000000000000000000000000000000000000000000000000000;
    let prev_shadow_balance_index = 0;
    let incoming_balance_index = 0;

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
    );
}
