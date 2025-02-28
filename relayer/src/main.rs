use alloy::{
    contract::{ContractInstance, Interface},
    dyn_abi::DynSolValue,
    hex::{FromHex, ToHexExt},
    network::EthereumWallet,
    primitives::{Address, Bytes},
    providers::{Provider, ProviderBuilder},
    signers::local::PrivateKeySigner,
};
use rocket::{
    fairing::{Fairing, Info, Kind},
    http::{Header, Method},
    post, routes,
    serde::json::Json,
    Request, Response, State,
};
use serde::{Deserialize, Serialize};
#[macro_use]
extern crate rocket;
extern crate dotenv;
use anyhow::{Context, Result};

use dotenv::dotenv;
use std::env;

const CONTRACT_ABI_PATH: &str =
    "../ignition/deployments/chain-11155111/artifacts/UltraAnonModule#UltraAnon.json";

// Create a CORS fairing
pub struct CORS;

#[rocket::async_trait]
impl Fairing for CORS {
    fn info(&self) -> Info {
        Info {
            name: "CORS Fairing",
            kind: Kind::Response | Kind::Request,
        }
    }

    async fn on_request(&self, request: &mut Request<'_>, _: &mut rocket::Data<'_>) {
        // If it's an OPTIONS request, configure it to be immediately handled
        if request.method() == Method::Options {
            request.local_cache(|| true);
        }
    }

    async fn on_response<'r>(&self, request: &'r Request<'_>, response: &mut Response<'r>) {
        response.set_header(Header::new("Access-Control-Allow-Origin", "*"));
        response.set_header(Header::new(
            "Access-Control-Allow-Methods",
            "POST, GET, OPTIONS",
        ));
        response.set_header(Header::new(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization",
        ));

        // If it's an OPTIONS request, set the status to 200 OK
        if request.method() == Method::Options {
            response.set_status(rocket::http::Status::Ok);
        }
    }
}

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

    let args = request.to_args();
    let call_builder = contract.function("privateTransfer", &args);

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
            let err = format!("transaction execution error: {}", err.to_string());
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
    private_key: String,
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
        .attach(CORS)
        .manage(app_state)
        .mount("/", routes![hello])
        .mount("/private_transfer", routes![private_transfer])
        .launch()
        .await?;

    Ok(())
}
