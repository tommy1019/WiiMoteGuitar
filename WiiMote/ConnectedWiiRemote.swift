import Foundation
import IOBluetooth
import Combine

import IOKit

class ConnectedWiiRemote : ObservableObject, Identifiable {
    
    @Published var isConnected = false
    @Published var hasExtension = false
    @Published var lowBattery = false
    @Published var batteryLevel = 0
    
    var isInitExtension = false
    
    let connectionManager : WiiMoteConntectionManager
    
    let device : IOBluetoothDevice!
    
    var controlPipe : IOBluetoothL2CAPChannel! = IOBluetoothL2CAPChannel()
    var dataPipe : IOBluetoothL2CAPChannel! = IOBluetoothL2CAPChannel()
    
    var rumble = false
    
    var addrHash : Int = -1
    
    var guitarData : GuitarData = GuitarData(
        whammyBar: false,
        plus: false,
        minus: false,
        strumUp: false,
        strumDown: false,
        fretGreen: false,
        fretRed: false,
        fretYellow: false,
        fretBlue: false,
        fretOrange: false
    )
    
    init?(manager : WiiMoteConntectionManager, device : IOBluetoothDevice) {
        self.connectionManager = manager
        self.device = device
        
        addrHash = device.addressString.hash
        
        print("Adding Wii Remote: \(device.addressString ?? "NO_ADDRESS")")
        
        print("Connected: \(device.isConnected() ? "true" : "false")")
        
        if !device.isConnected() {
            if device.openConnection() != 0 {
                print("Error: Could not connect to BT Device")
                device.closeConnection()
                return nil
            }
        }
        
        if device.openL2CAPChannelSync(&self.controlPipe, withPSM: BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDControl), delegate: self) != 0 {
            print("Error: Could not open control pipe")
            device.closeConnection()
            return nil
        }
        if device.openL2CAPChannelSync(&self.dataPipe, withPSM: BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDInterrupt), delegate: self) != 0 {
            print("Error: Could not open data pipe")
            device.closeConnection()
            return nil
        }
        
        sendData(data: [0xa2, 0x11, 0xF0], channel: self.dataPipe)
        
        isConnected = true
    }
    
    @objc func onOpenChannel(notif : IOBluetoothUserNotification, connection : IOBluetoothL2CAPChannel) {
        print("Channel opened on \(connection.psm)")
        
        if connection.psm == kBluetoothL2CAPPSMHIDControl {
            controlPipe = connection
            controlPipe.setDelegate(self)
        } else if connection.psm == kBluetoothL2CAPPSMHIDInterrupt {
            dataPipe = connection
            dataPipe.setDelegate(self)
        }
    }
    
    func updateLEDs(_ led1 : Bool, _ led2 : Bool, _ led3 : Bool, _ led4 : Bool) {
        let ledStatus : UInt8 =
        (led1 ? 0x10 : 0) |
        (led2 ? 0x20 : 0) |
        (led3 ? 0x40 : 0) |
        (led4 ? 0x80 : 0) |
        (rumble ? 1 : 0)
                
        sendData(data: [0xa2, 0x11, ledStatus], channel: self.dataPipe)
    }
    
    func updateRumble(_ rumble : Bool) {
        self.rumble = rumble
        sendData(data: [0xa2, 0x10, rumble ? 1 : 0], channel: self.dataPipe)
    }
    
    func sendData(data : [UInt8], channel : IOBluetoothL2CAPChannel) {
        var outData = Data(data)
        outData.withUnsafeMutableBytes { (ptr) in
            _ = channel.writeAsync(ptr.baseAddress, length: UInt16(data.count), refcon: nil)
        }
    }
}

extension Data {
    var hexDescription: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}

extension ConnectedWiiRemote : IOBluetoothL2CAPChannelDelegate {
    func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status error: IOReturn) {
        
    }
    
    func l2capChannelClosed(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        print("Channel \(l2capChannel.psm) closed")
        
        controlPipe.close()
        dataPipe.close()
        device.closeConnection()
        
        connectionManager.connectedRemotes.removeAll { (i) -> Bool in
            return i.id == self.id
        }
    }
    
    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytesNoCopy: dataPointer, count: dataLength, deallocator: .none)
        //print("Got Data(\(l2capChannel.psm)): \(data.hexDescription)")
        
        let messageType = data[1]
        
        if messageType == 0x20 {
            lowBattery = (data[4] & 0x01) > 0
            
            let hasExtPrev = hasExtension
            hasExtension = (data[4] & 0x02) > 0
            
            batteryLevel = Int(data[7])
            
            if !hasExtPrev && hasExtension {
                //Write first part of extension init
                isInitExtension = true
                sendData(data: [0xa2, 0x16, 0x04, 0xA4, 0x00, 0xF0, 0x01, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], channel: self.dataPipe)
            }
            
            if !hasExtension {
                sendData(data: [0xa2, 0x12, 0x00, 0x30], channel: self.dataPipe)
            }
        } else if messageType == 0x22 {
            print("Ack Result \(String(format: "%02X", data[4])) - \(String(format: "%02X", data[5])) ")
            
            if isInitExtension {
                //Write second part of extension init
                isInitExtension = false
                sendData(data: [0xa2, 0x16, 0x04, 0xA4, 0x00, 0xFB, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], channel: self.dataPipe)
            } else {
                //Start data reporting
                sendData(data: [0xa2, 0x12, 0x00, 0x32], channel: self.dataPipe)
            }
            
        } else if messageType == 0x32 {
            if hasExtension {
                
                if !connectionManager.isSendingKeys {
                    return
                }
                
                let newGuitarData = GuitarData(
                    whammyBar:      UInt8(data[7] & 0b00011111) > 20,
                    plus:           (data[8] & 0b00010000) == 0,
                    minus:          (data[8] & 0b00000100) == 0,
                    strumUp:        (data[9] & 0b00000001) == 0,
                    strumDown:      (data[8] & 0b01000000) == 0,
                    fretGreen:      (data[9] & 0b00010000) == 0,
                    fretRed:        (data[9] & 0b01000000) == 0,
                    fretYellow:     (data[9] & 0b00001000) == 0,
                    fretBlue:       (data[9] & 0b00100000) == 0,
                    fretOrange:     (data[9] & 0b10000000) == 0
                )
                
                //print("Guitar Status: (\(newGuitarData.strumUp ? "U" : (newGuitarData.strumDown ? "D" : "N"))) - Whammy(\(newGuitarData.whammyBar ? "W" : "w")) - \(newGuitarData.fretGreen ? "G" : "_")\(newGuitarData.fretRed ? "R" : "_")\(newGuitarData.fretYellow ? "Y" : "_")\(newGuitarData.fretBlue ? "B" : "_")\(newGuitarData.fretOrange ? "O" : "_") - (+:\(newGuitarData.plus ? "X" : " "), -:\(newGuitarData.minus ? "X" : " ")) - rawWhammy: \(UInt8(data[7]))")
                
                func sendKeypress(key : CGKeyCode, down : Bool) {
                    let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down);
                    event?.post(tap: .cghidEventTap)
                }
                
                func check(old : Bool, new : Bool, key : Int) {
                    if old != new {
                        if let key = connectionManager.mapping[addrHash]?[key] {
                            sendKeypress(key: key, down: new)
                        }
                    }
                }
                
                check(old: guitarData.fretGreen, new: newGuitarData.fretGreen, key: 0)
                check(old: guitarData.fretRed, new: newGuitarData.fretRed, key: 1)
                check(old: guitarData.fretYellow, new: newGuitarData.fretYellow, key: 2)
                check(old: guitarData.fretBlue, new: newGuitarData.fretBlue, key: 3)
                check(old: guitarData.fretOrange, new: newGuitarData.fretOrange, key: 4)
                
                check(old: guitarData.strumUp, new: newGuitarData.strumUp, key: 5)
                check(old: guitarData.strumDown, new: newGuitarData.strumDown, key: 6)
                
                check(old: guitarData.plus, new: newGuitarData.plus, key: 7)
                check(old: guitarData.minus, new: newGuitarData.minus, key: 8)
                
                check(old: guitarData.whammyBar, new: newGuitarData.whammyBar, key: 9)
                
                guitarData = newGuitarData
            }
        }
    }
}

struct GuitarData {
    let whammyBar : Bool
    
    let plus : Bool
    let minus : Bool
    
    let strumUp : Bool
    let strumDown : Bool
    
    let fretGreen : Bool
    let fretRed : Bool
    let fretYellow : Bool
    let fretBlue : Bool
    let fretOrange : Bool
}
