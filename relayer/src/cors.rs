use rocket::{
    fairing::{Fairing, Info, Kind},
    http::{Header, Method},
    Request, Response,
};

// Create a CORS fairing
pub struct Cors;

#[rocket::async_trait]
impl Fairing for Cors {
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
