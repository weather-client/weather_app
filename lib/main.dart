import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
      title: 'Flutter Demo',
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  int _counter = 0;
  BluetoothDevice? _device;
  final List<int> ServiceUUID = [0x00, 0x00, 0xff, 0xe0];
  final List<int> CharacteristicUUID = [0x00, 0x00, 0xff, 0xe1];

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  Future<void> _enableBluetooth() async {
    // check adapter availability
    if (await FlutterBluePlus.isAvailable == false) {
      log("Bluetooth not supported by this device");
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
    if (_device != null) {
      await _device!.disconnect();
      _device = null;
    }

    // Setup Listener for scan results
    // device not found? see "Common Problems" in the README
    var subscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.localName.isEmpty) {
          continue;
        }
        if (r.device.localName == "WeatherStation") {
          log("Found WeatherStation");
          _device = r.device;
          await FlutterBluePlus.stopScan();
        }
        log('${r.device.localName} found! rssi: ${r.rssi}');
      }
    });

    // Start scanning
    log("Start scanning");
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));

    // Stop scanning
    log("Stop scanning");
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
    log("Connecting to ${_device!.localName}");
    _device!.connectionState.listen((BluetoothConnectionState event) async {
      if (event == BluetoothConnectionState.connected) {
        log("Connected");
        log("Services discovered");
        // Note: You must call this again if disconnected!
        List<BluetoothService> services = await _device!.discoverServices();
        services.forEach((service) {
          log("Service: ${service.uuid}");
          if (service.uuid.toByteArray().sublist(0, 4).toString() ==
              ServiceUUID.toString()) {
            service.characteristics.forEach((characteristic) {
              log("Characteristic: ${characteristic.uuid}");

              if (characteristic.uuid.toByteArray().sublist(0, 4).toString() ==
                  CharacteristicUUID.toString()) {
                log("Found characteristic");
                characteristic.setNotifyValue(true);
                characteristic.onValueReceived.listen((value) {
                  log("Received: ${value.map((e) => String.fromCharCode(e)).toString()}");
                });
                characteristic
                    .write([0x41, 0x41, 0x41, 0x41], withoutResponse: true);
              }
            });
            return;
          }
        });
      }
    });
    await _device!.connect();

    // await _device!.disconnect();
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
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextButton(
                onPressed: _scanBluetoothAndConnect, child: const Text("Scan")),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _enableBluetooth,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
