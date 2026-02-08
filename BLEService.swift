import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE Service Manager
final class BLEService: NSObject, ObservableObject {
    static let shared = BLEService()
    
    // Service/Characteristic UUIDs (match web app and Python server)
    static let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    static let charUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    
    // Published state
    @Published var peers: [BLEPeer] = []
    @Published var isScanning = false
    @Published var bluetoothState: CBManagerState = .unknown
    
    // Callbacks
    var onMessageReceived: ((String, String) -> Void)? // (peerName, rawData)
    var onLog: ((String, LogEntry.LogLevel) -> Void)?
    var onPeerConnected: ((String) -> Void)?
    var onPeerDisconnected: ((String) -> Void)?
    
    // Internal
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedCharacteristics: [String: CBCharacteristic] = [:] // peerUUID -> characteristic
    private var chunkBuffers: [String: (data: Data, timer: Timer?)] = [:]
    private let chunkTimeout: TimeInterval = 0.15
    
    // Peripheral mode (so other devices can discover us)
    private var advertisingCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Scanning
    func startScan() {
        guard centralManager.state == .poweredOn else {
            onLog?("Bluetooth not ready (state: \(centralManager.state.rawValue))", .warning)
            return
        }
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        // Also scan for all devices to find companions
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        onLog?("Scanning for nearby devices...", .info)
        
        // Auto-stop after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScan()
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
        isScanning = false
        onLog?("Scan stopped (\(peers.count) device\(peers.count == 1 ? "" : "s") found)", .info)
    }
    
    // MARK: - Connect / Disconnect
    func connect(peerId: String) {
        guard let peripheral = discoveredPeripherals[peerId] else {
            onLog?("Device not found", .error)
            return
        }
        onLog?("Connecting to \(peripheral.name ?? "device")...", .info)
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect(peerId: String) {
        guard let peripheral = discoveredPeripherals[peerId] else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        connectedCharacteristics.removeValue(forKey: peerId)
        updatePeer(id: peerId, connected: false)
        onLog?("Disconnected from \(peripheral.name ?? "device")", .warning)
        onPeerDisconnected?(peerName(for: peerId))
    }
    
    func disconnectAll() {
        for (id, peripheral) in discoveredPeripherals {
            if peripheral.state == .connected {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
        connectedCharacteristics.removeAll()
        peers = peers.map { var p = $0; p.connected = false; return p }
    }
    
    // MARK: - Send Data (broadcast to all connected peers)
    func broadcast(_ data: Data) {
        var sentCount = 0
        
        // Send via connected characteristics (central mode)
        for (peerId, characteristic) in connectedCharacteristics {
            guard let peripheral = discoveredPeripherals[peerId],
                  peripheral.state == .connected else { continue }
            
            // Try write without response first (faster), fall back to chunked
            if data.count <= 182 { // typical negotiated MTU
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
                sentCount += 1
            } else {
                // Chunk into 20-byte pieces for safety
                var offset = 0
                while offset < data.count {
                    let end = min(offset + 20, data.count)
                    let chunk = data.subdata(in: offset..<end)
                    peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
                    offset = end
                }
                sentCount += 1
            }
        }
        
        // Send via peripheral mode to subscribed centrals
        if let char = advertisingCharacteristic, !subscribedCentrals.isEmpty {
            peripheralManager.updateValue(data, for: char, onSubscribedCentrals: subscribedCentrals)
            sentCount += subscribedCentrals.count
        }
        
        if sentCount > 0 {
            onLog?("Sent \(data.count)B to \(sentCount) peer\(sentCount == 1 ? "" : "s")", .data)
        }
    }
    
    // MARK: - Advertising (peripheral mode)
    func startAdvertising(name: String) {
        guard peripheralManager.state == .poweredOn else { return }
        
        let characteristic = CBMutableCharacteristic(
            type: Self.charUUID,
            properties: [.read, .write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        advertisingCharacteristic = characteristic
        
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager.add(service)
        
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: name
        ])
        onLog?("Advertising as '\(name)' — other devices can find us", .success)
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        subscribedCentrals.removeAll()
    }
    
    // MARK: - Helpers
    private func peerName(for id: String) -> String {
        peers.first(where: { $0.id == id })?.name ?? "Unknown"
    }
    
    private func updatePeer(id: String, connected: Bool) {
        if let i = peers.firstIndex(where: { $0.id == id }) {
            peers[i].connected = connected
        }
    }
    
    private func handleIncomingData(_ data: Data, from peerId: String) {
        // Chunk reassembly — buffer data and flush after timeout
        if var existing = chunkBuffers[peerId] {
            existing.timer?.invalidate()
            existing.data.append(data)
            let timer = Timer.scheduledTimer(withTimeInterval: chunkTimeout, repeats: false) { [weak self] _ in
                self?.flushChunkBuffer(for: peerId)
            }
            chunkBuffers[peerId] = (existing.data, timer)
        } else {
            let timer = Timer.scheduledTimer(withTimeInterval: chunkTimeout, repeats: false) { [weak self] _ in
                self?.flushChunkBuffer(for: peerId)
            }
            chunkBuffers[peerId] = (data, timer)
        }
    }
    
    private func flushChunkBuffer(for peerId: String) {
        guard let buffer = chunkBuffers.removeValue(forKey: peerId) else { return }
        buffer.timer?.invalidate()
        let raw = String(data: buffer.data, encoding: .utf8) ?? ""
        if !raw.isEmpty {
            let name = peerName(for: peerId)
            onMessageReceived?(name, raw)
        }
    }
    
    var connectedCount: Int {
        peers.filter(\.connected).count + subscribedCentrals.count
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        switch central.state {
        case .poweredOn:
            onLog?("Bluetooth ready", .success)
        case .poweredOff:
            onLog?("Bluetooth is off — enable it in Settings", .error)
        case .unauthorized:
            onLog?("Bluetooth permission denied — check Settings > Privacy", .error)
        case .unsupported:
            onLog?("Bluetooth LE not supported on this device", .error)
        default:
            onLog?("Bluetooth state: \(central.state.rawValue)", .info)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Device-\(id.prefix(8))"
        
        discoveredPeripherals[id] = peripheral
        
        if let i = peers.firstIndex(where: { $0.id == id }) {
            peers[i].rssi = RSSI.intValue
            peers[i].lastSeen = Date()
            if peers[i].name.hasPrefix("Device-") && !name.hasPrefix("Device-") {
                peers[i].name = name
            }
        } else {
            peers.append(BLEPeer(id: id, name: name, connected: false, rssi: RSSI.intValue, lastSeen: Date()))
            onLog?("Found: \(name) (RSSI: \(RSSI.intValue)dBm)", .success)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        updatePeer(id: id, connected: true)
        onLog?("Connected to \(peripheral.name ?? "device")", .success)
        onPeerConnected?(peerName(for: id))
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onLog?("Failed to connect: \(error?.localizedDescription ?? "unknown")", .error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        let name = peerName(for: id)
        connectedCharacteristics.removeValue(forKey: id)
        updatePeer(id: id, connected: false)
        onLog?("\(name) disconnected\(error != nil ? ": \(error!.localizedDescription)" : "")", .warning)
        onPeerDisconnected?(name)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([Self.charUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        let id = peripheral.identifier.uuidString
        for char in characteristics where char.uuid == Self.charUUID {
            connectedCharacteristics[id] = char
            peripheral.setNotifyValue(true, for: char)
            onLog?("Chat channel ready with \(peerName(for: id))", .success)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, error == nil else { return }
        let id = peripheral.identifier.uuidString
        handleIncomingData(data, from: id)
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            onLog?("Peripheral manager ready", .info)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
            onLog?("Remote device subscribed to notifications", .success)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll(where: { $0.identifier == central.identifier })
        onLog?("Remote device unsubscribed", .warning)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                handleIncomingData(data, from: request.central.identifier.uuidString)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
