import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:weather_station/schemas.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen(
      {Key? key,
      required this.device,
      required this.characteristic,
      required this.consumerStream,
      required this.config})
      : super(key: key);

  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  final Stream<String> consumerStream;
  final StationConfig config;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class UserInput {
  String? value;
  bool isEditing;
  UserInput({this.value, this.isEditing = false});
}

class LocalConfig {
  UserInput locationLatitude = UserInput();
  UserInput locationLongitude = UserInput();
  UserInput wifiSsid = UserInput();
  UserInput wifiPassword = UserInput();
  UserInput ethernetIp = UserInput();
  UserInput ethernetSubnet = UserInput();
  UserInput ethernetGateway = UserInput();
  UserInput ethernetDns = UserInput();
  UserInput loraDevEui = UserInput();
  UserInput loraAppEui = UserInput();
  UserInput loraAppKey = UserInput();
  UserInput cellularApn = UserInput();
  UserInput cellularUsername = UserInput();
  UserInput cellularPassword = UserInput();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final initTime = DateTime.now().millisecondsSinceEpoch;
  final LocalConfig localConfig = LocalConfig();
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    // _subscription = widget.consumerStream.listen((event) {
    //   log('Received: $event', name: 'ConfigScreen');
    //   if (event.startsWith("AT+CONFIG=")) {}
    // });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    widget.characteristic
        .write("AT+ALLCONFIG\r\n".codeUnits, withoutResponse: true);
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (widget.config.lastUpdated > initTime) {
        timer.cancel();
      } else {
        widget.characteristic
            .write("AT+ALLCONFIG\r\n".codeUnits, withoutResponse: true);
      }
    });
    // setState(() {
    //   _isLoaded = true;
    // });
  }

  Future<void> _sendPartialMessage(String message) async {
    widget.characteristic.write(message.codeUnits, withoutResponse: true);
  }

  Future<void> _updateConfig(String key, String value) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating device configuration...'),
      ),
    );
    String message = 'AT+CONFIG=$key=$value\r\n';
    const maxMessageLength = 13;
    List<String> messages = [];
    if (message.length > maxMessageLength) {
      int start = 0;
      int end = maxMessageLength;
      while (end < message.length) {
        messages.add(message.substring(start, end));
        start = end;
        end += maxMessageLength;
      }
      messages.add(message.substring(start, message.length));
    } else {
      messages.add(message);
    }
    for (String message in messages) {
      await _sendPartialMessage(message);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _restartDevice() async {
    widget.characteristic
        .write("AT+RESET\r\n".codeUnits, withoutResponse: true);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restarting device, please wait...'),
      ),
    );
  }

  Future<void> _factoryResetDevice() async {
    widget.characteristic
        .write("AT+FACTORYRESET\r\n".codeUnits, withoutResponse: true);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Factory resetting device, please wait...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.device.localName),
        ),
        body: ListenableBuilder(
            listenable: widget.config,
            builder: (BuildContext context, Widget? child) {
              return (widget.config.lastUpdated <= initTime)
                  ? const Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 30),
                        Text('Getting device configuration...'),
                      ],
                    ))
                  : ListView(
                      children: [
                        // Card Location
                        Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0)),
                            child: ExpansionTile(
                              title: const Text('Location'),
                              subtitle: (widget.config.location != null &&
                                      widget.config.location?.latitude !=
                                          null &&
                                      widget.config.location?.longitude != null)
                                  ? Text(
                                      '${widget.config.location?.latitude.toString()}, ${widget.config.location?.longitude.toString()}')
                                  : const Text('No location found'),
                              leading: const Checkbox(
                                value: true,
                                onChanged: null,
                                tristate: true,
                              ),
                              children: [
                                // Checkbox to use GPS module
                                ListTile(
                                  title: const Text('Use GPS'),
                                  subtitle: const Text(
                                      'Get location from GPS module'),
                                  trailing: Checkbox(
                                    value:
                                        (widget.config.location?.useGps != null)
                                            ? widget.config.location?.useGps
                                            : false,
                                    onChanged: (bool? value) {
                                      _updateConfig('location.gps',
                                          (value == false) ? '0' : '1');
                                    },
                                  ),
                                ),
                                (!localConfig.locationLatitude.isEditing)
                                    ?
                                    // Textfield for Latitude
                                    ListTile(
                                        title: const Text('Latitude'),
                                        subtitle: Text(widget
                                                .config.location?.latitude
                                                ?.toString() ??
                                            ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.locationLatitude
                                                  .value = widget
                                                      .config.location?.latitude
                                                      ?.toString() ??
                                                  '';
                                              localConfig.locationLatitude
                                                      .isEditing =
                                                  !localConfig.locationLatitude
                                                      .isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget
                                                .config.location?.latitude
                                                ?.toString()),
                                        onChanged: (String value) {
                                          localConfig.locationLatitude.value =
                                              value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Latitude',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.locationLatitude
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'location.lat',
                                                  localConfig
                                                      .locationLatitude.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                // Textfield for Longitude
                                (!localConfig.locationLongitude.isEditing)
                                    ? ListTile(
                                        title: const Text('Longitude'),
                                        subtitle: Text(widget
                                                .config.location?.longitude
                                                ?.toString() ??
                                            ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.locationLongitude
                                                  .value = widget.config
                                                      .location?.longitude
                                                      ?.toString() ??
                                                  '';
                                              localConfig.locationLongitude
                                                      .isEditing =
                                                  !localConfig.locationLongitude
                                                      .isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget
                                                .config.location?.longitude
                                                ?.toString()),
                                        onChanged: (String value) {
                                          localConfig.locationLongitude.value =
                                              value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Longitude',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.locationLongitude
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'location.lon',
                                                  localConfig
                                                      .locationLongitude.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                              ],
                            )),
                        // Card Wifi
                        Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0)),
                            child: ExpansionTile(
                              title: const Text('Wifi'),
                              subtitle: (widget.config.wifi != null &&
                                      widget.config.wifi?.ssid != null)
                                  ? Text(widget.config.wifi?.connected == true
                                      ? 'Connected to ${widget.config.wifi?.ssid}'
                                      : 'Not connected')
                                  : null,
                              leading: Checkbox(
                                value: (widget.config.wifi?.enabled != null)
                                    ? widget.config.wifi?.enabled
                                    : false,
                                onChanged: (bool? value) {
                                  _updateConfig('wifi.enabled',
                                      (value == false) ? '0' : '1');
                                },
                              ),
                              children: [
                                // Textfield for SSID
                                (!localConfig.wifiSsid.isEditing)
                                    ? ListTile(
                                        title: const Text('SSID'),
                                        subtitle: Text(
                                            widget.config.wifi?.ssid ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.wifiSsid.value =
                                                  widget.config.wifi?.ssid ??
                                                      '';
                                              localConfig.wifiSsid.isEditing =
                                                  !localConfig
                                                      .wifiSsid.isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget.config.wifi?.ssid),
                                        onChanged: (String value) {
                                          localConfig.wifiSsid.value = value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'SSID',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.wifiSsid.isEditing =
                                                    false;
                                                _updateConfig(
                                                  'wifi.ssid',
                                                  localConfig.wifiSsid.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),

                                // Textfield for Password
                                (!localConfig.wifiPassword.isEditing)
                                    ? ListTile(
                                        title: const Text('Password'),
                                        subtitle: Text(
                                            widget.config.wifi?.password ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.wifiPassword.value =
                                                  widget.config.wifi
                                                          ?.password ??
                                                      '';
                                              localConfig
                                                      .wifiPassword.isEditing =
                                                  !localConfig
                                                      .wifiPassword.isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget.config.wifi?.password),
                                        onChanged: (String value) {
                                          localConfig.wifiPassword.value =
                                              value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.wifiPassword
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'wifi.pwd',
                                                  localConfig
                                                      .wifiPassword.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                              ],
                            )),
                        // Card Ethernet
                        Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0)),
                            child: ExpansionTile(
                              title: const Text('Ethernet (DHCP)'),
                              subtitle: (widget.config.ethernet != null)
                                  ? Text(widget.config.ethernet?.connected ==
                                          true
                                      ? 'Connected to ${widget.config.ethernet?.ip}'
                                      : 'Not connected')
                                  : null,
                              leading: Checkbox(
                                value: (widget.config.ethernet?.enabled != null)
                                    ? widget.config.ethernet?.enabled
                                    : false,
                                onChanged: (bool? value) {
                                  _updateConfig('eth.enabled',
                                      (value == false) ? '0' : '1');
                                },
                              ),
                              children: [
                                // Textfield for IP
                                ListTile(
                                  title: const Text('IP'),
                                  subtitle:
                                      Text(widget.config.ethernet?.ip ?? ''),
                                ),
                                // Textfield for Subnet
                                ListTile(
                                  title: const Text('Subnet'),
                                  subtitle:
                                      Text(widget.config.ethernet?.mask ?? ''),
                                ),
                                // Textfield for Gateway
                                ListTile(
                                  title: const Text('Gateway'),
                                  subtitle: Text(
                                      widget.config.ethernet?.gateway ?? ''),
                                ),
                                // Textfield for DNS
                                ListTile(
                                  title: const Text('DNS'),
                                  subtitle:
                                      Text(widget.config.ethernet?.dns ?? ''),
                                ),
                              ],
                            )),
                        // Card LoRaWAN
                        Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0)),
                            child: ExpansionTile(
                              title: const Text('LoRaWAN'),
                              subtitle: (widget.config.lora != null &&
                                      widget.config.lora?.devEui != null)
                                  ? Text(widget.config.lora?.connected == true
                                      ? 'Network joined'
                                      : 'Not connected')
                                  : null,
                              leading: Checkbox(
                                value: (widget.config.lora?.enabled != null)
                                    ? widget.config.lora?.enabled
                                    : false,
                                onChanged: (bool? value) {
                                  _updateConfig('lora.enabled',
                                      (value == false) ? '0' : '1');
                                },
                              ),
                              children: [
                                // Textfield for DevEUI
                                (!localConfig.loraDevEui.isEditing)
                                    ? ListTile(
                                        title: const Text('DevEUI'),
                                        subtitle: Text(
                                            widget.config.lora?.devEui ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.loraDevEui.value =
                                                  widget.config.lora?.devEui ??
                                                      '';
                                              localConfig.loraDevEui.isEditing =
                                                  !localConfig
                                                      .loraDevEui.isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget.config.lora?.devEui),
                                        onChanged: (String value) {
                                          localConfig.loraDevEui.value = value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'DevEUI',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.loraDevEui
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'lora.devEui',
                                                  localConfig.loraDevEui.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                // Textfield for AppEUI
                                (!localConfig.loraAppEui.isEditing)
                                    ? ListTile(
                                        title: const Text('AppEUI'),
                                        subtitle: Text(
                                            widget.config.lora?.appEui ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.loraAppEui.value =
                                                  widget.config.lora?.appEui ??
                                                      '';
                                              localConfig.loraAppEui.isEditing =
                                                  !localConfig
                                                      .loraAppEui.isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget.config.lora?.appEui),
                                        onChanged: (String value) {
                                          localConfig.loraAppEui.value = value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'AppEUI',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.loraAppEui
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'lora.appEui',
                                                  localConfig.loraAppEui.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                // Textfield for AppKey
                                (!localConfig.loraAppKey.isEditing)
                                    ? ListTile(
                                        title: const Text('AppKey'),
                                        subtitle: Text(
                                            widget.config.lora?.appKey ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.loraAppKey.value =
                                                  widget.config.lora?.appKey ??
                                                      '';
                                              localConfig.loraAppKey.isEditing =
                                                  !localConfig
                                                      .loraAppKey.isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget.config.lora?.appKey),
                                        onChanged: (String value) {
                                          localConfig.loraAppKey.value = value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'AppKey',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.loraAppKey
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'lora.appKey',
                                                  localConfig.loraAppKey.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                              ],
                            )),
                        // Card Cellular
                        Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0)),
                            child: ExpansionTile(
                              title: const Text('Cellular'),
                              subtitle: (widget.config.cellular != null &&
                                      widget.config.cellular?.apn != null)
                                  ? Text(widget.config.cellular?.connected ==
                                          true
                                      ? 'Connected to ${widget.config.cellular?.apn}'
                                      : 'Not connected')
                                  : null,
                              leading: Checkbox(
                                value: (widget.config.cellular?.enabled != null)
                                    ? widget.config.cellular?.enabled
                                    : false,
                                onChanged: (bool? value) {
                                  _updateConfig('sim.enabled',
                                      (value == false) ? '0' : '1');
                                },
                              ),
                              children: [
                                // Textfield for APN
                                (!localConfig.cellularApn.isEditing)
                                    ? ListTile(
                                        title: const Text('APN'),
                                        subtitle: Text(
                                            widget.config.cellular?.apn ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.cellularApn.value =
                                                  widget.config.cellular?.apn ??
                                                      '';
                                              localConfig
                                                      .cellularApn.isEditing =
                                                  !localConfig
                                                      .cellularApn.isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget.config.cellular?.apn),
                                        onChanged: (String value) {
                                          localConfig.cellularApn.value = value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'APN',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.cellularApn
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'sim.apn',
                                                  localConfig
                                                      .cellularApn.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                // Textfield for Username
                                (!localConfig.cellularUsername.isEditing)
                                    ? ListTile(
                                        title: const Text('Username'),
                                        subtitle: Text(
                                            widget.config.cellular?.user ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.cellularUsername
                                                  .value = widget
                                                      .config.cellular?.user ??
                                                  '';
                                              localConfig.cellularUsername
                                                      .isEditing =
                                                  !localConfig.cellularUsername
                                                      .isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget.config.cellular?.user),
                                        onChanged: (String value) {
                                          localConfig.cellularUsername.value =
                                              value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Username',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.cellularUsername
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'sim.user',
                                                  localConfig
                                                      .cellularUsername.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                // Textfield for Password
                                (!localConfig.cellularPassword.isEditing)
                                    ? ListTile(
                                        title: const Text('Password'),
                                        subtitle: Text(
                                            widget.config.cellular?.password ??
                                                ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            setState(() {
                                              localConfig.cellularPassword
                                                  .value = widget.config
                                                      .cellular?.password ??
                                                  '';
                                              localConfig.cellularPassword
                                                      .isEditing =
                                                  !localConfig.cellularPassword
                                                      .isEditing;
                                            });
                                          },
                                        ),
                                      )
                                    : TextField(
                                        controller: TextEditingController(
                                            text: widget
                                                .config.cellular?.password),
                                        onChanged: (String value) {
                                          localConfig.cellularPassword.value =
                                              value;
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          contentPadding:
                                              const EdgeInsets.all(15),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.check),
                                            onPressed: () {
                                              setState(() {
                                                localConfig.cellularPassword
                                                    .isEditing = false;
                                                _updateConfig(
                                                  'sim.pwd',
                                                  localConfig
                                                      .cellularPassword.value!,
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                              ],
                            )),
                        OutlinedButton(
                            onPressed: () => _factoryResetDevice(),
                            child: const Text('Factory Reset'),
                            style: OutlinedButton.styleFrom(
                              primary: Colors.red,
                            )),
                        OutlinedButton(
                            onPressed: _restartDevice,
                            child: const Text('Restart Device')),
                        ListTile(
                          title: const Text('Device Name'),
                          subtitle: Text(widget.device.localName),
                        ),
                        ListTile(
                          title: const Text('Station ID'),
                          subtitle: Text(widget.config.stationId ?? ''),
                        ),
                        ListTile(
                          title: const Text('Device ID'),
                          subtitle: Text(widget.device.remoteId.toString()),
                        ),
                        ListTile(
                          title: const Text('Service UUID'),
                          subtitle: Text(
                              widget.characteristic.serviceUuid.toString()),
                        ),
                        ListTile(
                          title: const Text('Characteristic UUID'),
                          subtitle: Text(widget.characteristic.uuid.toString()),
                        ),
                      ],
                    );
            }));
  }
}
