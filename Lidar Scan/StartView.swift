//
//  StartView.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 27/04/25.
//

import SwiftUI
import ARKit

struct StartView: View {
    @State var shouldNavigateToScanView: Bool = false
    @State var shouldNavigateToViewList: Bool = false
    @State private var showingWebSocketSheet: Bool = false
    func isLidarCapable() -> Bool {
        let supportLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        guard supportLiDAR else {
            print("LiDAR isn't supported here")
            return false
        }
        return true
    }
    var body: some View {
        NavigationStack {
            if  isLidarCapable() {
                VStack {
                    // Open WebSocket control panel
                    Button {
                        shouldNavigateToScanView = false
                        shouldNavigateToViewList = false
                        showingWebSocketSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("WebSocket Control")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button {
                        shouldNavigateToScanView = true
                    } label: {
                        Text("Capture 3D Scan")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Button {
                        shouldNavigateToViewList = true
                    } label: {
                        Text("View 3D Scans")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .navigationDestination(isPresented: $shouldNavigateToViewList) {
                    View3DScansView().navigationBarHidden(true)
                }
            } else {
                VStack(alignment: .center) {
                    Text("This Device is not capable of a 3D scan, as it is missing the Lidar Sensor.")
                        .multilineTextAlignment(.center)
                }
            }
        }
        .fullScreenCover(isPresented: $shouldNavigateToScanView) {
            Capture3DScanView()
        }
        .sheet(isPresented: $showingWebSocketSheet) {
            WebSocketControlView()
        }
    }
}

#Preview {
    StartView()
}
