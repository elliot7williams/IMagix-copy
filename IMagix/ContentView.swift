//
//  ContentView.swift
//  IMagix
//
//  Created by Elliot Williams on 2025-07-04.
//

import SwiftUI
import MultipeerConnectivity
import CoreMotion

struct ContentView: View {
    @StateObject private var controller = MotionController()
    
    var body: some View {
        VStack {
            ConnectionView(controller: controller)
            
            Spacer()
            
            HStack(spacing: 50) {
                Button("Left Click") {
                    controller.sendMessage("leftDown")
                }
                .buttonStyle(MouseButtonStyle())
                
                Button("Right Click") {
                    controller.sendMessage("rightDown")
                }
                .buttonStyle(MouseButtonStyle())
            }
        }
        .padding()
    }
}

struct MouseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(40)
            .background(Circle().fill(Color.blue))
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

// Connection Manager
class MotionController: NSObject, ObservableObject {
    private let motionManager = CMMotionManager()
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private let serviceType = "mouse-control"
    
    @Published var connected = false
    
    override init() {
        super.init()
        setupSession()
        startMotionUpdates()
    }
    
    private func setupSession() {
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
    }
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Calculate cursor movement (tune sensitivity as needed)
            let dx = motion.gravity.x * 500
            let dy = motion.gravity.y * 500
            
            if abs(dx) > 1 || abs(dy) > 1 {
                self.sendMessage("move:\(dx),\(dy)")
            }
        }
    }
    
    func sendMessage(_ message: String) {
        guard connected, let data = message.data(using: .utf8) else { return }
        
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Send error: \(error)")
        }
    }
}

extension MotionController: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connected = (state == .connected)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MotionController: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, self.session)
    }
}

struct ConnectionView: View {
    @ObservedObject var controller: MotionController
    
    var body: some View {
        Text(controller.connected ? "Connected to Mac" : "Searching for Mac...")
            .padding()
            .background(controller.connected ? Color.green : Color.yellow)
            .cornerRadius(8)
    }
}
