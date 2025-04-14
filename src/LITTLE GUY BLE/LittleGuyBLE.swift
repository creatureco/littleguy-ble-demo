//
//  LittleGuyBLE.swift
//  LITTLE GUY BLE
//
//  Created by Daniel Kuntz on 4/13/25.
//

import Foundation
import CoreBluetooth
import Combine

class LittleGuyBLE: NSObject, ObservableObject {
    static let shared = LittleGuyBLE()

    @Published var connected: Bool = false

    private let deviceName = "LITTLE GUY"
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]

    private var discoveryCallback: ((Bool) -> Void)?
    private var writeCallback: ((Bool, Error?) -> Void)?

    private let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    private let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")

    private var lookDirectionSubject = PassthroughSubject<(Float, Float), Never>()
    private var lookDirectionCancellable: AnyCancellable?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        scanAndConnect()
        setupLookDirectionThrottling()
    }

    private func setupLookDirectionThrottling() {
        lookDirectionCancellable = lookDirectionSubject
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] direction in
                let (x, y) = direction
                self?.sendLookDirection(x: x, y: y)
            }
    }

    func setLookDirection(x: Float, y: Float, completion: ((Bool, Error?) -> Void)? = nil) {
        lookDirectionSubject.send((x, y))
    }

    private func sendLookDirection(x: Float, y: Float, completion: ((Bool, Error?) -> Void)? = nil) {
        let command = "SET_LOOK_DIRECTION:\(x):\(y)"
        sendCommandString(serviceUUID: serviceUUID,
                          characteristicUUID: characteristicUUID,
                          command: command,
                          completion: completion)
    }

    func transitionToState(_ state: String, completion: ((Bool, Error?) -> Void)? = nil) {
        let command = "SWITCH_STATE:\(state)"
        sendCommandString(serviceUUID: serviceUUID,
                          characteristicUUID: characteristicUUID,
                          command: command,
                          completion: completion)
    }

    private func scanAndConnect() {
        startScanning { deviceFound in
            if deviceFound {
                self.connect()
            }
        }
    }

    private func startScanning(completion: @escaping (Bool) -> Void) {
        discoveryCallback = completion

        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    private func connect() {
        if let peripheral = peripheral {
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
    }

    private func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    private func stopScanning() {
        centralManager.stopScan()
    }

    private func sendCommand(serviceUUID: CBUUID, characteristicUUID: CBUUID, data: Data, completion: ((Bool, Error?) -> Void)?) {
        writeCallback = completion

        guard let peripheral = peripheral, peripheral.state == .connected else {
            completion?(false, nil)
            return
        }

        if let characteristic = characteristics[characteristicUUID] {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } else {
            completion?(false, nil)
        }
    }

    private func sendCommandString(serviceUUID: CBUUID, characteristicUUID: CBUUID, command: String, completion: ((Bool, Error?) -> Void)?) {
        guard let data = command.data(using: .utf8) else {
            completion?(false, nil)
            return
        }

        sendCommand(serviceUUID: serviceUUID, characteristicUUID: characteristicUUID, data: data, completion: completion)
    }
}

extension LittleGuyBLE: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name, name == deviceName else { return }

        self.peripheral = peripheral
        self.stopScanning()
        self.discoveryCallback?(true)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
        self.connected = true
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.connected = false
        self.scanAndConnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.connected = false
        self.peripheral = nil
        self.scanAndConnect()
    }
}

extension LittleGuyBLE: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                self.characteristics[characteristic.uuid] = characteristic
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        writeCallback?(error == nil, error)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {}
}
