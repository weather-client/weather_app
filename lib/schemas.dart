import 'package:flutter/foundation.dart';

class LocationConfig {
  bool? useGps;
  bool? connected;
  double? latitude;
  double? longitude;
}

class WifiConfig {
  bool? enabled;
  bool? connected;
  String? ssid;
  String? password;
}

class EthernetConfig {
  bool? enabled;
  bool? connected;
  String? ip;
  String? mask;
  String? gateway;
  String? dns;
}

class LoraConfig {
  bool? enabled;
  bool? connected;
  String? devEui;
  String? appEui;
  String? appKey;
}

class CellularConfig {
  bool? enabled;
  bool? connected;
  String? apn;
  String? user;
  String? password;
}

class StationConfig with ChangeNotifier {
  static const appTitle = 'Weather Station';
  static const bleDeviceName = 'WeatherStation';
  static const List<int> serviceUUID = [0x00, 0x00, 0xff, 0xe0];
  static const List<int> characteristicUUID = [0x00, 0x00, 0xff, 0xe1];
  String? stationId;
  int? sendInterval;
  LocationConfig? location;
  WifiConfig? wifi;
  EthernetConfig? ethernet;
  LoraConfig? lora;
  CellularConfig? cellular;
  int lastUpdated = DateTime.now().millisecondsSinceEpoch;

  StationConfig() {
    location = LocationConfig();
    wifi = WifiConfig();
    ethernet = EthernetConfig();
    lora = LoraConfig();
    cellular = CellularConfig();
  }

  void doneUpdating() {
    lastUpdated = DateTime.now().millisecondsSinceEpoch;

    notifyListeners();
  }

  Map toJson() {
    return {
      'stationId': stationId,
      'sendInterval': sendInterval,
      'location': location,
      'wifi': wifi,
      'ethernet': ethernet,
      'lora': lora,
      'cellular': cellular,
      'lastUpdated': lastUpdated,
    };
  }
}

class Location {
  double? latitude;
  double? longitude;
}

class AirData {
  double? temperature;
  double? humidity;

  AirData({this.temperature, this.humidity});
}

class WeatherData with ChangeNotifier {
  Location location = Location();
  List<double> windSpeeds = [];
  List<String> windDirections = [];
  List<AirData> airDatas = [];
}
