// src/main.rs

mod client;
use client::Client;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let target_ip = if args.len() > 1 { &args[1] } else { "127.0.0.1" };
    
    println!("--- SENTIRIC SIP UAC (TEST CLIENT) ---");
    println!("Hedef: {}", target_ip);

    let client = Client::new(target_ip, 5060);
    client.start_call("905551234567");
}