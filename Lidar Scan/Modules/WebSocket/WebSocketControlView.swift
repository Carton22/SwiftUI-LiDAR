//
//  WebSocketControlView.swift
//  Lidar Scan

import SwiftUI

struct WebSocketControlView: View {
	@Environment(\.dismiss) private var dismiss
	@StateObject private var streamer = WebSocketStreamer()
	@State private var urlString: String = "ws://10.131.229.175:3001"
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: Text("Server")) {
					TextField("ws://host:port", text: $urlString)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled(true)
				}
				
				Section(header: Text("Connection"), footer: Text(statusFooter)) {
					HStack {
						Circle()
							.fill(streamer.isConnected ? Color.green : Color.red)
							.frame(width: 10, height: 10)
						Text(streamer.isConnected ? "Connected" : "Disconnected")
						Spacer()
						if streamer.isConnected {
							Button(role: .destructive) {
								streamer.disconnect()
							} label: {
								Label("Disconnect", systemImage: "wifi.slash")
							}
						} else {
							Button {
								streamer.connect(to: urlString)
							} label: {
								Label("Connect", systemImage: "wifi")
							}
						}
					}
				}
			}
			.navigationTitle("WebSocket")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { dismiss() }
				}
			}
		}
	}
	
	private var statusFooter: String {
		streamer.isConnected ? "Connected to \(urlString)" : "Enter server URL and tap Connect"
	}
}

#Preview {
	WebSocketControlView()
}
