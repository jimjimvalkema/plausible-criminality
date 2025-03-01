mod cors;
mod types;
use alloy::{
    contract::{ContractInstance, Interface},
    dyn_abi::DynSolValue,
    hex::ToHexExt,
    network::EthereumWallet,
    primitives::Address,
    providers::ProviderBuilder,
    signers::local::PrivateKeySigner,
};
use cors::Cors;
use rocket::{post, routes, serde::json::Json, State};
use types::TransactionResponse;
use types::{PrivateTransactionRequest, PublicTransactionRequest};
#[macro_use]
extern crate rocket;
extern crate dotenv;
use anyhow::{Context, Result};

use dotenv::dotenv;
use std::env;

const CONTRACT_ABI_PATH: &str =
    "../ignition/deployments/chain-11155111/artifacts/UltraAnonModule#UltraAnon.json";

async fn transfer_logic(
    function_name: &str,
    function_args: &[DynSolValue],
    state: &State<AppState>,
) -> Json<TransactionResponse> {
    let signer: PrivateKeySigner = state.private_key.parse().expect("should parse private key");
    let wallet = EthereumWallet::from(signer.clone());

    let provider_url = state.provider_url.clone();
    let provider = ProviderBuilder::new()
        .wallet(wallet)
        .on_http(provider_url.parse().unwrap());

    // Read the artifact which contains `abi`, `bytecode`, `deployedBytecode` and `metadata`.
    let artifact = std::fs::read(CONTRACT_ABI_PATH).expect("Failed to read artifact");
    let json: serde_json::Value = serde_json::from_slice(&artifact).unwrap();

    // Get `abi` from the artifact.
    let abi_value = json.get("abi").expect("Failed to get ABI from artifact");
    let abi = serde_json::from_str(&abi_value.to_string()).unwrap();

    let contract_address = state.contract_address;
    let contract = ContractInstance::new(contract_address, provider.clone(), Interface::new(abi));

    let call_builder = contract.function(function_name, function_args);

    if let Err(err) = call_builder {
        let err = format!("call builder error: {}", err);
        return Json(TransactionResponse {
            success: false,
            txn_hash: None,
            error: Some(err),
        });
    }

    let pending_txn_builder = call_builder.unwrap().send().await;

    if let Err(err) = pending_txn_builder {
        let err = format!("pending transaction builder error: {}", err);
        return Json(TransactionResponse {
            success: false,
            txn_hash: None,
            error: Some(err),
        });
    }

    match pending_txn_builder.unwrap().watch().await {
        Ok(txn_hash) => {
            let txn_hash = txn_hash.encode_hex();
            Json(TransactionResponse {
                success: true,
                txn_hash: Some(txn_hash),
                error: None,
            })
        }
        Err(err) => {
            let err = format!("transaction execution error: {}", err);
            Json(TransactionResponse {
                success: false,
                txn_hash: None,
                error: Some(err),
            })
        }
    }
}

#[post("/", format = "json", data = "<request>")]
async fn private_transfer(
    request: Json<PrivateTransactionRequest>,
    state: &State<AppState>,
) -> Json<TransactionResponse> {
    let args = request.to_args();
    transfer_logic("privateTransfer", &args, state).await
}

#[post("/", format = "json", data = "<request>")]
async fn public_transfer(
    request: Json<PublicTransactionRequest>,
    state: &State<AppState>,
) -> Json<TransactionResponse> {
    let args = request.to_args();
    transfer_logic("publicTransfer", &args, state).await
}

#[get("/")]
fn hello() -> String {
    "Hello!".to_string()
}

struct AppState {
    // TODO: use arc<Provider> instead of creating a new provider lol
    // I can't be fucked to deal with alloy types rn
    provider_url: String,
    contract_address: Address,
    private_key: String,
}

#[options("/<_..>")]
fn all_options() {
    // This is intentionally empty - the actual response is handled by the CORS fairing
}

#[rocket::main]
async fn main() -> Result<()> {
    dotenv().ok();
    let provider_url = env::var("PROVIDER_URL")
        .context("set PROVIDER_URL in a .env file")
        .unwrap();
    println!("provider url: {provider_url}");
    let contract_address = env::var("CONTRACT_ADDRESS")
        .context("set CONTRACT_ADDRESS in a .env file")
        .unwrap();
    println!("contract address: {contract_address}");
    let private_key = env::var("PRIVATE_KEY")
        .context("set PRIVATE_KEY in a .env file")
        .unwrap();

    let app_state = AppState {
        provider_url,
        contract_address: contract_address.parse().context("parse address").unwrap(),
        private_key,
    };

    let _ = rocket::build()
        .attach(Cors)
        .manage(app_state)
        .mount("/", routes![hello, all_options])
        .mount("/private_transfer", routes![private_transfer])
        .mount("/public_transfer", routes![public_transfer])
        .configure(rocket::Config::figment().merge(("address", "0.0.0.0")))
        .launch()
        .await?;

    Ok(())
}
