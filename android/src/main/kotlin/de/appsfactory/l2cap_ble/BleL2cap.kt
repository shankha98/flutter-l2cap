package de.appsfactory.l2cap_ble

import kotlinx.coroutines.flow.Flow

interface BleL2cap {

    val connectionState: Flow<ConnectionState>
    val incomingData: Flow<ByteArray>

    fun connectToDevice(macAddress: String): Flow<Result<Boolean>>

    fun disconnectFromDevice(): Flow<Result<Boolean>>

    fun createL2capChannel(psm: Int): Flow<Result<Boolean>>

    fun sendMessage(message: ByteArray, responseBufferSize: Int = 1024): Flow<Result<ByteArray>>

    fun startReceivingData(bufferSize: Int = 1024): Flow<Result<Boolean>>

    fun stopReceivingData(): Flow<Result<Boolean>>
}

enum class ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    DISCONNECTING,
    ERROR
}
