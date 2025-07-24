import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:l2cap_ble/l2cap_ble.dart';

class L2CapExample extends StatefulWidget {
  const L2CapExample({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _L2CapExampleState createState() => _L2CapExampleState();
}

class _L2CapExampleState extends State<L2CapExample> {
  final L2capBle _l2capBle = L2capBle();
  final List<String> _receivedMessages = [];
  L2CapConnectionState _connectionState = L2CapConnectionState.disconnected;
  bool _isReceiving = false;

  @override
  void initState() {
    super.initState();
    _listenToConnectionState();
    _listenToIncomingData();
  }

  void _listenToConnectionState() {
    _l2capBle.getConnectionState().listen((state) {
      setState(() {
        _connectionState = state;
      });
      debugPrint('Connection state changed: $state');
    });
  }

  void _listenToIncomingData() {
    _l2capBle.getIncomingData().listen((data) {
      setState(() {
        _receivedMessages.add(
            'Received: ${String.fromCharCodes(data)} (${data.length} bytes)');
      });
      debugPrint('Received data: ${data.length} bytes');

      // Process the received data here
      _processReceivedData(data);
    });
  }

  void _processReceivedData(Uint8List data) {
    // Add your custom data processing logic here
    // This works the same on both Android and iOS
    // For example, you might want to:
    // 1. Parse the data according to your protocol
    // 2. Update your app's state based on the received data
    // 3. Send a response back to the device if needed

    debugPrint('Processing received data: ${data.length} bytes');
    // Example: Convert to string if it's text data
    String dataAsString = String.fromCharCodes(data);
    debugPrint('Data as string: $dataAsString');

    // Example: Parse binary data
    if (data.length >= 4) {
      // Read first 4 bytes as little-endian integer
      int value = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
      debugPrint('Parsed integer value: $value');
    }
  }

  Future<void> _connectAndStartReceiving() async {
    try {
      // Step 1: Connect to the device
      String deviceId =
          "YOUR_DEVICE_MAC_ADDRESS"; // Replace with actual MAC address or UUID
      // On iOS, this should be the device UUID
      // On Android, this should be the MAC address
      bool connected = await _l2capBle.connectToDevice(deviceId);

      if (connected) {
        debugPrint('Connected to device');

        // Step 2: Create L2CAP channel
        int psm = 0x1001; // Replace with your PSM value
        bool channelCreated = await _l2capBle.createL2capChannel(psm);

        if (channelCreated) {
          debugPrint('L2CAP channel created');

          // Step 3: Start receiving data
          // Using a larger buffer for enhanced data handling
          bool receivingStarted =
              await _l2capBle.startReceivingData(bufferSize: 3200);

          if (receivingStarted) {
            setState(() {
              _isReceiving = true;
            });
            debugPrint('Started receiving data');
            _addMessage('✅ Successfully connected and started receiving data');
          } else {
            debugPrint('Failed to start receiving data');
            _addMessage('❌ Failed to start receiving data');
          }
        } else {
          debugPrint('Failed to create L2CAP channel');
          _addMessage('❌ Failed to create L2CAP channel');
        }
      } else {
        debugPrint('Failed to connect to device');
        _addMessage('❌ Failed to connect to device');
      }
    } catch (e) {
      debugPrint('Error: $e');
      _addMessage('❌ Error: $e');
    }
  }

  Future<void> _stopReceiving() async {
    try {
      bool stopped = await _l2capBle.stopReceivingData();
      if (stopped) {
        setState(() {
          _isReceiving = false;
        });
        debugPrint('Stopped receiving data');
        _addMessage('🛑 Stopped receiving data');
      } else {
        debugPrint('Failed to stop receiving data');
        _addMessage('❌ Failed to stop receiving data');
      }
    } catch (e) {
      debugPrint('Error stopping reception: $e');
      _addMessage('❌ Error stopping reception: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await _l2capBle.stopReceivingData();
      String deviceId =
          "YOUR_DEVICE_MAC_ADDRESS"; // Replace with actual MAC address or UUID
      bool disconnected = await _l2capBle.disconnectFromDevice(deviceId);

      if (disconnected) {
        setState(() {
          _isReceiving = false;
        });
        debugPrint('Disconnected from device');
        _addMessage('🔌 Disconnected from device');
      } else {
        debugPrint('Failed to disconnect from device');
        _addMessage('❌ Failed to disconnect from device');
      }
    } catch (e) {
      debugPrint('Error: $e');
      _addMessage('❌ Error: $e');
    }
  }

  Future<void> _sendTestMessage() async {
    try {
      String testMessage = "Hello from Flutter!";
      Uint8List messageBytes = Uint8List.fromList(testMessage.codeUnits);

      // Send message with custom response buffer size if expecting large responses
      Uint8List response =
          await _l2capBle.sendMessage(messageBytes, responseBufferSize: 2048);

      if (response.isNotEmpty) {
        String responseString = String.fromCharCodes(response);
        _addMessage('📤 Sent: $testMessage');
        _addMessage('📥 Response: $responseString');
      } else {
        _addMessage('📤 Sent: $testMessage (no response)');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _addMessage('❌ Error sending message: $e');
    }
  }

  void _addMessage(String message) {
    setState(() {
      _receivedMessages.add(message);
    });
  }

  void _clearMessages() {
    setState(() {
      _receivedMessages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('L2CAP BLE Example'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _connectionState == L2CapConnectionState.connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _connectionState == L2CapConnectionState.connected
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text('Connection: $_connectionState'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _isReceiving ? Icons.download : Icons.download_outlined,
                      color: _isReceiving ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text('Receiving: ${_isReceiving ? "Active" : "Inactive"}'),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _connectionState == L2CapConnectionState.disconnected
                              ? _connectAndStartReceiving
                              : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Connect & Start'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isReceiving ? _stopReceiving : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Receiving'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          _connectionState == L2CapConnectionState.connected
                              ? _sendTestMessage
                              : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Test'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          _connectionState != L2CapConnectionState.disconnected
                              ? _disconnect
                              : null,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect'),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Messages (${_receivedMessages.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _clearMessages,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _receivedMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages received yet.\nConnect to device and start receiving data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _receivedMessages.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            _receivedMessages[index],
                            style: const TextStyle(fontSize: 12),
                          ),
                          leading: CircleAvatar(
                            radius: 12,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
