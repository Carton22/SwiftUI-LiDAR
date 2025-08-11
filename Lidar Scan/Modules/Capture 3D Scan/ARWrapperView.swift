//
//  ARWrapperView.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 27/04/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ARWrapperView: UIViewRepresentable {
    @Binding var submittedExportRequest: Bool
    @Binding var submittedName: String
    @Binding var pauseSession: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        
        // Configure AR view options
        setARViewOptions(arView)
        
        // Build and run configuration immediately
        let configuration = buildConfigure()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("ARView created and session started")
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Handle export request
        if submittedExportRequest {
            print("Export request received for file: \(submittedName)")
            handleExportRequest(arView: uiView)
        }
        
        // Handle session pause/resume
        if pauseSession {
            uiView.session.pause()
            print("AR Session paused")
        } else {
            // Only restart if not already running by checking if we have a current frame
            if uiView.session.currentFrame == nil {
                let configuration = buildConfigure()
                uiView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                print("AR Session restarted")
            }
        }
    }
    
    private func handleExportRequest(arView: ARView) {
        print("Processing export request...")
        
        guard let camera = arView.session.currentFrame?.camera else { 
            print("No camera frame available for export")
            return 
        }
        
        print("Camera frame available, checking for mesh anchors...")
        
        let meshAnchors = arView.session.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor } ?? []
        print("Found \(meshAnchors.count) mesh anchors")
        
        if meshAnchors.isEmpty {
            print("No mesh anchors found for export")
            return
        }
        
        let viewModel = ExportViewModel()
        if let asset = viewModel.convertToAsset(meshAnchor: meshAnchors, camera: camera) {
            print("Asset created successfully, attempting export...")
            do {
                try viewModel.export(asset: asset, fileName: submittedName)
                print("Export completed successfully!")
            } catch {
                print("Export Failed: \(error)")
            }
        } else {
            print("Failed to create asset from mesh anchors")
        }
    }
    
    private func buildConfigure() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        configuration.sceneReconstruction = .meshWithClassification
        
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        
        print("AR Configuration created: \(configuration)")
        return configuration
    }
    
    private func setARViewOptions(_ arView: ARView) {
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.debugOptions.insert(.showWorldOrigin)
        
        // Enable camera feed visibility
        arView.isOpaque = false
        arView.backgroundColor = .clear
        
        print("AR View options configured")
    }
}

class ExportViewModel: NSObject, ObservableObject, ARSessionDelegate {
    func convertToAsset(meshAnchor: [ARMeshAnchor], camera: ARCamera) -> MDLAsset? {
        guard let device = MTLCreateSystemDefaultDevice() else { 
            print("Failed to create MTL device")
            return nil
        }
        let asset = MDLAsset()
        for anchor in meshAnchor {
            let mdlMesh = anchor.geometry.toMDLMesh(device: device, camera: camera, modelMatrix: anchor.transform)
            asset.add(mdlMesh)
        }
        return asset
    }
    
    func export(asset: MDLAsset, fileName: String) throws {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "com.original.creatingLidarModel", code: 153)
        }
        let folderName = "OBJ_FILES"
        let folderURL = directory.appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        let url = folderURL.appendingPathComponent("\(fileName.isEmpty ? UUID().uuidString : fileName).obj")
        do {
            try asset.export(to: url)
            print("Object saved successfully at \(url)")
        } catch {
            print("Export error: \(error)")
        }
    }
}
