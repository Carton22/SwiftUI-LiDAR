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
        
        // Set up session delegate for mesh geometry logging
        arView.session.delegate = context.coordinator
        
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
    
    // Add coordinator for mesh geometry logging
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

// MARK: - Coordinator for Mesh Geometry Logging
class Coordinator: NSObject, ARSessionDelegate {
    
    // Called whenever new mesh anchors are created or updated
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                printMeshGeometryInfo(meshAnchor: meshAnchor, event: "NEW MESH CREATED")
            }
        }
    }
    
    // Called whenever existing mesh anchors are updated
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                printMeshGeometryInfo(meshAnchor: meshAnchor, event: "MESH UPDATED")
            }
        }
    }
    
    private func printMeshGeometryInfo(meshAnchor: ARMeshAnchor, event: String) {
        let geometry = meshAnchor.geometry
        let uuid = meshAnchor.identifier.uuidString
        
        print("=== \(event) ===")
        print("Mesh UUID: \(uuid)")
        print("Vertices count: \(geometry.vertices.count)")
        print("Faces count: \(geometry.faces.count)")
        print("Normals count: \(geometry.normals.count)")
        
        // Print first few vertices for reference
        if geometry.vertices.count > 0 {
            let firstVertex = geometry.vertex(at: 0)
            print(firstVertex)
            print("First vertex: x=\(firstVertex.x), y=\(firstVertex.y), z=\(firstVertex.z)")
        }
        
        // Print first few faces for reference
        if geometry.faces.count > 0 {
            let firstFace = geometry.faces[0]
            print("First face indices: \(firstFace.indices[0]), \(firstFace.indices[1]), \(firstFace.indices[2])")
        }
        
        if geometry.normals.count > 0 {
            print("First few normals:")
            let normalCount = min(3, geometry.normals.count) // Print first 3 normals
            let nx = geometry.normals[0].0
            let ny = geometry.normals[0].1
            let nz = geometry.normals[0].2
            print("Normal x=\(nx), y=\(ny), z=\(nz)")
        }
        
        print("Transform matrix:")
        let transform = meshAnchor.transform
        print("  Position: x=\(transform[0][0]), y=\(transform[0][1]), z=\(transform[0][2])")
        print("==================")
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
