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

class _ConfigScreenState extends State<ConfigScreen> {
  final initTime = DateTime.now().millisecondsSinceEpoch;
  bool _isLoaded = true;
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

    // setState(() {
    //   _isLoaded = true;
    // });
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
                              leading: Checkbox(
                                value: true,
                                onChanged: (bool? value) {},
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
                                    onChanged: (bool? value) {},
                                    tristate: true,
                                  ),
                                ),
                                // Textfield for Latitude
                                ListTile(
                                  title: const Text('Latitude'),
                                  subtitle: Text(widget
                                          .config.location?.latitude
                                          ?.toString() ??
                                      ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                                // Textfield for Longitude
                                ListTile(
                                  title: const Text('Longitude'),
                                  subtitle: Text(widget
                                          .config.location?.longitude
                                          .toString() ??
                                      ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                                // Textfield for Altitude
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
                                onChanged: (bool? value) {},
                                tristate: true,
                              ),
                              children: [
                                // Textfield for SSID
                                ListTile(
                                  title: const Text('SSID'),
                                  subtitle:
                                      Text(widget.config.wifi?.ssid ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                                // Textfield for Password
                                ListTile(
                                  title: const Text('Password'),
                                  subtitle:
                                      Text(widget.config.wifi?.password ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
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
                                onChanged: (bool? value) {},
                                tristate: true,
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
                                onChanged: (bool? value) {},
                                tristate: true,
                              ),
                              children: [
                                // Textfield for DevEUI
                                ListTile(
                                  title: const Text('DevEUI'),
                                  subtitle:
                                      Text(widget.config.lora?.devEui ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                                // Textfield for AppEUI
                                ListTile(
                                  title: const Text('AppEUI'),
                                  subtitle:
                                      Text(widget.config.lora?.appEui ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                                // Textfield for AppKey
                                ListTile(
                                  title: const Text('AppKey'),
                                  subtitle:
                                      Text(widget.config.lora?.appKey ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
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
                                onChanged: (bool? value) {},
                                tristate: true,
                              ),
                              children: [
                                // Textfield for APN
                                ListTile(
                                  title: const Text('APN'),
                                  subtitle:
                                      Text(widget.config.cellular?.apn ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                                // Textfield for Username
                                ListTile(
                                  title: const Text('Username'),
                                  subtitle:
                                      Text(widget.config.cellular?.user ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                                // Textfield for Password
                                ListTile(
                                  title: const Text('Password'),
                                  subtitle: Text(
                                      widget.config.cellular?.password ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),
                                ),
                              ],
                            )),
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
