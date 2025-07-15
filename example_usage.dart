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
        _receivedMessages.add('Received: ${String.fromCharCodes(data)}');
      });
      debugPrint('Received data: ${data.length} bytes');

      // Process the received data here
      _processReceivedData(data);
    });
  }

  void _processReceivedData(Uint8List data) {
    // Add your custom data processing logic here
    // For example, you might want to:
    // 1. Parse the data according to your protocol
    // 2. Update your app's state based on the received data
    // 3. Send a response back to the device if needed

    debugPrint('Processing received data: ${data.length} bytes');
    // Example: Convert to string if it's text data
    String dataAsString = String.fromCharCodes(data);
    debugPrint('Data as string: $dataAsString');
  }

  Future<void> _connectAndStartReceiving() async {
    try {
      // Step 1: Connect to the device
      String deviceId =
          "YOUR_DEVICE_MAC_ADDRESS"; // Replace with actual MAC address
      bool connected = await _l2capBle.connectToDevice(deviceId);

      if (connected) {
        debugPrint('Connected to device');

        // Step 2: Create L2CAP channel
        int psm = 0x1001; // Replace with your PSM value
        bool channelCreated = await _l2capBle.createL2capChannel(psm);

        if (channelCreated) {
          debugPrint('L2CAP channel created');

          // Step 3: Start receiving data
          bool receivingStarted = await _l2capBle.startReceivingData();

          if (receivingStarted) {
            debugPrint('Started receiving data');
          } else {
            debugPrint('Failed to start receiving data');
          }
        } else {
          debugPrint('Failed to create L2CAP channel');
        }
      } else {
        debugPrint('Failed to connect to device');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _stopReceiving() async {
    try {
      bool stopped = await _l2capBle.stopReceivingData();
      if (stopped) {
        debugPrint('Stopped receiving data');
      } else {
        debugPrint('Failed to stop receiving data');
      }
    } catch (e) {
      debugPrint('Error stopping reception: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await _l2capBle.stopReceivingData();
      String deviceId =
          "YOUR_DEVICE_MAC_ADDRESS"; // Replace with actual MAC address
      bool disconnected = await _l2capBle.disconnectFromDevice(deviceId);

      if (disconnected) {
        debugPrint('Disconnected from device');
      } else {
        debugPrint('Failed to disconnect from device');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('L2CAP BLE Example'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Connection State: $_connectionState'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _connectAndStartReceiving,
                      child: const Text('Connect & Start'),
                    ),
                    ElevatedButton(
                      onPressed: _stopReceiving,
                      child: const Text('Stop Receiving'),
                    ),
                    ElevatedButton(
                      onPressed: _disconnect,
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _receivedMessages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_receivedMessages[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
