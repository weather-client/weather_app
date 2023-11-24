import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:weather_station/schemas.dart';
import 'package:weather_station/config_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    FlutterBluePlus.setLogLevel(LogLevel.debug);

    return MaterialApp(
      title: StationConfig.appTitle,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Weather Station'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final StationConfig _config = StationConfig();
  final WeatherData _weatherData = WeatherData();
  BluetoothDevice? _device;
  BluetoothService? _service;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  final StreamController<String> _consumerStreamController =
      StreamController<String>();
  Stream<String>? _consumerStream;
  String _inputBuffer = "";

  Future<void> _enableBluetooth() async {
    // check adapter availability
    if (await FlutterBluePlus.isAvailable == false) {
      log("Bluetooth not supported by this device", name: "Bluetooth");
      return;
    }

    // turn on bluetooth ourself if we can
    // for iOS, the user controls bluetooth enable/disable
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    // wait bluetooth to be on & print states
    // note: for iOS the initial state is typically BluetoothAdapterState.unknown
    // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
    await FlutterBluePlus.adapterState
        .map((s) {
          log(s.name);
          return s;
        })
        .where((s) => s == BluetoothAdapterState.on)
        .first;
  }

  Future<void> _scanBluetoothAndConnect() async {
    // check adapter state before scanning
    _enableBluetooth();

    if (_device != null) {
      await _device!.disconnect();
      _device = null;
    }

    // Setup Listener for scan results
    // device not found? see "Common Problems" in the README
    var subscription = FlutterBluePlus.scanResults.listen((results) async {
      if (_device != null) {
        return;
      }
      for (ScanResult r in results) {
        if (r.device.localName.isEmpty) {
          continue;
        }
        if (r.device.localName == StationConfig.bleDeviceName) {
          log('Found BLE device -> Name: ${r.device.localName}, Type: ${r.device.type}',
              name: 'Bluetooth');
          _device = r.device;
          await FlutterBluePlus.stopScan();
          return;
        }
        log('${r.device.localName} found! rssi: ${r.rssi}', name: 'Bluetooth');
      }
    });

    // Start scanning
    log("Start scanning", name: "Bluetooth");
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));

    // Stop scanning
    log("Stop scanning", name: "Bluetooth");
    await FlutterBluePlus.stopScan();
    subscription.cancel();
    if (_device != null) {
      await _connectBluetooth();
    }
  }

  Future<void> _connectBluetooth() async {
    if (_device == null) {
      log("No device found");
      return;
    }
    log("Connecting to ${_device!.localName}", name: "Bluetooth");
    _connectionStateSubscription =
        _device!.connectionState.listen((BluetoothConnectionState event) async {
      if (event == BluetoothConnectionState.connected) {
        log("Services discovered: ", name: "Bluetooth");
        // Note: You must call this again if disconnected!
        List<BluetoothService> services = await _device!.discoverServices();
        services.forEach((service) {
          log("Service: ${service.uuid}", name: "Bluetooth");
          if (service.uuid.toByteArray().sublist(0, 4).toString() ==
              StationConfig.serviceUUID.toString()) {
            service.characteristics.forEach((characteristic) {
              log("Characteristic: ${characteristic.uuid}", name: "Bluetooth");

              if (characteristic.uuid.toByteArray().sublist(0, 4).toString() ==
                  StationConfig.characteristicUUID.toString()) {
                log("Found WeatherStation service and characteristic: ${characteristic.uuid}",
                    name: "Bluetooth");
                setState(() {
                  _service = service;
                  _characteristic = characteristic;
                  _connectionStateSubscription?.cancel();
                  _connectionStateSubscription = null;
                });
                _connectCharacteristic();
              }
            });
            return;
          }
        });
      }
    });

    await _device!.connect();
  }

  void _consumeInputBuffer(String? input) {
    if (input != null) {
      _inputBuffer += input;
    }
    while (_inputBuffer.contains("\n")) {
      String message = _inputBuffer.substring(0, _inputBuffer.indexOf("\n"));
      _inputBuffer = _inputBuffer.substring(_inputBuffer.indexOf("\n") + 1);

      message = message.trim();
      if (message == "AT") {
        _characteristic!.write("OK\r\n".codeUnits, withoutResponse: true);
        log('Response: ${"OK\r\n".codeUnits}', name: 'Bluetooth');
      }
      _consumerStreamController.add(message);
    }
  }

  Future<void> _connectCharacteristic() async {
    if (_characteristic == null) {
      log("No characteristic found");
      return;
    }
    log("Connecting to ${_characteristic!.uuid}", name: "Bluetooth");
    _characteristic!.setNotifyValue(true);
    _valueSubscription = _characteristic!.onValueReceived.listen((value) {
      _consumeInputBuffer(value.map((e) => String.fromCharCode(e)).join());
    });
    _characteristic!.write([0x41, 0x41, 0x41, 0x41], withoutResponse: true);
  }

  Future<void> _disconnectDevice() async {
    if (_device == null) {
      log("No device found");
      return;
    }
    log("Disconnecting from ${_device!.localName}", name: "Bluetooth");
    await _device!.disconnect();
    _valueSubscription?.cancel();
    setState(() {
      _device = null;
      _valueSubscription = null;
      _characteristic = null;
      _service = null;
    });
  }

  void _configureDevice() {
    if (_characteristic != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ConfigScreen(
                  device: _device as BluetoothDevice,
                  characteristic: _characteristic as BluetoothCharacteristic,
                  consumerStream: _consumerStream as Stream<String>,
                  config: _config,
                )),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _consumerStream = _consumerStreamController.stream.asBroadcastStream();
    _consumerStream!.listen((event) {
      log("Event: $event", name: "Bluetooth");
      if (event.startsWith('AT+CONFIG=')) {
        String message = event.substring('AT+CONFIG='.length);
        bool assignMark = message.contains('=');
        String name =
            assignMark ? message.substring(0, message.indexOf('=')) : message;
        String value =
            assignMark ? message.substring(message.indexOf('=') + 1) : "";
        log("Config: $name=$value", name: "Bluetooth");
        switch (name) {
          case "station.id":
            _config.stationId = value;
            break;
          case "station.sendInterval":
            _config.sendInterval = int.parse(value);
            break;
          case "location.connected":
            _config.location!.connected = value == "1";
            break;
          case "location.gps":
            _config.location!.useGps = value == "1";
            break;
          case "location.lat":
            _config.location!.latitude = double.parse(value);
            break;
          case "location.lon":
            _config.location!.longitude = double.parse(value);
            break;
          case "wifi.enabled":
            _config.wifi!.enabled = value == "1";
            break;
          case "wifi.connected":
            _config.wifi!.connected = value == "1";
            break;
          case "wifi.ssid":
            _config.wifi!.ssid = value;
            break;
          case "wifi.pwd":
            _config.wifi!.password = value;
            break;
          case "eth.enabled":
            _config.ethernet!.enabled = value == "1";
            break;
          case "eth.connected":
            _config.ethernet!.connected = value == "1";
            break;
          case "eth.ip":
            _config.ethernet!.ip = value;
            break;
          case "eth.subnet":
            _config.ethernet!.mask = value;
            break;
          case "eth.gateway":
            _config.ethernet!.gateway = value;
            break;
          case "eth.dns":
            _config.ethernet!.dns = value;
            break;
          case "lora.enabled":
            _config.lora!.enabled = value == "1";
            break;
          case "lora.connected":
            _config.lora!.connected = value == "1";
            break;
          case "lora.devEui":
            _config.lora!.devEui = value;
            break;
          case "lora.appEui":
            _config.lora!.appEui = value;
            break;
          case "lora.appKey":
            _config.lora!.appKey = value;
            break;
          case "sim.enabled":
            _config.cellular!.enabled = value == "1";
            break;
          case "sim.connected":
            _config.cellular!.connected = value == "1";
            break;
          case "sim.apn":
            _config.cellular!.apn = value;
            break;
          case "sim.user":
            _config.cellular!.user = value;
            break;
          case "sim.pwd":
            _config.cellular!.password = value;
            break;
          case "done":
            _config.doneUpdating();
            log('Configuration done}', name: "Bluetooth");
            break;
          default:
            log("Unknown config: $name=$value", name: "Bluetooth");
        }
      } else if (event.startsWith('AT+DATA=')) {
        // Format example: {"loc":{"lat":52.202381,"lon":21.035158},"data":{"ws":[0.10],"wd":["NE"],"a":[{"t":23.70,"h":62.00}]}}
        String message = event.substring('AT+DATA='.length);
        log("Data: $message", name: "Bluetooth");
        Map<String, dynamic> data = jsonDecode(message);
        _weatherData.location.latitude = data['loc']['lat'];
        _weatherData.location.longitude = data['loc']['lon'];
        // List of wind speeds
        _weatherData.windSpeeds = (data['data']['ws'] as List<dynamic>)
            .map((e) => e as double)
            .toList();
        // List of wind directions
        _weatherData.windDirections = (data['data']['wd'] as List<dynamic>)
            .map((e) => e as String)
            .toList();
        // List of air data
        _weatherData.airDatas = (data['data']['a'] as List<dynamic>)
            .map((e) => AirData(
                temperature: e['t'] as double, humidity: e['h'] as double))
            .toList();
        // _weatherData.windDirections = data['data']['wd'];
        // _weatherData.airDatas = data['data']['a'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            (_device != null)
                ? Text(
                    'Connected to ${_device!.localName}',
                  )
                : const Text(
                    'No device connected',
                  ),
            (_device == null)
                ? TextButton(
                    onPressed: _scanBluetoothAndConnect,
                    child: const Text("Scan & Connect"))
                : TextButton(
                    onPressed: _disconnectDevice,
                    child: const Text("Disconnect")),
          ],
        ),
      ),
      floatingActionButton: (_device != null)
          ? FloatingActionButton(
              onPressed: _configureDevice,
              tooltip: 'Configure',
              child: const Icon(Icons.tune),
            )
          : null, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
