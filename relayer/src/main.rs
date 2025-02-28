use alloy::{
    hex::{FromHex, ToHexExt},
    primitives::Bytes,
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

struct AppState {
    // TODO: use arc<Provider> instead of creating a new provider lol
    // I can't be fucked to deal with alloy types rn
    provider_url: String,
}

#[rocket::main]
async fn main() -> Result<()> {
    dotenv().ok();
    let provider_url = env::var("PROVIDER_URL")
        .context("set PROVIDER_URL in a .env file")
        .unwrap();
    println!("provider url: {provider_url}");

    let app_state = AppState { provider_url };

    let _ = rocket::build()
        .manage(app_state)
        .mount("/", routes![hello])
        .mount("/call", routes![call])
        .launch()
        .await?;

    Ok(())
}

#[derive(Debug, Deserialize)]
struct CalldataRequest {
    calldata: String,
}

#[derive(Debug, Serialize)]
struct CalldataResponse {
    success: bool,
    txn_hash: Option<String>,
    error: Option<String>,
}

// endpoint "/call" with json like {"calldata": "some calldata"}
#[post("/", format = "json", data = "<request>")]
async fn call(request: Json<CalldataRequest>, state: &State<AppState>) -> Json<CalldataResponse> {
    let calldata = request.calldata.clone();

    let provider_url = state.provider_url.clone();
    let provider = ProviderBuilder::new().on_http(provider_url.parse().unwrap());

    let call_bytes = Bytes::from_hex(calldata).unwrap();
    let txn_builder = provider.send_raw_transaction(call_bytes.as_ref()).await;

    if let Err(err) = txn_builder {
        let err = err.to_string();
        println!("txn failed. error: {err}");
        return Json(CalldataResponse {
            success: false,
            txn_hash: None,
            error: Some(err),
        });
    }

    // okay to unwrap because we just exited early above if it was an err
    match txn_builder
        .unwrap()
        .with_required_confirmations(1)
        .with_timeout(Some(std::time::Duration::from_secs(60)))
        .watch()
        .await
    {
        Ok(txn_hash) => {
            let txn_hash = txn_hash.encode_hex();
            println!("txn success.  txn_hash: {txn_hash}");
            Json(CalldataResponse {
                success: true,
                txn_hash: Some(txn_hash),
                error: None,
            })
        }
        Err(err) => {
            let err = err.to_string();
            println!("txn failed. error: {err}");
            Json(CalldataResponse {
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
