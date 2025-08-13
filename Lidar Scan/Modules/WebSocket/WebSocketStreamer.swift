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
    startStreaming()
  }
  func disconnect()
  {
    timer?.invalidate()
    timer = nil
    websocketTask?.cancel(with: .goingAway, reason: nil)
    websocketTask = nil
    isConnected = false
  }
  func startStreaming()
  {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true){ _ in
      self.sendTestMessage()
    }
  }
  // MARK: - Testing helpers
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
  func sendTestMessage(){
    let payload: [String: Any] = [
      "type": "test",
      "message": "Hello from iOS (fake message)",
      "timestamp": Date().timeIntervalSince1970
    ]
    if let data = try? JSONSerialization.data(withJSONObject: payload),
       let json = String(data: data, encoding: .utf8){
      sendString(json)
    }
  }
}