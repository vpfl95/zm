import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';


void main()=>runApp(MyApp());


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE',
      theme: ThemeData(
        primarySwatch: Colors.blue
      ),
      home: MyHomePage(title: 'BLE'),
    );
  }
}


class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();
  final Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();


  @override
  _MyHomePageState createState() => _MyHomePageState();
}


class _MyHomePageState extends State<MyHomePage> {
  BluetoothDevice _connectedDevice;
  List<BluetoothService> _services;
  final _writeController = TextEditingController();
  List<dynamic> notifyValue = new List<dynamic>();



  Timer refreshTimer;

  onRefreshTimer(){
    refreshTimer = new Timer.periodic(Duration(milliseconds: 40), (timer) {
      setState(() {
      });
    });
  }

  offRefreshTimer(){
    refreshTimer.cancel();
  }



  //디바이스 리스트에 추가
  _addDeviceTolist(final BluetoothDevice device){
    if(!widget.devicesList.contains(device)){
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }
  @override
  void initState(){
    super.initState();
    widget.devicesList.clear();
    notifyValue.clear();
    widget.flutterBlue.connectedDevices
    .asStream()
    .listen((List<BluetoothDevice>devices){
      for(BluetoothDevice device in devices){
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results){
      for(ScanResult result in results){
        _addDeviceTolist(result.device);
        print('${result.device.name} found! rssi: ${result.rssi}');
      }
    });
    widget.flutterBlue.startScan();
  }

  ListView _buildListViewOfDevices(){
    List<Container> containers = new List<Container>();
    for(BluetoothDevice device in widget.devicesList){
      containers.add(
        Container(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.name == '' ? '(unkown device)' : device.name,
                    style: TextStyle(fontWeight: FontWeight.bold),),
                  Text(device.id.toString()),
                  ],
                ),
              ),FlatButton(
                color: Colors.blue,
                child: Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  widget.flutterBlue.stopScan();
                  try {
                    await device.connect();
                  } catch (e) {
                    if (e.code != 'already_connected') {
                      throw e;
                    }
                  } finally {
                    _services = await device.discoverServices();
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                },
              )
            ],
          ),
        )
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(
      BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = new List<ButtonTheme>();

    if (characteristic.properties.read) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              color: Colors.blue,
              child: Text('READ', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                var sub = characteristic.value.listen((value) {
                  setState(() {
                    widget.readValues[characteristic.uuid] = value;
                  });
                });
                await characteristic.read();
                sub.cancel();
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.write) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: Text('WRITE', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Write"),
                        content: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _writeController,
                              ),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          FlatButton(
                            child: Text("Send"),
                            onPressed: () {
                              characteristic.write(
                                  utf8.encode(_writeController.value.text));
                              Navigator.pop(context);
                            },
                          ),
                          FlatButton(
                            child: Text("Cancel"),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    });
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.notify) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: Text('NOTIFY', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                onRefreshTimer();
                characteristic.value.listen((value) {
                  widget.readValues[characteristic.uuid] = value;
                });
                await characteristic.setNotifyValue(true);
              },
            ),
          ),
        ),
      );
    }
    return buttons;
  }

  ListView _buildConnectDeviceView() {
    List<Container> containers = new List<Container>();

    for (BluetoothService service in _services) {
      List<Widget> characteristicsWidget = new List<Widget>();
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        characteristic.value.listen((value) {
          print('value = $value');

          notifyValue.add(value);
          //print('length= ${notifyValue.length}');
          //notifyValue.forEach((element) => print('notifyvalue = $element'));
        });
        characteristicsWidget.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(characteristic.uuid.toString(),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: <Widget>[
                    ..._buildReadWriteNotifyButton(characteristic),
                  ],

                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('Value: ' +
                          widget.readValues[characteristic.uuid].toString()),
                    ),
                  ],
                ),
                Divider(),
              ],
            ),
          ),
        );
      }
      containers.add(
        Container(
          child: ExpansionTile(
              title: Text(service.uuid.toString()),
              children: characteristicsWidget),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
       Container(
         height: 300,
//         child:  ListView.builder(
//             itemBuilder: (BuildContext context, int index){
//               return ListTile(title: Text(notifyValue.isEmpty ? '' : '($index) = ${notifyValue[index]}'));
//             }
//         ),
       ),
       SizedBox(
         height: 30
       ),
       new Container(
          child: Column(
            children: <Widget>[
              Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: <Widget>[
              Text(_connectedDevice.name,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                width: 30,
              ),
              FlatButton(
                child: Text("DisConnect",
                  style:(TextStyle(color: Colors.white)),),
                color: Colors.blue,
                onPressed: () async {
                  offRefreshTimer();
                  notifyValue.clear();
                  setState(() {
                    _connectedDevice.disconnect();
                    if(_connectedDevice!=null) {
                      _connectedDevice = null;
                    }

                  });
                },
              ),
            ],
          ),
        ]),
       ),
      ],
    );
  }

  ListView _buildView() {
    if (_connectedDevice != null) {
      return _buildConnectDeviceView();
    }
    return _buildListViewOfDevices();
  }



  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.bluetooth_searching),
            onPressed: (){
              notifyValue.clear();
              widget.flutterBlue.stopScan();
              if (_connectedDevice == null) {
                setState(() {
                  widget.devicesList.clear();
                  widget.flutterBlue.connectedDevices
                      .asStream()
                      .listen((List<BluetoothDevice>devices){
                    for(BluetoothDevice device in devices){
                      _addDeviceTolist(device);
                    }
                  });
                  widget.flutterBlue.scanResults.listen((List<ScanResult> results){
                    for(ScanResult result in results){
                      _addDeviceTolist(result.device);
                      print('connectedDevice :  $_connectedDevice');
                    }
                  });
                  widget.flutterBlue.startScan();
                });
              }
            },
          )
        ],
      ),
      body: _buildView(),
    );
  }
}

