//
//  Capture3DScanView.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 27/04/25.
//

import SwiftUI

struct Capture3DScanView: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>
    @State var submittedExportRequest = false
    @State var submittedName = ""
    @State var pauseSession: Bool = false
    @State var showingExportAlert = false
    @State var tempFileName = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // AR View as background
            ARWrapperView(submittedExportRequest: $submittedExportRequest,
                        submittedName: $submittedName,
                        pauseSession: $pauseSession)
            .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                HStack {
                    Button {
                        self.mode.wrappedValue.dismiss()
                    } label: {
                        Text("Back")
                            .frame(width: 80)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .frame(width: 40, height: 40)
                    Spacer()
                }.padding(.leading, 40)
                Spacer()
                Button {
                    pauseSession = true
                    showingExportAlert = true
                } label: {
                    Text("Export")
                        .frame(width: UIScreen.main.bounds.width-120)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .onAppear {
            print("Capture3DScanView appeared")
        }
        .alert("Save File", isPresented: $showingExportAlert) {
            TextField("File name", text: $tempFileName)
                .foregroundColor(.white)
            Button("Cancel") {
                pauseSession = false
                tempFileName = ""
            }
            Button("Save") {
                print("Export button pressed with filename: \(tempFileName)")
                submittedName = tempFileName
                submittedExportRequest.toggle()
                print("Export request set to: \(submittedExportRequest)")
                
                // Reset the export request after a short delay to allow processing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    submittedExportRequest = false
                    print("Export request reset")
                }
                
                tempFileName = ""
                self.mode.wrappedValue.dismiss()
            }
        } message: {
            Text("Enter your file name")
        }
    }
}

#Preview {
    Capture3DScanView()
}
