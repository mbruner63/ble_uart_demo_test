import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:location_permissions/location_permissions.dart';
import 'dart:io' show Platform;
import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';

// This flutter app demonstrates an usage of the flutter_reactive_ble flutter plugin
// This app works only with BLE devices which advertise with a Nordic UART Service (NUS) UUID
Uuid _UART_UUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_RX = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_TX = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
String myBuffer = '';
String myFile = "zcm.txt";


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter_reactive_ble example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter_reactive_ble UART example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> _foundBleUARTDevices = [];
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late Stream<ConnectionStateUpdate> _currentConnectionStream;
  late StreamSubscription<ConnectionStateUpdate> _connection;
  late QualifiedCharacteristic _txCharacteristic;
  late QualifiedCharacteristic _rxCharacteristic;
  late Stream<List<int>> _receivedDataStream;
  late TextEditingController _dataToSendText;
  bool _scanning = false;
  bool _connected = false;
  bool inFile = false;
  String _logTexts = "";
  List<String> _receivedData = [];
  int _numberOfMessagesReceived = 0;

  void initState() {
    super.initState();
    _dataToSendText = TextEditingController();
  }

  void refreshScreen() {
    setState(() {});
  }

  void _sendData() async {
  var files = ["zcmDl();","pvtDl();"];
  for ( var i = 0 ; i < files.length ; i++ )
  {
      var file = files[i];
      file += '\n';
      myBuffer = '';
      print("sending=> " + file);
  await flutterReactiveBle.writeCharacteristicWithResponse(_rxCharacteristic,
      value: file.codeUnits);
  };
  }

//TODO  add a filter to only capture text between < and >.  For
  // Example "<abcd>" would only add "abcd" to mybuffer.
  // need a state variable (inside_brackets).  If false then looking for
  // '<'.  If true, routing all strings to myBuffer until a '>' is found
  // Remember data is a list<int>  should convert to string first.
  //  Very unlikely that a '<' and '>' will been in one session of data.
  void onNewReceivedData (List<int> data) async {
    _numberOfMessagesReceived += 1;
    String testStr = String.fromCharCodes(data);
    for (var i = 0; i < data.length; i++) {
      var character = data[i];
      var stringCharacter = String.fromCharCode(character);
      if (!inFile) {
        if (stringCharacter == "<") {
          print("found <");
          inFile = true;
        }
      } else {
        if (stringCharacter == ">") {
          inFile = false;
          print("found >");
          print(myBuffer);
          await writeFile();
          readFile();
            if (myFile == "zcm.txt") {
              myFile = "demo.pvt";
            }
        } else {
          myBuffer = myBuffer + stringCharacter;
        }
      }
    }
    refreshScreen();
  }

  void _disconnect() async {
    await _connection.cancel();
    _connected = false;
    refreshScreen();
  }

  void _stopScan() async {
    await _scanStream.cancel();
    _scanning = false;
    refreshScreen();
  }

  //TODO FILE CREATION

  Future<String?> get _localPath async {
    WidgetsFlutterBinding.ensureInitialized();
    //final directory = await getApplicationDocumentsDirectory();
    final Directory? directory = await getExternalStorageDirectory();

    return directory?.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    print('$path/$myFile');
    return File('$path/$myFile');
  }

  Future<bool> readFile() async {
    try {
      final file = await _localFile;
      print("inside readFile");
      // Read the file
      final contents = await file.readAsString();
      print("here is the file contents=============================");
      print(contents);
      print("end file contents=============================");
      return true;
    } catch (e) {
      // If encountering an error, return 0
      print("catch in readFile");
      return false;
    }
  }

  Future<File> writeFile() async {
    final file = await _localFile;
    try {
      await file.delete;
    } catch (e) {
      print(e);
    }
    print("writing file "+myFile);
    try {
      // force a file creation
      file.writeAsStringSync("test line.");
      file.writeAsStringSync(myBuffer + "\r\n", mode: FileMode.append);
    } catch (e) {
      print("error writing file");
    }

      final path = await _localPath;
      List<String> myattachment = ['$path/zcm.txt','$path/demo.pvt'];
    if ( myFile == 'demo.pvt') {
      print("Attachements for email");
      print(myattachment);
      final Email email = Email(
        body: 'test',
        subject: 'test',
        recipients: ["marty@bruner-consulting.com"],
        attachmentPaths: myattachment,
        isHTML: false,
      );
      try {
        await FlutterEmailSender.send(email);
        print('success');
      } catch (error) {
        print(error.toString());
      }
    }
    // Write the file
    return file;
  }

  Future<void> showNoPermissionDialog() async => showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) => AlertDialog(
      title: const Text('No location permission '),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            const Text('No location permission granted.'),
            const Text(
                'Location permission is required for BLE to function.'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Acknowledge'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );

  void _startScan() async {
    bool goForIt = false;
    PermissionStatus permission;
    if (Platform.isAndroid) {
      permission = await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.granted) goForIt = true;
    } else if (Platform.isIOS) {
      goForIt = true;
    }
    if (goForIt) {
      //TODO replace True with permission == PermissionStatus.granted is for IOS test
      _foundBleUARTDevices = [];
      _scanning = true;
      refreshScreen();
      _scanStream = flutterReactiveBle
          .scanForDevices(withServices: [_UART_UUID]).listen((device) {
        if (_foundBleUARTDevices.every((element) => element.id != device.id)) {
          _foundBleUARTDevices.add(device);
          refreshScreen();
        }
      }, onError: (Object error) {
        _logTexts = "${_logTexts}ERROR while scanning:$error \n";
        refreshScreen();
      });
    } else {
      await showNoPermissionDialog();
    }
  }

  void onConnectDevice(index) {
    _currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
      id: _foundBleUARTDevices[index].id,
      prescanDuration: Duration(seconds: 1),
      withServices: [_UART_UUID, _UART_RX, _UART_TX],
    );
    _logTexts = "";
    refreshScreen();
    _connection = _currentConnectionStream.listen((event) {
      var id = event.deviceId.toString();
      switch (event.connectionState) {
        case DeviceConnectionState.connecting:
          {
            _logTexts = "${_logTexts}Connecting to $id\n";
            break;
          }
        case DeviceConnectionState.connected:
          {
            _connected = true;
            _logTexts = "${_logTexts}Connected to $id\n";
            _numberOfMessagesReceived = 0;
            _receivedData = [];
            _txCharacteristic = QualifiedCharacteristic(
                serviceId: _UART_UUID,
                characteristicId: _UART_TX,
                deviceId: event.deviceId);
            _receivedDataStream =
                flutterReactiveBle.subscribeToCharacteristic(_txCharacteristic);
            _receivedDataStream.listen((data) {
              onNewReceivedData(data);
            }, onError: (dynamic error) {
              _logTexts = "${_logTexts}Error:$error$id\n";
            });
            _rxCharacteristic = QualifiedCharacteristic(
                serviceId: _UART_UUID,
                characteristicId: _UART_RX,
                deviceId: event.deviceId);
            break;
          }
        case DeviceConnectionState.disconnecting:
          {
            _connected = false;
            _logTexts = "${_logTexts}Disconnecting from $id\n";
            break;
          }
        case DeviceConnectionState.disconnected:
          {
            _logTexts = "${_logTexts}Disconnected from $id\n";
            break;
          }
      }
      refreshScreen();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
    ),
    body: Center(
      child: ListView(
        shrinkWrap: true,
        //mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const Text("BLE UART Devices found:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 2)),
              height: 100,
              child: ListView.builder(
                  itemCount: _foundBleUARTDevices.length,
                  itemBuilder: (context, index) => Card(
                      child: ListTile(
                        dense: true,
                        enabled: !((!_connected && _scanning) ||
                            (!_scanning && _connected)),
                        trailing: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            (!_connected && _scanning) ||
                                (!_scanning && _connected)
                                ? () {}
                                : onConnectDevice(index);
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            padding:
                            const EdgeInsets.symmetric(vertical: 4.0),
                            alignment: Alignment.center,
                            child: const Icon(
                                Icons.bluetooth_connected_outlined),
                          ),
                        ),
                        subtitle: Text(_foundBleUARTDevices[index].id),
                        title: Text(
                            "$index: ${_foundBleUARTDevices[index].name}"),
                      )))),
          const Text("Status messages:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              width: 1400,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 2)),
              height: 90,
              child: Scrollbar(
                  child: SingleChildScrollView(child: Text(_logTexts)))),
          const Text("Received data:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              width: 1400,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 2)),
              height: 90,
              child: Text(_receivedData.join("\n"))),
          const Text("Send message:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 2)),
              child: Row(children: <Widget>[
                Expanded(
                    child: TextField(
                      enabled: _connected,
                      controller: _dataToSendText,
                      decoration: const InputDecoration(
                          border: InputBorder.none, hintText: 'Enter a string'),
                    )),
                ElevatedButton(
                    child: Icon(
                      Icons.send,
                      color: _connected ? Colors.blue : Colors.grey,
                    ),
                    onPressed: _connected ? _sendData : () {}),
              ]))
        ],
      ),
    ),
    persistentFooterButtons: [
      Container(
        height: 35,
        child: Column(
          children: [
            if (_scanning)
              const Text("Scanning: Scanning")
            else
              const Text("Scanning: Idle"),
            if (_connected)
              const Text("Connected")
            else
              const Text("disconnected."),
          ],
        ),
      ),
      ElevatedButton(
        onPressed: !_scanning && !_connected ? _startScan : () {},
        child: Icon(
          Icons.play_arrow,
          color: !_scanning && !_connected ? Colors.blue : Colors.grey,
        ),
      ),
      ElevatedButton(
          onPressed: _scanning ? _stopScan : () {},
          child: Icon(
            Icons.stop,
            color: _scanning ? Colors.blue : Colors.grey,
          )),
      ElevatedButton(
          onPressed: _connected ? _disconnect : () {},
          child: Icon(
            Icons.cancel,
            color: _connected ? Colors.blue : Colors.grey,
          ))
    ],
  );
}
