package de.appsfactory.l2cap_ble

import androidx.annotation.NonNull

import de.appsfactory.l2cap_ble.BleL2capImpl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.Log
import io.flutter.plugin.common.EventChannel
import kotlin.Result as KResult

/** L2capBlePlugin */
class L2capBlePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var connectionStateEventChannel: EventChannel
    private lateinit var incomingDataEventChannel: EventChannel
    private var connectionStateEventSink: EventChannel.EventSink? = null
    private var incomingDataEventSink: EventChannel.EventSink? = null
    private lateinit var bleL2capImpl: BleL2capImpl

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "l2cap_ble")
        channel.setMethodCallHandler(this)
        
        connectionStateEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "getConnectionState")
        connectionStateEventChannel.setStreamHandler(ConnectionStateStreamHandler())
        
        incomingDataEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "getIncomingData")
        incomingDataEventChannel.setStreamHandler(IncomingDataStreamHandler())
        
        bleL2capImpl = BleL2capImpl(flutterPluginBinding.applicationContext, Dispatchers.IO)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
       if (call.method == "connectToDevice") {
            CoroutineScope(Dispatchers.Main).launch {
                val macAddress: String = requireNotNull(call.argument("deviceId"))
                bleL2capImpl.connectToDevice(macAddress).collect { res: KResult<Boolean> ->
                    Log.d("L2capBlePlugin", "connectToDevice: $res")
                    res.mapToResult(result)
                }
            }
        } else if (call.method == "disconnectFromDevice") {
            CoroutineScope(Dispatchers.Main).launch {
                bleL2capImpl.disconnectFromDevice().collect { res: KResult<Boolean> ->
                    Log.d("L2capBlePlugin", "disconnectFromDevice: $res")
                    res.mapToResult(result)
                }
            }
        } else if (call.method == "createL2capChannel") {
            CoroutineScope(Dispatchers.Main).launch {
                val psm: Int = requireNotNull(call.argument("psm"))
                bleL2capImpl.createL2capChannel(psm).collect { res: KResult<Boolean> ->
                    Log.d("L2capBlePlugin", "createL2capChannel: $res")
                    res.mapToResult(result)
                }
            }
        } else if (call.method == "sendMessage") {
            CoroutineScope(Dispatchers.Main).launch {
                val message: ByteArray = requireNotNull(call.argument("message"))
                val responseBufferSize: Int = call.argument("responseBufferSize") ?: 1024
                bleL2capImpl.sendMessage(message, responseBufferSize).collect { res: KResult<ByteArray> ->
                    Log.d("L2capBlePlugin", "sendMessage: $res")
                    res.mapToResult(result)
                }
            }
        } else if (call.method == "startReceivingData") {
            CoroutineScope(Dispatchers.Main).launch {
                val bufferSize: Int = call.argument("bufferSize") ?: 1024
                bleL2capImpl.startReceivingData(bufferSize).collect { res: KResult<Boolean> ->
                    Log.d("L2capBlePlugin", "startReceivingData: $res")
                    res.mapToResult(result)
                }
            }
        } else if (call.method == "stopReceivingData") {
            CoroutineScope(Dispatchers.Main).launch {
                bleL2capImpl.stopReceivingData().collect { res: KResult<Boolean> ->
                    Log.d("L2capBlePlugin", "stopReceivingData: $res")
                    res.mapToResult(result)
                }
            }
        } else {
            result.notImplemented()
        }
    }

    inner class ConnectionStateStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
            connectionStateEventSink = eventSink
            CoroutineScope(Dispatchers.Main).launch {
                bleL2capImpl.connectionState.collect { state: ConnectionState ->
                    Log.d("L2capBlePlugin", "ConnectionState: $state")
                    connectionStateEventSink?.success(state.ordinal)
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            connectionStateEventSink = null
        }
    }

    inner class IncomingDataStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
            incomingDataEventSink = eventSink
            CoroutineScope(Dispatchers.Main).launch {
                bleL2capImpl.incomingData.collect { data: ByteArray ->
                    Log.d("L2capBlePlugin", "Incoming data: ${data.size} bytes")
                    incomingDataEventSink?.success(data)
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            incomingDataEventSink = null
        }
    }

    override fun onCancel(arguments: Any?) {
        // This method is from the old EventChannel.StreamHandler interface
        // We keep it for compatibility but it's not used anymore
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
        // This method is from the old EventChannel.StreamHandler interface
        // We keep it for compatibility but it's not used anymore
    }

    private suspend fun KResult<Any>.mapToResult(@NonNull result: Result) {
        withContext(Dispatchers.Main) {
            if (isSuccess) {
                result.success(getOrNull())
            } else {
                result.error("error", exceptionOrNull()?.message, null)
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
