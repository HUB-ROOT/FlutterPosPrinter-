// lib/main.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "POS Printer",
      home: const BluetoothPrinterScreen(),
    );
  }
}

class BluetoothPrinterScreen extends StatefulWidget {
  const BluetoothPrinterScreen({super.key});

  @override
  State<BluetoothPrinterScreen> createState() => _BluetoothPrinterScreenState();
}

class _BluetoothPrinterScreenState extends State<BluetoothPrinterScreen> {
  final FlutterReactiveBle ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<ConnectionStateUpdate>? connSub;

  List<DiscoveredDevice> devices = [];
  bool isScanning = false;
  String? connectedDeviceId;
  bool printerReady = false;

  Uuid? detectedService;
  Uuid? detectedWriteChar;
  bool writeWithResponse = true;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> startScan() async {
    if (isScanning) return;
    setState(() {
      devices.clear();
      isScanning = true;
    });

    scanSub?.cancel();
    scanSub = ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen(
          (device) {
            if (device.name.isNotEmpty &&
                !devices.any((d) => d.id == device.id)) {
              setState(() => devices.add(device));
            }
          },
          onError: (e) => showMsg("Scan error: $e"),
          onDone: () => setState(() => isScanning = false),
        );
  }

  Future<void> connectToDevice(String devId) async {
    connSub?.cancel();
    setState(() {
      connectedDeviceId = null;
      printerReady = false;
    });

    connSub = ble
        .connectToDevice(
          id: devId,
          connectionTimeout: const Duration(seconds: 12),
        )
        .listen((update) async {
          if (update.connectionState == DeviceConnectionState.connected) {
            setState(() => connectedDeviceId = devId);
            showMsg("Connected!");
            await detectCharacteristic(devId);
          }
          if (update.connectionState == DeviceConnectionState.disconnected) {
            setState(() {
              connectedDeviceId = null;
              printerReady = false;
            });
            showMsg("Printer disconnected");
          }
        }, onError: (e) => showMsg("Connection error: $e"));
  }

  Future<void> detectCharacteristic(String devId) async {
    try {
      final services = await ble.discoverServices(devId);
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.isWritableWithResponse || c.isWritableWithoutResponse) {
            detectedService = s.serviceId;
            detectedWriteChar = c.characteristicId;
            writeWithResponse = c.isWritableWithResponse;
            setState(() => printerReady = true);
            showMsg("Printer ready for printing");
            return;
          }
        }
      }
      showMsg("Could not detect writable characteristic");
    } catch (e) {
      showMsg("Error detecting characteristic: $e");
    }
  }

  Future<void> sendBytes(List<int> bytes) async {
    if (!printerReady || connectedDeviceId == null) {
      showMsg("Printer not ready");
      return;
    }

    final characteristic = QualifiedCharacteristic(
      deviceId: connectedDeviceId!,
      characteristicId: detectedWriteChar!,
      serviceId: detectedService!,
    );

    const int chunkSize = 20;

    for (var i = 0; i < bytes.length; i += chunkSize) {
      final chunk = bytes.sublist(
        i,
        i + chunkSize > bytes.length ? bytes.length : i + chunkSize,
      );

      try {
        await ble.writeCharacteristicWithResponse(
          characteristic,
          value: Uint8List.fromList(chunk),
        );
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 50));
        await ble.writeCharacteristicWithResponse(
          characteristic,
          value: Uint8List.fromList(chunk),
        );
      }

      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> printTest() async {
    if (!printerReady) {
      showMsg("Printer not ready");
      return;
    }

    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    bytes += gen.text(
      "CAFE DE LUXE",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += gen.text(
      "Amsterdam Centrum",
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += gen.hr();

    bytes += gen.row([
      PosColumn(text: "Qty", width: 2),
      PosColumn(text: "Item", width: 6),
      PosColumn(
        text: "Price",
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += gen.row([
      PosColumn(text: "2", width: 2),
      PosColumn(text: "Cappuccino", width: 6),
      PosColumn(
        text: "Rs 700",
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += gen.row([
      PosColumn(text: "1", width: 2),
      PosColumn(text: "Croissant", width: 6),
      PosColumn(
        text: "Rs 350",
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += gen.feed(2);
    bytes += gen.cut();

    await sendBytes(bytes);
    showMsg("Printed successfully!");
  }

  void showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    scanSub?.cancel();
    connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = connectedDeviceId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("POS Bluetooth Printer"),
        actions: [
          IconButton(
            icon: isScanning
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.refresh),
            onPressed: startScan,
          ),
          if (connected && printerReady)
            IconButton(icon: const Icon(Icons.print), onPressed: printTest),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: connected && printerReady ? Colors.green : Colors.red,
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: Text(
              connected
                  ? (printerReady ? "Printer Ready" : "Connected - Not Ready")
                  : "Not Connected",
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: devices.isEmpty
                ? const Center(child: Text("No devices found"))
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (c, i) {
                      final d = devices[i];
                      final isThisConnected = d.id == connectedDeviceId;

                      return ListTile(
                        leading: Icon(
                          isThisConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth,
                        ),
                        title: Text(d.name),
                        subtitle: Text(d.id),
                        trailing: isThisConnected
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () {
                                  connSub?.cancel();
                                  setState(() {
                                    connectedDeviceId = null;
                                    printerReady = false;
                                  });
                                },
                                child: const Text("Disconnect"),
                              )
                            : ElevatedButton(
                                onPressed: () => connectToDevice(d.id),
                                child: const Text("Connect"),
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
