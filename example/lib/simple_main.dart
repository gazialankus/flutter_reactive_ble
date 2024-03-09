import 'dart:async';

import 'package:ble_bonding/ble_bonding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

Future<void> main() async {
  runApp(const MainApp());
}


class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: MainPage());
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _run,
                child: const Text('run'),
              ),
            ],
          ),
        ),
      );

  Future<void> _run() async {
    final ble = FlutterReactiveBle();

    await ble.statusStream.firstWhere((e) => e == BleStatus.ready);

    final idCompleter = Completer<String>();
    final scanSubscription =
        ble.scanForDevices(withServices: []).listen((event) {
      if (event.id.toLowerCase().endsWith('7c:7e')) {
        if (event.connectable == Connectable.available) {
          idCompleter.complete(event.id);
        }
      }
    });

    final id = await idCompleter.future;
    await scanSubscription.cancel(); // TODO so this could be await for?


    final bondingState = await BleBonding().getBondingState(id);

    if (bondingState != BleBondingState.bonded) {
      print('was not bonded, is bonding');
      await BleBonding().bond(id);
      // works without this wait just fine
      // await Future<void>.delayed(const Duration(seconds: 5));
    }

    print('will connect');
    var isConnected = false;

    late StreamSubscription<ConnectionStateUpdate> connectionSubscription;
    while (!isConnected) {
      final connectedCompleter = Completer<bool>();
      connectionSubscription =
          ble.connectToDevice(id: id).listen((event) {
        if (event.deviceId != id) {
          print('id of other device, weird ${event.deviceId}');
          return;
        }
        if (event.failure != null) {
          print('connection failure ${event.connectionState} ${event.failure}');
        }
        if (event.connectionState == DeviceConnectionState.connected) {
          connectedCompleter.complete(true);
        } else if (event.connectionState ==
            DeviceConnectionState.disconnected) {
          connectedCompleter.complete(false);
        }
      });

      isConnected = await connectedCompleter.future;
      // this disconnects the device
      // await connectionSubscription.cancel();
    }


    await ble.discoverAllServices(id);
    final services = await ble.getDiscoveredServices(id);
    print('GOT SERVICES');
    print(services);

    await connectionSubscription.cancel();
  }
}
