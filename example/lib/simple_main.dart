import 'dart:async';

import 'package:ble_bonding/ble_bonding.dart';
import 'package:flutter/cupertino.dart';
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

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _run,
                child: const Text('run'),
              ),
              Expanded(
                child: ListView(
                  children: logLines.map((e) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(e),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      );

  final logLines = <String>[];

  void addLog(String s) {
    final out = '${DateTime.now()} $s';
    print(out);
    setState(() {
      logLines.add(out);
    });
  }

  Future<void> _run() async {
    final ble = FlutterReactiveBle();
    addLog('RUN FlutterReactiveBle');

    await waitUntilBleIsReady(ble);
    addLog('RUN Ble is ready');

    final id = await scanAndGetId(ble);
    addLog('RUN scanned and got $id');
    // final id = 'E2:92:8E:ED:7C:7E';

    // addLog('bypass bonding. watch thinks it is bonded but phone does not.');
    // TODO after unpairing from phone it gets stuck here. if times out, should tell user to reboot watch.
    await waitUntilBonded(id);
    addLog('RUN is bonded');

    final connectionSubscription = await waitUntilConnected(ble, id);
    addLog('RUN is connected');

    // added later
    await waitUntilBonded(id);
    addLog('RUN is bonded 2');

    await discoverAndPrintServices(ble, id);
    addLog('Discovered services');

    const secs = 60;
    addLog('Waiting for $secs secs to see if we can keep connection');
    await Future<void>.delayed(const Duration(seconds: secs));
    addLog('$secs secs over');

    await connectionSubscription.cancel();
    addLog('Disconnected');
  }

  Future<void> discoverAndPrintServices(FlutterReactiveBle ble, String id) async {
    await ble.discoverAllServices(id);
    final services = await ble.getDiscoveredServices(id);
    print('GOT SERVICES');
    print(services);
  }

  Future<StreamSubscription<ConnectionStateUpdate>> waitUntilConnected(FlutterReactiveBle ble, String id) async {
    print('will connect');
    var isConnected = false;

    late StreamSubscription<ConnectionStateUpdate> connectionSubscription;
    while (!isConnected) {
      final connectedCompleter = Completer<bool>();
      connectionSubscription =
          ble.connectToDevice(id: id).listen((event) {
          addLog('connection event $event');
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
    return connectionSubscription;
  }

  Future<void> waitUntilBonded(String id) async {
    var bondingState = await BleBonding().getBondingState(id);

    if (bondingState == BleBondingState.bonded) {
      addLog('Already bonded');
    }
    while (bondingState != BleBondingState.bonded) {
      addLog('was not bonded, is bonding');
      await BleBonding().bond(id);
      addLog('tried to bond');

      bondingState = await BleBonding().getBondingState(id);
      addLog('bondingState $bondingState');
      // works without this wait just fine
      // await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<String> scanAndGetId(FlutterReactiveBle ble) async {
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
    // so this could be await for? yes but would not work in real use.
    // we're not looking for one device there.
    await scanSubscription.cancel();
    return id;
  }

  Future<void> waitUntilBleIsReady(FlutterReactiveBle ble) async {
    await ble.statusStream.firstWhere((e) {
      addLog(e.toString());
      return e == BleStatus.ready;
    });
  }
}
