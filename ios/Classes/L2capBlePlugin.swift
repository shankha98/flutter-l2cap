import Flutter
import UIKit

public class L2capBlePlugin: NSObject, FlutterPlugin {
    
    private var connectionStateEventSink: FlutterEventSink?
    private var incomingDataEventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "l2cap_ble", binaryMessenger: registrar.messenger())
        let instance = L2capBlePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Register the connection state event channel
        let connectionStateEventChannel = FlutterEventChannel(name: "getConnectionState", binaryMessenger: registrar.messenger())
        connectionStateEventChannel.setStreamHandler(ConnectionStateStreamHandler(plugin: instance))
        
        // Register the incoming data event channel
        let incomingDataEventChannel = FlutterEventChannel(name: "getIncomingData", binaryMessenger: registrar.messenger())
        incomingDataEventChannel.setStreamHandler(IncomingDataStreamHandler(plugin: instance))
    }
    
    override private init() {
        super.init()
    }
    
    func setConnectionStateEventSink(_ eventSink: FlutterEventSink?) {
        self.connectionStateEventSink = eventSink
    }
    
    func setIncomingDataEventSink(_ eventSink: FlutterEventSink?) {
        self.incomingDataEventSink = eventSink
    }
    
    @objc func getConnectionState(notification: Notification) {
        guard let eventSink = self.connectionStateEventSink,
        let userInfo = notification.userInfo,
        let updatedState = userInfo["state"] as? Int32 else {
            return
        }
        eventSink(updatedState)
    }
    
    @objc func getIncomingData(notification: Notification) {
        guard let eventSink = self.incomingDataEventSink,
        let userInfo = notification.userInfo,
        let data = userInfo["data"] as? Data else {
            return
        }
        let flutterData = FlutterStandardTypedData(bytes: data)
        eventSink(flutterData)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        
        switch call.method {
        case "connectToDevice":
            if let arguments = call.arguments as? [String: Any],
               let deviceId = arguments["deviceId"] as? String {
                BluetoothManager.shared.connectToDevice(deviceId: deviceId) { status in
                    if status {
                        print("connection successful")
                        result(true)
                    } else {
                        result(false)
                    }
                }
            }
        case "disconnectFromDevice":
            print("calling disconnect")
            if let arguments = call.arguments as? [String: Any],
               let deviceId = arguments["deviceId"] as? String {
                BluetoothManager.shared.disconnectFromDevice(deviceId: deviceId) { status in
                    if status {
                        print("disconnected successful")
                        result(true)
                    } else {
                        result(false)
                    }
                }
            }
            result(true)
        case "createL2capChannel":
            if let arguments = call.arguments as? [String: Any],
               let psm = arguments["psm"] as? UInt16 {
                BluetoothManager.shared.createL2CapChannel(psm: psm) { status in
                    if status {
                        print("created L2CAP channel")
                        result(true)
                    } else {
                        print("Failed to create L2CAP channel")
                        result(false)
                    }
                }
            }
        case "sendMessage":
            if let arguments = call.arguments as? [String: Any],
               let message = arguments["message"] as? FlutterStandardTypedData {
                
                let responseBufferSize = arguments["responseBufferSize"] as? Int ?? 1024
                
                if let byteArray = self.parseFlutterStandardTypedDataToData(message) {
                    BluetoothManager.shared.sendMessage(message: byteArray, responseBufferSize: responseBufferSize) { response in
                        let data = self.convertInt16ToData(response)
                        let stringValue = String(data: data, encoding: .utf8) ?? ""
                        print("Returned data is \(response) \(stringValue)")
                        result(self.parseDataToFlutterStandardTypedData(data))
                    }
                } else {
                    result(nil)
                }
            }
        case "startReceivingData":
            let arguments = call.arguments as? [String: Any]
            let bufferSize = arguments?["bufferSize"] as? Int ?? 1024
            
            BluetoothManager.shared.startReceivingData(bufferSize: bufferSize) { status in
                if status {
                    print("Started receiving data with buffer size: \(bufferSize)")
                    result(true)
                } else {
                    print("Failed to start receiving data")
                    result(false)
                }
            }
        case "stopReceivingData":
            BluetoothManager.shared.stopReceivingData { status in
                if status {
                    print("Stopped receiving data")
                    result(true)
                } else {
                    print("Failed to stop receiving data")
                    result(false)
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func parseFlutterStandardTypedDataToData(_ data: FlutterStandardTypedData) -> Data? {
        return data.data
    }
    
    func parseDataToFlutterStandardTypedData(_ data: Data) -> FlutterStandardTypedData {
        return FlutterStandardTypedData(bytes: data)
    }
    
    func convertInt16ToData(_ value: Int16) -> Data {
        var intValue = value
        return Data(bytes: &intValue, count: MemoryLayout<Int16>.size)
    }
}

// MARK: - Stream Handlers

class ConnectionStateStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: L2capBlePlugin?
    
    init(plugin: L2capBlePlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setConnectionStateEventSink(events)
        NotificationCenter.default.addObserver(
            plugin!,
            selector: #selector(L2capBlePlugin.getConnectionState(notification:)),
            name: Notification.Name("getConnectionStateNotification"),
            object: nil)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setConnectionStateEventSink(nil)
        NotificationCenter.default.removeObserver(plugin!, name: Notification.Name("getConnectionStateNotification"), object: nil)
        return nil
    }
}

class IncomingDataStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: L2capBlePlugin?
    
    init(plugin: L2capBlePlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setIncomingDataEventSink(events)
        NotificationCenter.default.addObserver(
            plugin!,
            selector: #selector(L2capBlePlugin.getIncomingData(notification:)),
            name: Notification.Name("getIncomingDataNotification"),
            object: nil)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setIncomingDataEventSink(nil)
        NotificationCenter.default.removeObserver(plugin!, name: Notification.Name("getIncomingDataNotification"), object: nil)
        return nil
    }
}
