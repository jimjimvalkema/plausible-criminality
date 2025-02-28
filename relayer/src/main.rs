use alloy::{
    contract::{ContractInstance, Interface},
    dyn_abi::DynSolValue,
    hex::{FromHex, ToHexExt},
    primitives::{Address, Bytes},
    providers::{Provider, ProviderBuilder},
};
use rocket::{post, routes, serde::json::Json, State};
use serde::{Deserialize, Serialize};
#[macro_use]
extern crate rocket;
extern crate dotenv;
use anyhow::{Context, Result};

use dotenv::dotenv;
use std::env;

const CONTRACT_ABI_PATH: &str =
    "../ignition/deployments/chain-11155111/artifacts/UltraAnonModule#UltraAnon.json";

#[derive(Debug, Deserialize)]
struct PrivateTransactionRequest {
    to: String,
    value: String,
    nullifier_value: String,
    nullifier_key: String,
    shadow_balance_root: String,
    incoming_balance_root: String,
    proof: String,
}

impl PrivateTransactionRequest {
    fn to_args(&self) -> Vec<DynSolValue> {
        vec![
            // Convert address string to DynSolValue
            DynSolValue::Address(self.to.parse().expect("Invalid address")),
            // Convert numeric strings to DynSolValue::Uint
            DynSolValue::Uint(self.value.parse().expect("Invalid value"), 256),
            DynSolValue::Uint(
                self.nullifier_value
                    .parse()
                    .expect("Invalid nullifier value"),
                256,
            ),
            DynSolValue::Uint(
                self.nullifier_key.parse().expect("Invalid nullifier key"),
                256,
            ),
            DynSolValue::Uint(
                self.shadow_balance_root
                    .parse()
                    .expect("Invalid shadow balance root"),
                256,
            ),
            DynSolValue::Uint(
                self.incoming_balance_root
                    .parse()
                    .expect("Invalid incoming balance root"),
                256,
            ),
            // Convert proof string (likely hex) to DynSolValue::Bytes
            DynSolValue::Bytes(hex::decode(&self.proof).expect("Invalid proof hex")),
        ]
    }
}

#[derive(Debug, Serialize)]
struct TransactionResponse {
    success: bool,
    txn_hash: Option<String>,
    error: Option<String>,
}

#[post("/", format = "json", data = "<request>")]
async fn private_transfer(
    request: Json<PrivateTransactionRequest>,
    state: &State<AppState>,
) -> Json<TransactionResponse> {
    let provider_url = state.provider_url.clone();
    let provider = ProviderBuilder::new().on_http(provider_url.parse().unwrap());

    // Read the artifact which contains `abi`, `bytecode`, `deployedBytecode` and `metadata`.
    let artifact = std::fs::read(CONTRACT_ABI_PATH).expect("Failed to read artifact");
    let json: serde_json::Value = serde_json::from_slice(&artifact).unwrap();

    // Get `abi` from the artifact.
    let abi_value = json.get("abi").expect("Failed to get ABI from artifact");
    let abi = serde_json::from_str(&abi_value.to_string()).unwrap();

    let contract_address = state.contract_address;
    let contract = ContractInstance::new(contract_address, provider.clone(), Interface::new(abi));

    let args = request.to_args();
    let call_builder = contract.function("privateTransfer", &args);

    if let Err(err) = call_builder {
        let err = err.to_string();
        return Json(TransactionResponse {
            success: false,
            txn_hash: None,
            error: Some(err),
        });
    }

    let pending_txn_builder = call_builder.unwrap().send().await;

    if let Err(err) = pending_txn_builder {
        let err = err.to_string();
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
            let err = err.to_string();
            Json(TransactionResponse {
                success: false,
                txn_hash: None,
                error: Some(err),
            })
        }
    }
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

    let app_state = AppState {
        provider_url,
        contract_address: contract_address.parse().context("parse address").unwrap(),
    };

    let _ = rocket::build()
        .manage(app_state)
        .mount("/", routes![hello])
        .mount("/private_transfer", routes![private_transfer])
        .launch()
        .await?;

    Ok(())
}
