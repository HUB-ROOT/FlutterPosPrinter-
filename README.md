# Flutter Bluetooth POS Printer App

A simple Flutter application for scanning, connecting, and printing receipts on **Bluetooth thermal POS printers** using **flutter_reactive_ble** and **esc_pos_utils**.

---

## ⭐ Features

* 🔍 Scan nearby Bluetooth (BLE) printers
* 🔗 Connect & disconnect from BLE printer
* 🧭 Auto-detect writable GATT characteristic
* 🖨 Print ESC/POS formatted receipts (80mm)
* 📄 Includes test receipt print (Cafe demo invoice)
* 🟢 Real-time connection & printer-ready status

---

## 📱 Screenshots

*(Add screenshots here later)*

---

## 🛠 Tech Stack

* **Flutter**
* **flutter_reactive_ble** → BLE scanning & communication
* **permission_handler** → Runtime permissions
* **esc_pos_utils** → Generate ESC/POS print commands

---

## 📥 Installation

Clone the repository:

```sh
git clone https://github.com/yourusername/yourrepo.git
cd yourrepo
```

Install dependencies:

```sh
flutter pub get
```

Run on device:

```sh
flutter run
```

---

## 🔧 Required Permissions

### Android

Make sure to update your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

Also add inside `<application>`:

```xml
<uses-feature android:name="android.hardware.bluetooth_le" android:required="false"/>
```

---

## 🗂 Project Structure

```
lib/
 └── main.dart     # Full BLE + ESC/POS printer implementation
```

---

## 🖨 How It Works

### 1. Scan For Devices

Click the **refresh icon** → app discovers nearby BLE devices.

### 2. Connect

Tap any device → app connects & discovers services.

### 3. Detect Writable BLE Characteristic

App automatically finds:

* Writable service
* Writable characteristic
* Correct write mode (with/without response)

### 4. Print

When printer is ready, press the **print icon** in the app bar.
This sends a chunked, compatible ESC/POS data stream.

---

## 🧾 Test Print Example

The app prints:

* Store name (large centered)
* Store address
* Divider
* Itemized rows (`Qty | Item | Price`)
* Final cut

---

## 📦 Dependencies

```yaml
flutter_reactive_ble: ^5.x.x
permission_handler: ^11.x.x
esc_pos_utils: ^1.x.x
```

---

## 🧩 Known Limitations

* BLE printers only (not classic Bluetooth SPP).
* Chunk size fixed at **20 bytes** (BLE MTU default).
* Some printers may require customized ESC/POS commands.

---

## 🔮 Future Improvements

* Save & auto-reconnect to last printer
* Support for 58mm & 80mm printers
* Text/receipt designer UI
* Print images & QR codes

---

## 📝 License

MIT License – free to use & modify.

---

## 🤝 Contributing

Pull requests are welcome!
