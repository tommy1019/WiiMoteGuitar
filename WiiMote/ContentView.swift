import SwiftUI

struct ContentView: View {
    
    @ObservedObject var connectionManager : WiiMoteConntectionManager
    
    func handleDrop(providers : [NSItemProvider]) -> Bool {
        providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
            if let data = data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                do {
                    print("Loading \(path)")
                    let lines = try String(contentsOf: url).split(separator: "\n")
                    
                    connectionManager.mapping.removeAll()
                    
                    for line in lines {
                        if line.trimmingCharacters(in: .whitespaces) == "" {
                            continue
                        }
                        
                        let components = line.split(separator: ",")
                        
                        if components.count != 11 {
                            print("Error: Incorrect number of components for \(components[0])")
                            continue
                        }
                        
                        let addrHash = components[0].trimmingCharacters(in: .whitespaces).hash
                        var mapping : [UInt16] = []
                        
                        for i in 1 ... 10 {
                            guard let value = UInt16(components[i].trimmingCharacters(in: .whitespaces).dropFirst(2), radix: 16) else {
                                print("Incorrectly formatted integer: \(components[i])")
                                return
                            }
                            mapping.append(value)
                        }
                        
                        connectionManager.mapping[addrHash] = mapping
                    }
                    
                    print(connectionManager.mapping)
                } catch {
                    print("Error loading file")
                }
            }
        })
        return true
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: {
                    connectionManager.scan()
                }, label: {
                    Text("Start Scanning")
                })
                .disabled(connectionManager.isScanning)
                
                Spacer()
                
                Button(action: {
                    
                }, label: {
                    Text("Load Config File")
                })
                .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop)
                .disabled(connectionManager.isScanning)
                
                Spacer()
                
                Toggle("Is Sending Keys", isOn: $connectionManager.isSendingKeys)
                
                Spacer()
                
                Button (action: {
                }, label: {
                    Text("Test")
                })

            }
            .padding()
            List() {
                ForEach(connectionManager.connectedRemotes) { (remote) in
                    WiiRemoteView(connectionManager: connectionManager, remote: remote)
                }
            }
        }
    }
}

struct WiiRemoteView : View {
    @ObservedObject var connectionManager : WiiMoteConntectionManager
    @ObservedObject var remote : ConnectedWiiRemote
    
    @State var led1 = true
    @State var led2 = true
    @State var led3 = true
    @State var led4 = true
    
    @State var rumble = false
    
    var body: some View {
        HStack {
            Text("\(remote.device?.addressString ?? "00:00:00:00")")
                .font(.largeTitle)
            
            HStack {
                Toggle(isOn: $led1) {
                    Text("Led1")
                }
                .onReceive([self.led1].publisher.first(), perform: { _ in
                    remote.updateLEDs(led1, led2, led3, led4)
                })
                
                Toggle(isOn: $led2) {
                    Text("Led2")
                }
                .onReceive([self.led2].publisher.first(), perform: { _ in
                    remote.updateLEDs(led1, led2, led3, led4)
                })
                
                Toggle(isOn: $led3) {
                    Text("Led3")
                }
                .onReceive([self.led3].publisher.first(), perform: { _ in
                    remote.updateLEDs(led1, led2, led3, led4)
                })
                
                Toggle(isOn: $led4) {
                    Text("Led4")
                }
                .onReceive([self.led4].publisher.first(), perform: { _ in
                    remote.updateLEDs(led1, led2, led3, led4)
                })
            }
            .labelsHidden()
            
            Toggle(isOn: $rumble) {
                Text("Rumble")
            }
            .onReceive([self.rumble].publisher.first(), perform: { _ in
                remote.updateRumble(rumble)
            })
            
            if remote.hasExtension {
                Image(systemName: "rectangle.connected.to.line.below")
            }
            
            Button(action: {
                remote.device.closeConnection()
                connectionManager.connectedRemotes = connectionManager.connectedRemotes.filter({ (i) -> Bool in
                    return i.id != remote.id
                })
            }, label: {
                Text("Disconnect")
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let testConectionManager = WiiMoteConntectionManager()
        
        return ContentView(connectionManager: testConectionManager)
    }
}
