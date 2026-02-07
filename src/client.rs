// sentiric-sip-uac/src/client.rs
use std::net::SocketAddr;
use std::time::Duration;
use tokio::net::UdpSocket;
use tracing::{info, warn, error, debug};
use sentiric_sip_core::{SipPacket, Method, Header, HeaderName, parser};
use sentiric_rtp_core::{RtpHeader, RtpPacket, CodecType, CodecFactory, Pacer};
use rand::Rng;

pub struct Client {
    socket: UdpSocket,
    target_addr: SocketAddr,
    local_port: u16,
}

impl Client {
    pub async fn new(target_ip: &str, target_port: u16) -> anyhow::Result<Self> {
        // Port 6060: Yerel çakışmayı önlemek için standart dışı port.
        let local_port = 6060;
        let socket = UdpSocket::bind(format!("0.0.0.0:{}", local_port)).await?;
        let target_addr = format!("{}:{}", target_ip, target_port).parse()?;

        Ok(Client {
            socket,
            target_addr,
            local_port,
        })
    }

    pub async fn start_call(&self, to_user: &str, from_user: &str) -> anyhow::Result<()> {
        let call_id = format!("uac-v15-{}", rand::thread_rng().gen::<u32>());
        
        // [v1.15.0 IDENTITY]: SBC/Proxy'nin tanıyacağı gerçek kimliği simüle et
        let from = format!("<sip:{}@sentiric.local>;tag=uac-v15-tag", from_user);
        let to = format!("<sip:{}@{}>", to_user, self.target_addr.ip());
        
        let mut invite = SipPacket::new_request(
            Method::Invite, 
            format!("sip:{}@{}:{}", to_user, self.target_addr.ip(), self.target_addr.port())
        );
        
        // Via branch (z9hG4bK magic cookie)
        invite.headers.push(Header::new(HeaderName::Via, format!("SIP/2.0/UDP 127.0.0.1:{};branch=z9hG4bK-{}", 
            self.local_port, rand::thread_rng().gen::<u16>())));
        invite.headers.push(Header::new(HeaderName::From, from.clone()));
        invite.headers.push(Header::new(HeaderName::To, to.clone()));
        invite.headers.push(Header::new(HeaderName::CallId, call_id.clone()));
        invite.headers.push(Header::new(HeaderName::CSeq, "1 INVITE".to_string()));
        invite.headers.push(Header::new(HeaderName::Contact, format!("<sip:{}@127.0.0.1:{}>", from_user, self.local_port)));
        invite.headers.push(Header::new(HeaderName::ContentType, "application/sdp".to_string()));
        invite.headers.push(Header::new(HeaderName::UserAgent, "Sentiric-UAC-Tester-v1.15.0".to_string()));

        // SDP: Standard Telekom Codecs
        let sdp = format!(
            "v=0\r\n\
            o=- 12345 12345 IN IP4 127.0.0.1\r\n\
            s=PrecisionTest\r\n\
            c=IN IP4 127.0.0.1\r\n\
            t=0 0\r\n\
            m=audio 6062 RTP/AVP 8 101\r\n\
            a=rtpmap:8 PCMA/8000\r\n\
            a=rtpmap:101 telephone-event/8000\r\n\
            a=sendrecv\r\n"
        );
        invite.body = sdp.as_bytes().to_vec();

        info!("📤 [SIP] Sending INVITE (Identity: {})", from_user);
        self.socket.send_to(&invite.to_bytes(), self.target_addr).await?;

        self.wait_for_response(call_id, to, from).await
    }

    async fn wait_for_response(&self, call_id: String, to_header: String, from_header: String) -> anyhow::Result<()> {
        let mut buf = [0u8; 4096];
        
        loop {
            let (size, src) = self.socket.recv_from(&mut buf).await?;
            let packet = parser::parse(&buf[..size])?;

            debug!("📩 [SIP] Received: {} {}", packet.status_code, packet.reason);

            if packet.status_code == 200 {
                info!("✅ [SIP] 200 OK Received. Completing Handshake...");
                
                let remote_tag = packet.get_header_value(HeaderName::To)
                    .cloned()
                    .unwrap_or(to_header.clone());

                let mut ack = SipPacket::new_request(Method::Ack, format!("sip:{}", src));
                ack.headers.push(Header::new(HeaderName::CallId, call_id.clone()));
                ack.headers.push(Header::new(HeaderName::From, from_header.clone()));
                ack.headers.push(Header::new(HeaderName::To, remote_tag));
                ack.headers.push(Header::new(HeaderName::CSeq, "1 ACK".to_string()));
                ack.headers.push(Header::new(HeaderName::Via, format!("SIP/2.0/UDP 127.0.0.1:{};branch=z9hG4bK-ack", self.local_port)));

                self.socket.send_to(&ack.to_bytes(), self.target_addr).await?;

                // [v1.3.0 PACER]: RTP Akışını nano-hassasiyette başlat
                info!("🎵 [RTP] Starting Precision Audio Stream...");
                self.run_rtp_stream(src).await?;
                break;
            } else if packet.status_code >= 400 {
                error!("❌ [SIP] Call Rejected: {} {}", packet.status_code, packet.reason);
                return Err(anyhow::anyhow!("SIP Protocol Error: {}", packet.status_code));
            }
        }
        Ok(())
    }

    async fn run_rtp_stream(&self, media_addr: SocketAddr) -> anyhow::Result<()> {
        // PCMA (G.711a) Encoder
        let mut encoder = CodecFactory::create_encoder(CodecType::PCMA);
        
        // [v1.3.0 HYBRID PACER]: Milimetrik 20ms aralığı
        let mut pacer = Pacer::new(20);
        
        let ssrc: u32 = rand::thread_rng().gen();
        let mut seq: u16 = 0;
        let mut ts: u32 = 0;

        info!("🎤 [RTP] Transmitting PCMA to {}", media_addr);

        // 10 Saniyelik Stres/Kalite Testi (500 Paket)
        for i in 0..500 {
            pacer.wait(); // Nano-second sync

            // Simüle edilmiş ses (Silence in PCMA)
            let pcm = vec![0i16; 160]; 
            let payload = encoder.encode(&pcm);

            let mut header = RtpHeader::new(8, seq, ts, ssrc);
            if i == 0 { header.marker = true; } // İlk pakette kilitlenme için Marker

            let rtp_pkt = RtpPacket { header, payload };
            
            if let Err(e) = self.socket.send_to(&rtp_pkt.to_bytes(), media_addr).await {
                warn!("⚠️ [RTP] Send Fail: {}", e);
            }

            seq = seq.wrapping_add(1);
            ts = ts.wrapping_add(160);

            if i % 100 == 0 {
                debug!("📊 [RTP] Progress: {} packets sent", i);
            }
        }

        info!("🏁 [RTP] Test Sequence Completed.");
        Ok(())
    }
}