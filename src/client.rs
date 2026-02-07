// sentiric-sip-uac/src/client.rs
use std::net::SocketAddr;
use tokio::net::UdpSocket;
use tracing::info;
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
        let local_port = 6060;
        let socket = UdpSocket::bind(format!("0.0.0.0:{}", local_port)).await?;
        let target_addr = format!("{}:{}", target_ip, target_port).parse()?;

        Ok(Client { socket, target_addr, local_port })
    }

    pub async fn start_call(&self, to_user: &str, from_user: &str) -> anyhow::Result<()> {
        let call_id = format!("uac-v15-{}", rand::thread_rng().gen::<u32>());
        let from = format!("<sip:{}@sentiric.local>;tag=uac-v15-tag", from_user);
        let to = format!("<sip:{}@{}>", to_user, self.target_addr.ip());
        
        let mut invite = SipPacket::new_request(
            Method::Invite, 
            format!("sip:{}@{}:{}", to_user, self.target_addr.ip(), self.target_addr.port())
        );
        
        invite.headers.push(Header::new(HeaderName::Via, format!("SIP/2.0/UDP 127.0.0.1:{};branch=z9hG4bK-{}", 
            self.local_port, rand::thread_rng().gen::<u16>())));
        invite.headers.push(Header::new(HeaderName::From, from.clone()));
        invite.headers.push(Header::new(HeaderName::To, to.clone()));
        invite.headers.push(Header::new(HeaderName::CallId, call_id.clone()));
        invite.headers.push(Header::new(HeaderName::CSeq, "1 INVITE".to_string()));
        invite.headers.push(Header::new(HeaderName::Contact, format!("<sip:{}@127.0.0.1:{}>", from_user, self.local_port)));
        invite.headers.push(Header::new(HeaderName::ContentType, "application/sdp".to_string()));
        invite.headers.push(Header::new(HeaderName::UserAgent, "Sentiric-UAC-Tester-v1.2.1".to_string()));

        let sdp = "v=0\r\no=- 12345 12345 IN IP4 127.0.0.1\r\ns=PrecisionTest\r\nc=IN IP4 127.0.0.1\r\nt=0 0\r\nm=audio 6062 RTP/AVP 8 101\r\na=rtpmap:8 PCMA/8000\r\na=rtpmap:101 telephone-event/8000\r\na=sendrecv\r\n";
        invite.body = sdp.as_bytes().to_vec();

        info!("📤 [SIP] Sending INVITE (Identity Restoration Test)");
        self.socket.send_to(&invite.to_bytes(), self.target_addr).await?;

        self.wait_for_response(call_id, to, from).await
    }

    async fn wait_for_response(&self, call_id: String, to_header: String, from_header: String) -> anyhow::Result<()> {
        let mut buf = [0u8; 4096];
        loop {
            let (size, src) = self.socket.recv_from(&mut buf).await?;
            let packet = parser::parse(&buf[..size])?;

            if packet.status_code == 200 {
                info!("✅ [SIP] 200 OK Received. Extracting Remote Media Port...");

                // Dynamic RTP Port Discovery
                let sdp_text = String::from_utf8_lossy(&packet.body);
                let rtp_port = self.extract_rtp_port(&sdp_text).unwrap_or(30000);
                let rtp_target = SocketAddr::new(self.target_addr.ip(), rtp_port);
                
                info!("🎯 [RTP] Target confirmed from SDP: {}", rtp_target);

                let remote_tag = packet.get_header_value(HeaderName::To).cloned().unwrap_or(to_header.clone());
                let mut ack = SipPacket::new_request(Method::Ack, format!("sip:{}", src));
                ack.headers.push(Header::new(HeaderName::CallId, call_id.clone()));
                ack.headers.push(Header::new(HeaderName::From, from_header.clone()));
                ack.headers.push(Header::new(HeaderName::To, remote_tag));
                ack.headers.push(Header::new(HeaderName::CSeq, "1 ACK".to_string()));
                ack.headers.push(Header::new(HeaderName::Via, format!("SIP/2.0/UDP 127.0.0.1:{};branch=z9hG4bK-ack", self.local_port)));

                self.socket.send_to(&ack.to_bytes(), self.target_addr).await?;

                info!("🎵 [RTP] Starting Audio Sequence...");
                self.run_rtp_stream(rtp_target).await?;
                break;
            } else if packet.status_code >= 400 {
                return Err(anyhow::anyhow!("SIP Error: {}", packet.status_code));
            }
        }
        Ok(())
    }

    fn extract_rtp_port(&self, sdp: &str) -> Option<u16> {
        for line in sdp.lines() {
            if line.starts_with("m=audio ") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() > 1 {
                    return parts[1].parse().ok();
                }
            }
        }
        None
    }

    async fn run_rtp_stream(&self, media_addr: SocketAddr) -> anyhow::Result<()> {
        let mut encoder = CodecFactory::create_encoder(CodecType::PCMA);
        let mut pacer = Pacer::new(20);
        let ssrc: u32 = rand::thread_rng().gen();
        let mut seq: u16 = 0;
        let mut ts: u32 = 0;

        for i in 0..500 {
            pacer.wait();
            let pcm = vec![0i16; 160]; 
            let payload = encoder.encode(&pcm);
            let mut header = RtpHeader::new(8, seq, ts, ssrc);
            header.marker = i == 0;
            let rtp_pkt = RtpPacket { header, payload };
            let _ = self.socket.send_to(&rtp_pkt.to_bytes(), media_addr).await;
            seq = seq.wrapping_add(1);
            ts = ts.wrapping_add(160);
        }
        info!("🏁 [RTP] Sequence finished.");
        Ok(())
    }
}