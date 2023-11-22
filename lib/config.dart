import 'package:flutter/material.dart';

class StationConfig {
  static const Title = 'Weather Station';
  static const BLEDeviceName = 'WeatherStation';
  static const List<int> ServiceUUID = [0x00, 0x00, 0xff, 0xe0];
  static const List<int> CharacteristicUUID = [0x00, 0x00, 0xff, 0xe1];
}
