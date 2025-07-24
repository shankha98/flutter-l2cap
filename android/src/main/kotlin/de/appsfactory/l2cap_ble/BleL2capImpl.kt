package de.appsfactory.l2cap_ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import java.util.*
import kotlin.coroutines.coroutineContext


class BleL2capImpl(
    private val context: Context,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : BleL2cap {

    private val connectionStateSharedFlow = MutableSharedFlow<ConnectionState>()
    private val incomingDataSharedFlow = MutableSharedFlow<ByteArray>()
    private var isReceiving = false
    private var receivingJob: kotlinx.coroutines.Job? = null

    private val bluetoothManager: BluetoothManager? by lazy {
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager?
    }
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        bluetoothManager?.adapter
    }

    private var bluetoothDevice: BluetoothDevice? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var bluetoothSocket: BluetoothSocket? = null

    override val connectionState: Flow<ConnectionState> = connectionStateSharedFlow.asSharedFlow()
    override val incomingData: Flow<ByteArray> = incomingDataSharedFlow.asSharedFlow()

    @SuppressLint("MissingPermission")
    override fun connectToDevice(macAddress: String): Flow<Result<Boolean>> = flow {
        val result = try {
            bluetoothDevice = bluetoothAdapter?.getRemoteDevice(macAddress)
            if (bluetoothDevice == null) {
                throw Exception("Device with address: $macAddress not found")
            }
            val connectionStateChannel = Channel<ConnectionState>(Channel.BUFFERED)
            connectionStateChannel.trySend(ConnectionState.CONNECTING)
            val gattCallback = object : BluetoothGattCallback() {

                // Implement the necessary callback methods, like onConnectionStateChange, onServicesDiscovered, etc.
                override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                    super.onConnectionStateChange(gatt, status, newState)

                    when (newState) {
                        BluetoothGatt.STATE_CONNECTED -> {
                            connectionStateChannel.trySend(ConnectionState.CONNECTED)
                        }

                        BluetoothGatt.STATE_CONNECTING -> {
                            connectionStateChannel.trySend(ConnectionState.CONNECTING)
                        }

                        BluetoothGatt.STATE_DISCONNECTING -> {
                            connectionStateChannel.trySend(ConnectionState.DISCONNECTING)
                        }

                        BluetoothGatt.STATE_DISCONNECTED -> {
                            connectionStateChannel.trySend(ConnectionState.DISCONNECTED)
                        }
                    }
                }
            }
            CoroutineScope(coroutineContext).launch {
                for (state in connectionStateChannel) {
                    connectionStateSharedFlow.emit(state)
                }
            }
            bluetoothGatt = bluetoothDevice?.connectGatt(context, false, gattCallback)
            Result.success(true)
        } catch (e: Exception) {
            Result.failure(e)
        }
        emit(result)
    }.flowOn(ioDispatcher)

    @SuppressLint("MissingPermission")
    override fun disconnectFromDevice(): Flow<Result<Boolean>> = flow {
        val result = try {
            connectionStateSharedFlow.emit(ConnectionState.DISCONNECTING)
            bluetoothGatt?.disconnect()
            bluetoothGatt = null
            connectionStateSharedFlow.emit(ConnectionState.DISCONNECTED)
            Result.success(true)
        } catch (e: Exception) {
            Result.failure(e)
        }
        emit(result)
    }.flowOn(ioDispatcher)

    @SuppressLint("MissingPermission")
    override fun createL2capChannel(psm: Int): Flow<Result<Boolean>> = flow {
        // You should check if the device supports opening an L2CAP channel.
        val result = try {
            bluetoothSocket = bluetoothDevice?.createInsecureL2capChannel(psm)
            if (bluetoothSocket == null) {
                throw Exception("Failed to create L2CAP channel")
            }
            bluetoothSocket?.connect()
            Result.success(true)
        } catch (e: Exception) {
            Result.failure(e)
        }
        emit(result)
    }.flowOn(ioDispatcher)

    @SuppressLint("MissingPermission")
    override fun sendMessage(message: ByteArray, responseBufferSize: Int): Flow<Result<ByteArray>> = flow {
        val result = try {
            if (bluetoothSocket == null) {
                throw Exception("Bluetooth socket is null")
            }
            bluetoothSocket?.outputStream?.write(message)
            // Now, we should read the response from the input stream
            val response = ByteArray(responseBufferSize) // Buffer size is now configurable
            val bytesRead = bluetoothSocket?.inputStream?.read(response)
            // It's important to note that the above read call is blocking.
            // You might want to wrap it with 'withTimeout' to prevent it from blocking indefinitely.
            bytesRead?.let {
                Result.success(response.copyOfRange(0, it))
            } ?: Result.failure(Exception("Failed to read response"))
        } catch (e: Exception) {
            Result.failure(e)
        }
        emit(result)
    }.flowOn(ioDispatcher)

    @SuppressLint("MissingPermission")
    override fun startReceivingData(bufferSize: Int): Flow<Result<Boolean>> = flow {
        val result = try {
            if (bluetoothSocket == null) {
                throw Exception("Bluetooth socket is null")
            }
            if (isReceiving) {
                throw Exception("Already receiving data")
            }
            
            isReceiving = true
            receivingJob = CoroutineScope(ioDispatcher).launch {
                try {
                    val inputStream = bluetoothSocket?.inputStream
                    val buffer = ByteArray(bufferSize)
                    
                    while (isReceiving && bluetoothSocket?.isConnected == true) {
                        try {
                            val bytesRead = inputStream?.read(buffer)
                            if (bytesRead != null && bytesRead > 0) {
                                val receivedData = buffer.copyOfRange(0, bytesRead)
                                incomingDataSharedFlow.emit(receivedData)
                            }
                        } catch (e: Exception) {
                            if (isReceiving) {
                                // Only emit error if we're still supposed to be receiving
                                // Socket might have been closed intentionally
                                throw e
                            }
                            break
                        }
                    }
                } catch (e: Exception) {
                    isReceiving = false
                    throw e
                }
            }
            
            Result.success(true)
        } catch (e: Exception) {
            isReceiving = false
            Result.failure(e)
        }
        emit(result)
    }.flowOn(ioDispatcher)

    override fun stopReceivingData(): Flow<Result<Boolean>> = flow {
        val result = try {
            isReceiving = false
            receivingJob?.cancel()
            receivingJob = null
            Result.success(true)
        } catch (e: Exception) {
            Result.failure(e)
        }
        emit(result)
    }.flowOn(ioDispatcher)
}
