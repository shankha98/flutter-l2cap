import 'dart:typed_data';

import 'l2cap_ble_platform_interface.dart';

class L2capBle {
  Future<bool> connectToDevice(String deviceId) =>
      L2capBlePlatform.instance.connectToDevice(deviceId);
  Future<bool> disconnectFromDevice(String deviceId) =>
      L2capBlePlatform.instance.disconnectFromDevice(deviceId);
  Stream<L2CapConnectionState> getConnectionState() =>
      L2capBlePlatform.instance.getConnectionState();
  Stream<Uint8List> getIncomingData() =>
      L2capBlePlatform.instance.getIncomingData();
  Future<bool> createL2capChannel(int psm) =>
      L2capBlePlatform.instance.createL2capChannel(psm);
  Future<Uint8List> sendMessage(Uint8List message) =>
      L2capBlePlatform.instance.sendMessage(message);
  Future<bool> startReceivingData() =>
      L2capBlePlatform.instance.startReceivingData();
  Future<bool> stopReceivingData() =>
      L2capBlePlatform.instance.stopReceivingData();
}

enum L2CapConnectionState {
  connecting,
  connected,
  disconnecting,
  disconnected,
  error
}
