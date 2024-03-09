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

    // TWO TODOS
    // TODO 1. pair dialog appears twice. Here's a fix for that https://github.com/PhilipsHue/flutter_reactive_ble/issues/507#issuecomment-1771086912
    //  also check if the fork we were using did this
    // TODO 2. Have to finish pairing before we can ask for discoverAllServices below
    //  so either case, I start connection and wait for getting paired.
    //    this must fix both issues

    // I pause here and I get two pair requests. The github link does not work.
    print('will wait for bonding');
    bool isPaired = false;
    while (!isPaired) {
      isPaired = await BleBonding().isPaired(id);
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    print('bonded, disconnecting');
    await connectionSubscription.cancel();

    print('will wait for 5');
    await Future<void>.delayed(const Duration(seconds: 5));
    print('will connect again');

    // before pausing at line 89 I thought a disconnect/connect could help. it does not.
    isConnected = false;
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

  }
}
