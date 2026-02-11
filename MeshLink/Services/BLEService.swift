import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE Service Manager v3.1
final class BLEService: NSObject, ObservableObject {
    static let shared = BLEService()
    
    static let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    static let charUUID    = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    static let restorationId = "com.meshlink.central"
    static let peripheralRestorationId = "com.meshlink.peripheral"
    
    // Published state
    @Published var peers: [BLEPeer] = []
    @Published var isScanning = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var showMeshLinkOnly = false
    
    // Callbacks
    var onMessageReceived: ((String, String) -> Void)?
    var onLog: ((String, LogEntry.LogLevel) -> Void)?
    var onPeerConnected: ((String) -> Void)?
    var onPeerDisconnected: ((String) -> Void)?
    
    // Internal
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedCharacteristics: [String: CBCharacteristic] = [:]
    private var connectionTimers: [String: Timer] = [:]
    
    // Chunk reassembly
    private var chunkBuffers: [String: (data: Data, timer: Timer?)] = [:]
    private let chunkTimeout: TimeInterval = 0.15
    
    // Large message chunked reassembly (sequence-based)
    private var messageChunkBuffers: [String: [Int: String]] = [:]
    private var messageChunkExpected: [String: Int] = [:]
    private var messageChunkTimers: [String: Timer] = [:]
    
    // Mesh relay
    private var seenMessageIds: Set<String> = []
    private let maxSeenIds = 500
    
    // Auto-reconnect
    private var knownPeerUUIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "knownPeers") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "knownPeers") }
    }
    private var reconnectTimer: Timer?
    
    // Peripheral mode
    private var advertisingCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []
    
    // Track which peers are MeshLink
    private var meshLinkPeerIds: Set<String> = []
    
    // FIX: Retry advertising when peripheral powers on after app launch
    private var pendingAdvertisingName: String?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self, queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restorationId]
        )
        peripheralManager = CBPeripheralManager(
            delegate: self, queue: .main,
            options: [CBPeripheralManagerOptionRestoreIdentifierKey: Self.peripheralRestorationId]
        )
    }
    
    // MARK: - Scanning
    func startScan() {
        guard centralManager.state == .poweredOn else {
            onLog?("Bluetooth not ready", .warning)
            return
        }
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        onLog?("Scanning for devices...", .info)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.stopScan()
        }
    }
    
    func stopScan() {
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
        let meshCount = peers.filter(\.isMeshLink).count
        onLog?("Scan done: \(peers.count) devices (\(meshCount) MeshLink)", .info)
    }
    
    // MARK: - Filtered peers list
    var filteredPeers: [BLEPeer] {
        if showMeshLinkOnly {
            return peers.filter { $0.isMeshLink || $0.connected }
        }
        return peers.sorted { a, b in
            if a.isMeshLink != b.isMeshLink { return a.isMeshLink }
            if a.connected != b.connected { return a.connected }
            return a.rssi > b.rssi
        }
    }
    
    // MARK: - Connect / Disconnect
    func connect(peerId: String) {
        guard let peripheral = discoveredPeripherals[peerId] else {
            onLog?("Device not found", .error); return
        }
        guard peripheral.state != .connected && peripheral.state != .connecting else {
            onLog?("Already connected/connecting", .warning); return
        }
        // Fix #11: Mark as connecting (shows spinner on peer card)
        updatePeer(id: peerId, connected: false, connecting: true)
        onLog?("Connecting to \(peripheral.name ?? "device")...", .info)
        peripheral.delegate = self
        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
        // 10s timeout
        connectionTimers[peerId]?.invalidate()
        connectionTimers[peerId] = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self, let p = self.discoveredPeripherals[peerId], p.state != .connected else { return }
            self.centralManager.cancelPeripheralConnection(p)
            self.onLog?("Connection timed out", .warning)
            self.updatePeer(id: peerId, connected: false, connecting: false)
            self.connectionTimers.removeValue(forKey: peerId)
        }
    }
    
    func disconnect(peerId: String) {
        guard let peripheral = discoveredPeripherals[peerId] else { return }
        cleanup(peerId: peerId)
        centralManager.cancelPeripheralConnection(peripheral)
        updatePeer(id: peerId, connected: false, connecting: false)
        var known = knownPeerUUIDs; known.remove(peerId); knownPeerUUIDs = known
        onLog?("Disconnected from \(peerName(for: peerId))", .warning)
        onPeerDisconnected?(peerName(for: peerId))
    }
    
    func disconnectAll() {
        for (id, peripheral) in discoveredPeripherals where peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
            cleanup(peerId: id)
        }
        connectedCharacteristics.removeAll()
        peers = peers.map { var p = $0; p.connected = false; p.connecting = false; return p }
        knownPeerUUIDs = []
    }
    
    private func cleanup(peerId: String) {
        connectionTimers[peerId]?.invalidate()
        connectionTimers.removeValue(forKey: peerId)
        connectedCharacteristics.removeValue(forKey: peerId)
        chunkBuffers[peerId]?.timer?.invalidate()
        chunkBuffers.removeValue(forKey: peerId)
    }
    
    // MARK: - Auto-Reconnect
    func startAutoReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.attemptReconnect()
        }
    }
    
    private func attemptReconnect() {
        guard centralManager.state == .poweredOn else { return }
        for uuid in knownPeerUUIDs {
            if let peripheral = discoveredPeripherals[uuid],
               peripheral.state == .disconnected,
               meshLinkPeerIds.contains(uuid) {
                onLog?("Auto-reconnecting to \(peerName(for: uuid))...", .info)
                connect(peerId: uuid)
            }
        }
    }
    
    // MARK: - Send (with chunking for large messages)
    func broadcast(_ data: Data, excludePeerId: String? = nil) {
        var sentCount = 0
        if data.count > 180 {
            broadcastChunked(data, excludePeerId: excludePeerId)
            return
        }
        for (peerId, characteristic) in connectedCharacteristics {
            if peerId == excludePeerId { continue }
            guard let peripheral = discoveredPeripherals[peerId], peripheral.state == .connected else { continue }
            let maxLen = max(20, peripheral.maximumWriteValueLength(for: .withoutResponse) - 3)
            if data.count <= maxLen {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            } else {
                var offset = 0
                while offset < data.count {
                    let end = min(offset + 20, data.count)
                    peripheral.writeValue(data.subdata(in: offset..<end), for: characteristic, type: .withoutResponse)
                    offset = end
                }
            }
            sentCount += 1
        }
        if let char = advertisingCharacteristic, !subscribedCentrals.isEmpty {
            peripheralManager.updateValue(data, for: char, onSubscribedCentrals: subscribedCentrals)
            sentCount += subscribedCentrals.count
        }
        if sentCount > 0 {
            onLog?("Sent \(data.count)B → \(sentCount) peer\(sentCount == 1 ? "" : "s")", .data)
        }
    }
    
    private func broadcastChunked(_ data: Data, excludePeerId: String? = nil) {
        let chunkSize = 160
        let b64 = data.base64EncodedString()
        let msgId = UUID().uuidString
        let total = Int(ceil(Double(b64.count) / Double(chunkSize)))
        
        for seq in 0..<total {
            let start = b64.index(b64.startIndex, offsetBy: seq * chunkSize)
            let end = b64.index(start, offsetBy: min(chunkSize, b64.count - seq * chunkSize))
            let chunk = ChunkEnvelope(msgId: msgId, seq: seq, total: total, data: String(b64[start..<end]))
            if let jsonData = try? JSONEncoder().encode(chunk),
               let jsonStr = String(data: jsonData, encoding: .utf8),
               let sendData = ("{\"chunk\":" + jsonStr + "}").data(using: .utf8) {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(seq) * 0.05) { [weak self] in
                    self?.broadcast(sendData, excludePeerId: excludePeerId)
                }
            }
        }
        onLog?("Sending \(data.count)B in \(total) chunks", .data)
    }
    
    // MARK: - Mesh Relay
    func shouldProcess(messageId: String) -> Bool {
        if seenMessageIds.contains(messageId) { return false }
        seenMessageIds.insert(messageId)
        if seenMessageIds.count > maxSeenIds {
            seenMessageIds = Set(Array(seenMessageIds).suffix(maxSeenIds / 2))
        }
        return true
    }
    
    // MARK: - Advertising
    func startAdvertising(name: String) {
        pendingAdvertisingName = name
        guard peripheralManager.state == .poweredOn else {
            onLog?("Peripheral not ready — will retry when Bluetooth is on", .info)
            return
        }
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
        onLog?("Advertising as '\(name)'", .success)
        startAutoReconnect()
    }
    
    func stopAdvertising() {
        pendingAdvertisingName = nil
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        subscribedCentrals.removeAll()
        reconnectTimer?.invalidate()
    }
    
    // MARK: - Helpers
    func peerName(for id: String) -> String {
        peers.first(where: { $0.id == id })?.name ?? "Unknown"
    }
    
    /// Fix #2: Only counts MeshLink-verified connected peers
    var connectedCount: Int {
        peers.filter { $0.connected && $0.isMeshLink }.count + subscribedCentrals.count
    }
    
    private func updatePeer(id: String, connected: Bool, connecting: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let i = self.peers.firstIndex(where: { $0.id == id }) else { return }
            self.peers[i].connected = connected
            self.peers[i].connecting = connecting
        }
    }
    
    private func markAsMeshLink(id: String) {
        meshLinkPeerIds.insert(id)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let i = self.peers.firstIndex(where: { $0.id == id }) else { return }
            self.peers[i].isMeshLink = true
        }
    }
    
    /// Fix #1: Auto-disconnect non-MeshLink device after service discovery
    private func autoDisconnectNonMeshLink(peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name ?? "device"
        centralManager.cancelPeripheralConnection(peripheral)
        cleanup(peerId: id)
        updatePeer(id: id, connected: false, connecting: false)
        onLog?("\(name) — not MeshLink, disconnected", .warning)
    }
    
    // MARK: - Incoming Data
    private func handleIncomingData(_ data: Data, from peerId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if var existing = self.chunkBuffers[peerId] {
                existing.timer?.invalidate()
                existing.data.append(data)
                let timer = Timer.scheduledTimer(withTimeInterval: self.chunkTimeout, repeats: false) { [weak self] _ in
                    self?.flushChunkBuffer(for: peerId)
                }
                self.chunkBuffers[peerId] = (existing.data, timer)
            } else {
                let timer = Timer.scheduledTimer(withTimeInterval: self.chunkTimeout, repeats: false) { [weak self] _ in
                    self?.flushChunkBuffer(for: peerId)
                }
                self.chunkBuffers[peerId] = (data, timer)
            }
        }
    }
    
    private func flushChunkBuffer(for peerId: String) {
        guard let buffer = chunkBuffers.removeValue(forKey: peerId) else { return }
        buffer.timer?.invalidate()
        guard let raw = String(data: buffer.data, encoding: .utf8), !raw.isEmpty else { return }
        
        if raw.contains("\"chunk\":{") || raw.contains("\"chunk\":  {") {
            handleChunkEnvelope(raw, from: peerId)
            return
        }
        
        onMessageReceived?(peerName(for: peerId), raw)
    }
    
    private func handleChunkEnvelope(_ raw: String, from peerId: String) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chunkJson = json["chunk"] as? [String: Any],
              let chunkData = try? JSONSerialization.data(withJSONObject: chunkJson),
              let envelope = try? JSONDecoder().decode(ChunkEnvelope.self, from: chunkData) else { return }
        
        if messageChunkBuffers[envelope.msgId] == nil {
            messageChunkBuffers[envelope.msgId] = [:]
            messageChunkExpected[envelope.msgId] = envelope.total
            messageChunkTimers[envelope.msgId] = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                self?.messageChunkBuffers.removeValue(forKey: envelope.msgId)
                self?.messageChunkExpected.removeValue(forKey: envelope.msgId)
                self?.messageChunkTimers.removeValue(forKey: envelope.msgId)
            }
        }
        messageChunkBuffers[envelope.msgId]?[envelope.seq] = envelope.data
        
        if let chunks = messageChunkBuffers[envelope.msgId],
           let total = messageChunkExpected[envelope.msgId],
           chunks.count == total {
            messageChunkTimers[envelope.msgId]?.invalidate()
            messageChunkTimers.removeValue(forKey: envelope.msgId)
            messageChunkBuffers.removeValue(forKey: envelope.msgId)
            messageChunkExpected.removeValue(forKey: envelope.msgId)
            
            let combined = (0..<total).compactMap { chunks[$0] }.joined()
            if let fullData = Data(base64Encoded: combined),
               let fullStr = String(data: fullData, encoding: .utf8) {
                onMessageReceived?(peerName(for: peerId), fullStr)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { self.bluetoothState = central.state }
        switch central.state {
        case .poweredOn: onLog?("Bluetooth ready", .success)
        case .poweredOff: onLog?("Bluetooth off — enable in Settings", .error)
        case .unauthorized: onLog?("Bluetooth permission denied", .error)
        default: break
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                let id = peripheral.identifier.uuidString
                discoveredPeripherals[id] = peripheral
                peripheral.delegate = self
                if peripheral.state == .connected {
                    updatePeer(id: id, connected: true)
                    peripheral.discoverServices(nil)
                    onLog?("Restored connection to \(peripheral.name ?? id)", .success)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier.uuidString
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Device-\(String(id.prefix(8)))"
        
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let isMesh = serviceUUIDs.contains(Self.serviceUUID) || meshLinkPeerIds.contains(id)
        
        discoveredPeripherals[id] = peripheral
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let i = self.peers.firstIndex(where: { $0.id == id }) {
                self.peers[i].rssi = RSSI.intValue
                self.peers[i].lastSeen = Date()
                if isMesh { self.peers[i].isMeshLink = true }
                if self.peers[i].name.hasPrefix("Device-") && !name.hasPrefix("Device-") {
                    self.peers[i].name = name
                }
            } else {
                self.peers.append(BLEPeer(id: id, name: name, connected: false, connecting: false, rssi: RSSI.intValue, lastSeen: Date(), isMeshLink: isMesh))
                if isMesh {
                    self.onLog?("Found MeshLink: \(name) (\(RSSI.intValue)dBm)", .success)
                } else {
                    self.onLog?("Found: \(name) (\(RSSI.intValue)dBm)", .info)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        connectionTimers[id]?.invalidate()
        connectionTimers.removeValue(forKey: id)
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        // Stay in connecting state until service discovery confirms MeshLink
        updatePeer(id: id, connected: true, connecting: true)
        onLog?("Connected to \(peripheral.name ?? "device"), verifying...", .info)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        cleanup(peerId: id)
        updatePeer(id: id, connected: false, connecting: false)
        onLog?("Connect failed: \(error?.localizedDescription ?? "unknown")", .error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        let name = peerName(for: id)
        let wasMeshLink = meshLinkPeerIds.contains(id)
        cleanup(peerId: id)
        updatePeer(id: id, connected: false, connecting: false)
        if wasMeshLink {
            onLog?("\(name) disconnected\(error.map { ": \($0.localizedDescription)" } ?? "")", .warning)
            onPeerDisconnected?(name)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            if let e = error { onLog?("Service error: \(e.localizedDescription)", .error) }
            // Fix #1: Service discovery failed — disconnect
            autoDisconnectNonMeshLink(peripheral: peripheral)
            return
        }
        let id = peripheral.identifier.uuidString
        var foundMeshLink = false
        for service in services {
            if service.uuid == Self.serviceUUID {
                foundMeshLink = true
                peripheral.discoverCharacteristics([Self.charUUID], for: service)
            }
        }
        if foundMeshLink {
            markAsMeshLink(id: id)
            // Fix #11: Done connecting, now fully connected
            updatePeer(id: id, connected: true, connecting: false)
            // Save for auto-reconnect only if MeshLink
            var known = knownPeerUUIDs; known.insert(id); knownPeerUUIDs = known
            onPeerConnected?(peerName(for: id))
        } else {
            // Fix #1: Auto-disconnect non-MeshLink devices
            autoDisconnectNonMeshLink(peripheral: peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }
        let id = peripheral.identifier.uuidString
        for char in characteristics where char.uuid == Self.charUUID {
            connectedCharacteristics[id] = char
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
            }
            onLog?("Chat channel ready with \(peerName(for: id))", .success)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else { return }
        handleIncomingData(data, from: peripheral.identifier.uuidString)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let e = error { onLog?("Notify error: \(e.localizedDescription)", .warning) }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            onLog?("Peripheral ready", .info)
            // FIX: Retry advertising that failed at launch
            if let name = pendingAdvertisingName {
                startAdvertising(name: name)
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {}
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
            onLog?("Peer subscribed via peripheral mode", .success)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll(where: { $0.identifier == central.identifier })
        onLog?("Peer unsubscribed", .warning)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value, !data.isEmpty {
                handleIncomingData(data, from: request.central.identifier.uuidString)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
