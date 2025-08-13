import SwiftUI

class WebSocketStreamer: ObservableObject{
  private var websocketTask: URLSessionWebSocketTask?
  private var timer: Timer?
  private let session = URLSession(configuration: .default)
  @Published var isConnected = false
  func connect(to urlString: String){
    guard let url = URL(string: urlString) else{
      print("Please enter a valid url ")
      return
    }
    websocketTask = session.webSocketTask(with: url)
    websocketTask?.resume()
    isConnected = true
    print("Websocket is connected to: \(urlString)")
    sendString("Hello from iOS iPad testing now")
  }
  
  func disconnect()
  {
    timer?.invalidate()
    timer = nil
    websocketTask?.cancel(with: .goingAway, reason: nil)
    websocketTask = nil
    isConnected = false
  }

  func sendString(_ text: String){
    guard isConnected else { print("WebSocket not connected"); return }
    let message = URLSessionWebSocketTask.Message.string(text)
    websocketTask?.send(message){ error in
      if let error = error {
        print("WebSocket send error: \(error)")
      } else {
        print("Sent string: \(text)")
      }
    }
  }
  // MARK: - Mesh sending
  func sendMeshData(_ mesh: MeshData){
    guard isConnected else { print("WebSocket not connected"); return }
    let envelope: [String: Any] = [
      "type": "mesh_data",
      "data": [
        "id": mesh.id,
        "vertices": mesh.vertices,
        "faces": mesh.faces,
        "transform": mesh.transform,
        "timestamp": mesh.timestamp
      ]
    ]
    if let data = try? JSONSerialization.data(withJSONObject: envelope),
       let json = String(data: data, encoding: .utf8){
      sendString(json)
    }
  }
}