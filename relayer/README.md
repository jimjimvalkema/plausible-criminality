# Relay

This is a small webserver that executes smart contract calls for others. This is important to preserve the privacy of UltraAnon users. Send arguments for either `UltraAnon.publicTransfer` or `UltraAnon.privateTransfer` to the endpoints `/public_transfer` or `/private_transfer`.

# Running

By default it will run locally at port 8000. Requires env vars `PROVIDER_URL`, `CONTRACT_ADDRESS` (ultraAnon contract address) and `PRIVATE_KEY`.

Run with `cargo run` (dev) or `cargo run --release` (prod).

If you run into issues after getting it to work once or twice it's likely your rpc.
