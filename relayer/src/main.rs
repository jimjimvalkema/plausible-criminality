use alloy::{contract::RawCallBuilder, providers::ProviderBuilder};
use rocket::{post, routes, serde::json::Json, State};
use serde::{Deserialize, Serialize};
#[macro_use]
extern crate rocket;
extern crate dotenv;
use anyhow::{Context, Result};

use dotenv::dotenv;
use std::env;

// #[tokio::main]
// async fn main() -> Result<()> {
//     dotenv().ok();
//     let provider_url = env::var("PROVIDER_URL")
//         .context("set PROVIDER_URL in a .env file")
//         .unwrap();
//     println!("provider url: {provider_url}");
//     let provider = ProviderBuilder::new().on_http(provider_url.parse().unwrap());
//
//     let call_bytes = "x".to_string().into();
//     let call = RawCallBuilder::<(), _, _>::new_raw(provider, call_bytes)
//         .call()
//         .await?;
//
//     println!("Made txn");
//
//     Ok(())
// }
//
//
//

#[derive(Debug, Deserialize)]
struct CalldataRequest {
    calldata: String,
}

#[derive(Debug, Serialize)]
struct CalldataResponse {
    message: String, // success: bool,
                     // error: Option<String>,
}

// endpoint "/call" with json like {"calldata": "some calldata"}
#[post("/", format = "json", data = "<request>")]
fn call(request: Json<CalldataRequest>) -> Json<CalldataResponse> {
    let calldata = request.calldata.clone();

    Json(CalldataResponse { message: calldata })
}

#[get("/")]
fn hello() -> String {
    "Hello!".to_string()
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .mount("/", routes![hello])
        .mount("/call", routes![call])
}
