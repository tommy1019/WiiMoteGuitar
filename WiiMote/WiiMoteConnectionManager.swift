import Foundation
import IOBluetooth

class WiiMoteConntectionManager: NSObject, ObservableObject {

    @Published var isScanning = false
    @Published var isSendingKeys = false
    
    @Published var connectedRemotes : [ConnectedWiiRemote] = []
    
    var mapping : [Int : [UInt16]] = [:]
    
    override init() {
        super.init()
        
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(onConnectRequest))
    }
    
    @objc func onConnectRequest(notification : IOBluetoothUserNotification, device : IOBluetoothDevice) {
        if device.isConnected() {
            return
        }
        
        onRequest(device: device)
    }
    
    func scan() {
        isScanning = true

        guard let deviceInquity = IOBluetoothDeviceInquiry(delegate: self) else {
            print("Error: Could not start scan for devices")
            isScanning = false
            
            return
        }

        deviceInquity.start()
    }
    
    func onRequest(device : IOBluetoothDevice) {
        print("Device Request: \(device.name ?? "nil") - \(device.deviceClassMajor).\(device.deviceClassMinor)")
        
        if device.name == nil {
            device.remoteNameRequest(self)
            return
        }
        
        if !device.name.lowercased().contains("nintendo") {
            print("Ignoringing non nintendo device")
            return
        }
        
        guard let newRemote = ConnectedWiiRemote(manager: self, device: device) else {
            return
        }
        connectedRemotes.append(newRemote)
        
//        if device.isPaired() {
//            onPair(device: device)
//        } else {
//            guard let pair = IOBluetoothDevicePair(device: device) else {
//                print("Failed to pair to WiiRemote")
//                return
//            }
//            pair.delegate = self
//            pair.start()
//        }
    }
    
    func onPair(device : IOBluetoothDevice) {
        print("Device Paired")
        
        guard let newRemote = ConnectedWiiRemote(manager: self, device: device) else {
            return
        }
        
        connectedRemotes.append(newRemote)
    }
    
    func remoteNameRequestComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        print("Got name \(status)")
        
        onRequest(device: device)
    }
    
    func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        print("Connection complete")
    }
}

extension WiiMoteConntectionManager : IOBluetoothDeviceInquiryDelegate {
    func deviceInquiryStarted(_ sender: IOBluetoothDeviceInquiry!) {
        
    }
    
    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        isScanning = false
    }
    
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        onRequest(device: device)
    }
}

extension WiiMoteConntectionManager : IOBluetoothDevicePairDelegate {
    func devicePairingPINCodeRequest(_ sender: Any!) {
        print("Replying PIN code")
        let pair = sender as! IOBluetoothDevicePair
        
        guard let address = pair.device()?.getAddress()?.pointee else { return }
        
        var pin = BluetoothPINCode(data: (address.data.5, address.data.4, address.data.3, address.data.2, address.data.1, address.data.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

        pair.replyPINCode(6, pinCode: &pin)
    }
    
    func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        let pair = sender as! IOBluetoothDevicePair
        
        if error != 0 {
            print("Failed to pair device: \(error)")
            pair.device()?.closeConnection()
            return
        }
        
        onPair(device: pair.device())
    }

}
