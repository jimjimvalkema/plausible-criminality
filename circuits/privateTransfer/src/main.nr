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

#[test]
fn test_main() {
    let sender_account = 0x29176100eaa962bdc1fe6c654d6a3c130e96a4d1;
    let secret = 0x01;
    let transfer_amount = 0x63;
    let nullifier_value = 0x2630cc50d3b7412c44e2d1858709a176b8b070cc249e837ac0255a59131abe66;
    let nullifier_key = 0x7af346e2d304279e79e0a9f3023f771294a78acb70e73f90afe27cad401e81;
    let prev_shadow_balance_root =
        0x1eb064b21055ac6a350cf41eb30e4ce2cb19680217df3a243617c2838185ad06;
    let incoming_balance_root = 0x0c8e2cee16292be5f5c8785d204b3ec6613dbe139a115e8330c97cd31a0ac60f;
    let prev_shadow_balance_merkle_proof = [
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
        0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c,
        0x13e37f2d6cb86c78ccc1788607c2b199788c6bb0a615a21f2e7a8e88384222f8,
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
        0x64b6a738a5ff537db7b220f3394f0ecbd35bfd355c5425dc1166bf3236079b,
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
    ];
    let incoming_balance = 0x64;
    let prev_nonce = 0x00;
    let prev_shadow_balance = 0x00;
    let prev_shadow_balance_index = 0x00;
    let incoming_balance_index = 0x00;
    let recipient_account = 0x794464c8c91A2bE4aDdAbfdB82b6db7B1Bb1DBC7;

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
}

#[test]
fn test_main_2() {
    let sender_account = 0x29176100eaa962bdc1fe6c654d6a3c130e96a4d1;
    let secret = 0x01;
    let transfer_amount = 0x01;
    let nullifier_value = 0x02c0066e10a72abd2b33c3b214cb3e81bcb1b6e30961cd23c202b18673bf2543;
    let nullifier_key = 0x7af346e2d304279e79e0a9f3023f771294a78acb70e73f90afe27cad401e81;
    let prev_shadow_balance_root =
        0x2f46a7390a3e50ff334a6ae49f19ac0c9a5e223f2de57c5840e282b82349c9d7;
    let incoming_balance_root = 0x19192d6e007bb3d9416bc3b8798f845114ff6b03ca9d36c661e090a921c58501;
    let prev_shadow_balance_merkle_proof = [
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
    ];
    let incoming_balance_merkle_proof = [
        0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c,
        0x13e37f2d6cb86c78ccc1788607c2b199788c6bb0a615a21f2e7a8e88384222f8,
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
        0x64b6a738a5ff537db7b220f3394f0ecbd35bfd355c5425dc1166bf3236079b,
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
    ];
    let incoming_balance = 0x66;
    let prev_nonce = 0x00;
    let prev_shadow_balance = 0x00;
    let prev_shadow_balance_index = 0x00;
    let incoming_balance_index = 0x00;
    let recipient_account = 0x29176100eaa962bdc1fe6c654d6a3c130e96a4d1;

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
}
