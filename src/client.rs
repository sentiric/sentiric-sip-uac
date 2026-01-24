// sentiric-sip-uac/src/client.rs

use std::net::UdpSocket;
use std::thread;
use std::time::{Duration, Instant};
use sentiric_sip_core::{SipPacket, Method, Header, HeaderName};
use sentiric_sip_core::parser;
// DÜZELTME: Kullanılmayan G729Encoder ve Encoder kaldırıldı.
// Sadece kullanılan RtpHeader ve CodecType kaldı.
use sentiric_rtp_core::{RtpHeader, CodecType, CodecFactory}; 

pub struct Client {
    socket: UdpSocket,
    target_ip: String,
    target_port: u16,
    local_port: u16,
}

impl Client {
    pub fn new(target_ip: &str, target_port: u16) -> Self {
        let local_port = 6060;
        let socket = UdpSocket::bind(format!("0.0.0.0:{}", local_port))
            .expect("UAC: UDP port 6060 açılamadı.");
        
        socket.set_read_timeout(Some(Duration::from_secs(3))).unwrap();

        Client {
            socket,
            target_ip: target_ip.to_string(),
            target_port,
            local_port,
        }
    }

    pub fn start_call(&self, to_user: &str) {
        println!("📞 [UAC] Çağrı başlatılıyor -> {}:{}", self.target_ip, self.target_port);

        let call_id = format!("call-{}@127.0.0.1", 12345);
        let from = format!("<sip:test_uac@127.0.0.1:{}>;tag=client-tag", self.local_port);
        let to = format!("<sip:{}@{}:{}>", to_user, self.target_ip, self.target_port);
        
        let mut invite = SipPacket::new_request(Method::Invite, format!("sip:{}@{}:{}", to_user, self.target_ip, self.target_port));
        
        invite.headers.push(Header::new(HeaderName::Via, format!("SIP/2.0/UDP 127.0.0.1:{};branch=z9hG4bK-uac-1", self.local_port)));
        invite.headers.push(Header::new(HeaderName::From, from.clone()));
        invite.headers.push(Header::new(HeaderName::To, to.clone()));
        invite.headers.push(Header::new(HeaderName::CallId, call_id.clone()));
        invite.headers.push(Header::new(HeaderName::CSeq, "1 INVITE".to_string()));
        invite.headers.push(Header::new(HeaderName::Contact, format!("<sip:test_uac@127.0.0.1:{}>", self.local_port)));
        invite.headers.push(Header::new(HeaderName::UserAgent, "Sentiric UAC Tester".to_string()));
        invite.headers.push(Header::new(HeaderName::ContentType, "application/sdp".to_string()));

        let sdp = format!(
            "v=0\r\n\
            o=- 111 111 IN IP4 127.0.0.1\r\n\
            s=Client\r\n\
            c=IN IP4 127.0.0.1\r\n\
            t=0 0\r\n\
            m=audio 20000 RTP/AVP 18 101\r\n\
            a=rtpmap:18 G729/8000\r\n\
            a=fmtp:18 annexb=no\r\n\
            a=sendrecv\r\n"
        );
        invite.body = sdp.as_bytes().to_vec();

        self.send(&invite);
        self.listen_loop(call_id, to, from);
    }

    fn listen_loop(&self, call_id: String, to_header: String, from_header: String) {
        let mut buf = [0u8; 4096];
        let start_time = Instant::now();

        loop {
            if start_time.elapsed() > Duration::from_secs(30) {
                println!("❌ [UAC] Timeout.");
                break;
            }

            if let Ok((size, src)) = self.socket.recv_from(&mut buf) {
                let data = buf[..size].to_vec();
                
                match parser::parse(&data) {
                    Ok(packet) => {
                        println!("[ALINDI] {} {}", packet.status_code, packet.reason);

                        if packet.status_code == 200 {
                            println!("✅ 200 OK Alındı. ACK gönderiliyor...");
                            
                            let remote_tag = packet.headers.iter()
                                .find(|h| h.name == HeaderName::To)
                                .map(|h| h.value.clone())
                                .unwrap_or(to_header.clone());

                            let mut ack = SipPacket::new_request(Method::Ack, format!("sip:{}:{}", self.target_ip, self.target_port));
                            ack.headers.push(Header::new(HeaderName::Via, format!("SIP/2.0/UDP 127.0.0.1:{};branch=z9hG4bK-uac-2", self.local_port)));
                            ack.headers.push(Header::new(HeaderName::From, from_header.clone()));
                            ack.headers.push(Header::new(HeaderName::To, remote_tag));
                            ack.headers.push(Header::new(HeaderName::CallId, call_id.clone()));
                            ack.headers.push(Header::new(HeaderName::CSeq, "1 ACK".to_string()));
                            ack.headers.push(Header::new(HeaderName::ContentLength, "0".to_string()));

                            self.send(&ack);

                            let rtp_target_ip = src.ip().to_string();
                            self.start_rtp_precision(rtp_target_ip, 10000); 
                            break;
                        }
                    },
                    Err(e) => {
                        eprintln!("⚠️ [UAC] Parse Hatası: {}", e);
                    }
                }
            }
        }
    }

    fn send(&self, pkt: &SipPacket) {
        let bytes = pkt.to_bytes();
        if let Err(e) = self.socket.send_to(&bytes, format!("{}:{}", self.target_ip, self.target_port)) {
            eprintln!("❌ [UAC] Gönderim Hatası: {}", e);
        }
    }

    fn start_rtp_precision(&self, target_ip: String, target_port: u16) {
        println!("🎵 [UAC] RTP Yayını Başlıyor -> {}:{}", target_ip, target_port);
        // Factory kullanarak encoder oluşturuyoruz
        let mut encoder = CodecFactory::create_encoder(CodecType::G729);
        let pcm = vec![0i16; 160]; 
        
        let mut seq = 0u16;
        let mut ts = 0u32;
        
        let frame_duration = Duration::from_micros(20000); 
        let mut next_wakeup = Instant::now();

        for _ in 0..500 {
            let encoded = encoder.encode(&pcm);
            let mut header = RtpHeader::new(18, seq, ts, 0x998877);
            if seq == 0 { header.marker = true; }
            
            let pkt = sentiric_rtp_core::RtpPacket { header, payload: encoded };
            
            let _ = self.socket.send_to(&pkt.to_bytes(), format!("{}:{}", target_ip, target_port));
            
            seq = seq.wrapping_add(1);
            ts = ts.wrapping_add(160);

            next_wakeup += frame_duration;
            let now = Instant::now();
            if now < next_wakeup {
                let sleep_dur = next_wakeup - now;
                if sleep_dur > Duration::from_millis(1) {
                    thread::sleep(sleep_dur - Duration::from_millis(1));
                }
                while Instant::now() < next_wakeup {
                    std::hint::spin_loop();
                }
            }
        }
        println!("🛑 [UAC] Test Bitti.");
    }
}