import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:audioplayers/audio_cache.dart';

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
  BluetoothDevice latestDevice;
  //BluetoothDeviceState deviceState;
  List<BluetoothService> _services;
  final _writeController = TextEditingController();
  List<dynamic> notifyValue = new List<dynamic>();
  int notifylength = 0;
  var isSelected2 = [false, true];
  bool timerON;
  AudioCache player = new AudioCache();
  bool notify_flag;
  Timer refreshTimer;
  final Stream<int> stream = Stream.periodic(Duration(seconds: 1), (int x) => x); // 1초에 한번씩 업데이트

  onRefreshTimer(){
    timerON=true;
    refreshTimer = new Timer.periodic(Duration(milliseconds: 40), (timer) {
      setState(() {
      });
    });
  }

  offRefreshTimer(){
    timerON=false;
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
  //nosound mp3 재생
  play() async{
    const alarmAudioPath = "test.wav";
    const noSound = "nosound.mp3";
    player.loop(alarmAudioPath);
    player.loop(noSound);
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
    play();
  }

  ListView _buildListViewOfDevices(){
    List<Container> containers = new List<Container>();
    setState(() {});

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
                ),
                FlatButton(
                  color: Colors.blue,
                  child: Text(
                    'Connect',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    onRefreshTimer();

                    widget.flutterBlue.stopScan();
                    try {
                      await device.connect(autoConnect: false);
                    } catch (e) {
                      if (e.code != 'already_connected') {
                        throw e;
                      }
                    } finally {
                      _services = await device.discoverServices();
                    }
                    setState(() {
                      _connectedDevice = device;
                      latestDevice = device;
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
//            child: StreamBuilder<int>(
//              stream: stream,
//              builder: (BuildContext context, AsyncSnapshot<int> snapshot){
//                return RaisedButton(
//                  child: Text('NOTIFY', style: TextStyle(color: Colors.white)),
//                  onPressed: () async {
//                    //onRefreshTimer();
//                    notify_flag=true;
//                    characteristic.value.listen((value) {
//                      widget.readValues[characteristic.uuid] = value;
//                      if (isSelected2[0] == true) {
//                        notifyValue.add(value);
//                      }
//                    });
//                    await characteristic.setNotifyValue(true);
//                    //setState(() {});
//                  },
//                );
//              }
//            ),
            child: RaisedButton(
              child: Text('NOTIFY', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                //onRefreshTimer();
                notify_flag=true;
                characteristic.value.listen((value) {
                  widget.readValues[characteristic.uuid] = value;
                  if (isSelected2[0] == true) {
                    notifyValue.add(value);
                  }
                });
                await characteristic.setNotifyValue(true);
                //setState(() {});
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
        StreamBuilder<BluetoothDeviceState>(
          stream: latestDevice.state,
          initialData: BluetoothDeviceState.connecting,
          builder: (c, snapshot) {
           // deviceState = snapshot.data;
            if(snapshot.data==BluetoothDeviceState.disconnected){
              //offRefreshTimer();
              latestDevice.connect();
            }
//            if(snapshot.data==BluetoothDeviceState.connecting){
//              //onRefreshTimer();
//
//            }
            return ListTile(
            leading: (snapshot.data == BluetoothDeviceState.connected)
                ? Icon(Icons.bluetooth_connected)
                : Icon(Icons.bluetooth_disabled),
            title: Text(
                'Device is ${snapshot.data.toString().split('.')[1]}.'),
            subtitle: Text('${latestDevice.id}'),
            trailing: StreamBuilder<bool>(
              stream: latestDevice.isDiscoveringServices,
              initialData: false,
              builder: (c, snapshot) => IndexedStack(
                index: snapshot.data ? 1 : 0,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: () async {
                      await latestDevice.discoverServices();
                      //print('deviceState = ${deviceState.toString().split('.')[1]}, latestDevice = ${latestDevice.name}');
                      },
                  ),
                  IconButton(
                    icon: SizedBox(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.grey),
                      ),
                      width: 18.0,
                      height: 18.0,
                    ),
                    onPressed: null,
                  )
                ],
              ),
            ),
          );
         }
        ),
        Divider(),
        ...containers,
        Container(
          height: 150,
          child:  ListView.builder(
              itemCount: notifyValue.length,
              itemBuilder: (BuildContext context, int index){
                return ListTile(title: Text(notifyValue.isEmpty ? '' : '($index) = ${notifyValue[index]}'));
              }
          ),
        ),
        SizedBox(
            height: 10
        ),
        Container(
          child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text("Listlength = $notifylength"),
                  ],
                ),
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
                        notify_flag=false;
                        notifyValue.clear();
                        _connectedDevice.disconnect();

                        setState(() {
                          if(_connectedDevice!=null) {
                            _connectedDevice = null;
                          }
                          //deviceState=BluetoothDeviceState.disconnected;
                          latestDevice=null;
                        });
                      },
                    ),
                    SizedBox(
                      width: 30,
                    ),
                    ToggleButtons(
                      children: [
                        Icon(Icons.play_arrow),
                        Icon(Icons.stop),
                      ],
                      onPressed: (int index) {
                        setState(() {
                          for (int buttonIndex = 0; buttonIndex < isSelected2.length; buttonIndex++) {
                            if (buttonIndex == index) {
                              isSelected2[buttonIndex] = true;
                            } else {
                              isSelected2[buttonIndex] = false;
                            }
                          }
                        });
                        print(isSelected2[0]);
                        print(isSelected2);
                      },
                      isSelected: isSelected2,
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
    notifylength=notifyValue.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.bluetooth_searching),
            onPressed: (){
              widget.flutterBlue.stopScan();
              notifyValue.clear();
              widget.devicesList.clear();
              FlutterBlue.instance.startScan();
//
            },
          )
        ],
      ),
      body: _buildView(),
    );
  }
}