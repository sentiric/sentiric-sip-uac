// sentiric-sip-uac/src/scenario.rs
use serde::Deserialize;
use std::fs;
use anyhow::{Result, Context};

#[derive(Deserialize, Debug)]
pub struct ScenarioDef {
    pub name: String,
    pub target_ip: String,
    pub port: u16,
    pub to: String,
    pub from: String,
    pub headless: bool,
    pub actions: Vec<ActionDef>,
}

#[derive(Deserialize, Debug)]
#[serde(tag = "type")]
pub enum ActionDef {
    #[serde(rename = "wait")]
    Wait { ms: u64 },
    
    #[serde(rename = "dtmf")]
    Dtmf { key: char },
    
    #[serde(rename = "hangup")]
    Hangup,
}

pub fn load_scenario(path: &str) -> Result<ScenarioDef> {
    let data = fs::read_to_string(path).context(format!("Senaryo dosyası okunamadı: {}", path))?;
    let scenario: ScenarioDef = serde_json::from_str(&data).context("Senaryo JSON formatı geçersiz")?;
    Ok(scenario)
}