import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import 'package:rotary_table/SelectBondedDevicePage.dart';
import 'package:rotary_table/StateModel.dart';
import 'package:flutter/services.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPage createState() => _MainPage();
}

class _MainPage extends State<MainPage> {
  BluetoothConnection? connection;
  BluetoothDevice? server;
  bool isConnecting=false;
  bool isDisconnecting=false;

  String _messageBuffer = '';

  final GlobalKey<FormState> _divisionFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _angleFormKey = GlobalKey<FormState>();

  var numTxtContr = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double screenWidth=MediaQuery.of(context).size.width/4;
    //SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return
      Material(child: SafeArea(
          child:Center(child:
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Consumer<StateModel>(
            builder: (context, state, child) {
                return ElevatedButton.icon(
                  onPressed: () async {
                    final BluetoothDevice? selectedDevice =
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return SelectBondedDevicePage(checkAvailability: false);
                        },
                      ),
                    );

                    if (selectedDevice != null) {
                      print('Connect -> selected ' + selectedDevice.address);
                      _connect(selectedDevice);
                    } else {
                      print('Connect -> no device selected');
                    }
                  },
                  icon: state.connected?Icon(Icons.bluetooth_connected):Icon(Icons.bluetooth_outlined),
                  label: Text('Connect'),
              );}),
              Center(child:
              Consumer<StateModel>(
                builder: (context, state, child) {
                  return Row(mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children:[
                    Text(state.currentAngle.toString()),
                    CustomPaint(
                      size: Size.square(screenWidth),
                      painter: WheelPainter(state.divisions, state.currentAngle,state.state)
                    ),
                    Text(state.targetAngle.toString())
                  ]);
                }
              )),
              Form(
                key: _divisionFormKey,
                child: Row(
                  children: [
                    Flexible(child: TextFormField(
                      initialValue: "2",
                      keyboardType: TextInputType.numberWithOptions(decimal:true),
                      decoration: const InputDecoration(
                        labelText: 'Divider',

                      ),
                      onSaved: (val) {
                        Provider.of<StateModel>(context, listen: false).divisions=double.parse(val!);
                      },
                    )),
                    Flexible(child: TextFormField(
                      controller: numTxtContr,
                      keyboardType: TextInputType.numberWithOptions(decimal:true),
                      decoration: const InputDecoration(
                        labelText: 'Num',
                      ),
                      onSaved: (val) {
                        Provider.of<StateModel>(context, listen: false).currentIndex=double.parse(val!);
                      },
                    )),
                    Flexible(child: ElevatedButton(
                      onPressed: () {
                        // Validate will return true if the form is valid, or false if
                        // the form is invalid.
                        if (_divisionFormKey.currentState!.validate()) {
                            _divisionFormKey.currentState!.save();
                        }
                      },
                      child: const Text('Apply'),
                    )),
                  ],
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                ElevatedButton.icon(
                  onPressed: (){
                    changeIndex(-1);
                  },
                  icon: Icon(Icons.navigate_before),
                  label: Text('Previous'),
                ),
                ElevatedButton.icon(
                  onPressed: (){
                    changeIndex(1);
                  },
                  icon: Icon(Icons.navigate_next),
                  label: Text('Next'),
                ),
              ],),
              Form(
                key: _angleFormKey,
                child: Row(
                  children: [
                    Flexible(child: TextFormField(
                      initialValue: "0",
                      keyboardType: TextInputType.numberWithOptions(decimal:true),
                      decoration: const InputDecoration(
                        labelText: 'Custom angle',

                      ),
                      onSaved: (val) {
                        double? angle=double.tryParse(val!);
                        Provider.of<StateModel>(context, listen: false).targetAngle=angle!;
                        sendRotationCommand(angle);
                      },
                    )),

                    Flexible(child: ElevatedButton.icon(
                      icon: Icon(Icons.call_missed_outgoing),
                      onPressed: () {
                        if (_angleFormKey.currentState!.validate()) {
                          _angleFormKey.currentState!.save();
                        }
                      },
                      label: const Text('Go'),
                    )),
                    ElevatedButton.icon(
                      icon: Icon(Icons.exposure_zero),
                      onPressed: () {
                        sendZeroCommand();
                      },
                      label: const Text('Zero'),
                    )
                  ],
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Consumer<StateModel>(
                  builder: (context, state, child) {
                  return Checkbox(value: !state.absolute, onChanged: (bool? val){
                    Provider.of<StateModel>(context, listen: false).absolute=!val!;
                    if(val==true){
                      sendRelCommand();
                    }else{
                      sendAbsCommand();
                    }
                  });}),
                  Text("Relative")
                ]
              )
            ],
          )
      ))
      );
  }

  void _connect(BluetoothDevice selDevice){
    server=selDevice;
    if(server==null)return;
    BluetoothConnection.toAddress(server!.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });
      Provider.of<StateModel>(context, listen: false).connected=true;

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
          Provider.of<StateModel>(context, listen: false).connected=false;
        } else {
          print('Disconnected remotely!');
          Provider.of<StateModel>(context, listen: false).connected=false;
        }
        if (this.mounted) {
          Provider.of<StateModel>(context, listen: false).connected=true;
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
      Provider.of<StateModel>(context, listen: false).connected=false;
    });
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);

    int index = buffer.indexOf(13);
    if (~index != 0) {
      parseStatusString((backspacesCounter > 0
          ? _messageBuffer.substring(
          0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString.substring(0, index)));
      _messageBuffer="";
    /*  setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });*/
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
          0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void parseStatusString(String line){
    print(line);

    List<String>parts=line.split(";");
    if(parts.length<5){
      print("Error strange status");
      return;
    }

    if(parts[0]=="0"){
      Provider
          .of<StateModel>(context, listen: false)
          .state=HeadState.STATE_WAITING;
    }else{
      Provider
          .of<StateModel>(context, listen: false)
          .state=HeadState.STATE_ROTATING;
    }

    double? curAngle=double.tryParse(parts[3]);
    print(parts[3]);
    if(curAngle!=null) {
      Provider
          .of<StateModel>(context, listen: false)
          .currentAngle =curAngle;
    }
  }

  void sendZeroCommand(){
    _sendMessage("G92");
  }

  void sendAbsCommand(){
    _sendMessage("G90");
  }

  void sendRelCommand(){
    _sendMessage("G91");
  }

  void sendRotationCommand(double angle,{double? feedRate}){
    if(Provider.of<StateModel>(context,listen: false).state==HeadState.STATE_WAITING){
      String cmd="G01";

      cmd+="A"+angle.toString();
      if(feedRate!=null){
        cmd+="F"+feedRate.toString();
      }
      _sendMessage(cmd);
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(ascii.encode(text + "\r\n")));
        await connection!.output.allSent;

        /*setState(() {
          //messages.add(_Message(clientID, text));
        });*/
      } catch (e) {
        // Ignore error, but notify state
        //setState(() {});
      }
    }
  }

  void changeIndex(int i) {
    var index=Provider.of<StateModel>(context, listen: false).currentIndex;
    var divider=Provider.of<StateModel>(context, listen: false).divisions;

    index+=i;

    if(index>divider){
      index=1;
    }else if(index<1){
      index=divider;
    }

    numTxtContr.text=index.toString();
    Provider.of<StateModel>(context, listen: false).currentIndex=index;

    double tAngle=360/divider*(index-1);
    //sendAbsCommand();
    Provider.of<StateModel>(context, listen: false).targetAngle=tAngle;
    sendRotationCommand(tAngle);

  }

}

class WheelPainter extends CustomPainter{
  num divisions=1;
  double angle=0;
  HeadState state=HeadState.STATE_WAITING;

  WheelPainter(this.divisions,this.angle,this.state);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..color=this.state==HeadState.STATE_WAITING?Colors.amber:Colors.red
      ..strokeWidth=1;

    final shapeBounds = Rect.fromLTRB(0, 0, size.width, size.height);

    canvas.drawCircle(shapeBounds.center, shapeBounds.width/2, paint);
    canvas.drawLine(Offset(shapeBounds.right+10,shapeBounds.center.dy+10), Offset(shapeBounds.right-10+10,shapeBounds.center.dy), paint);
    canvas.drawLine(Offset(shapeBounds.right+10,shapeBounds.center.dy-10), Offset(shapeBounds.right-10+10,shapeBounds.center.dy), paint);
    canvas.translate(shapeBounds.center.dx, shapeBounds.center.dy);
    canvas.rotate(angle/360*pi);
    for (int i = 0; i < divisions; i++) {
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: shapeBounds.width/2),
          i*2*pi/divisions, (i+1)*2*pi/divisions, true, paint);
    }
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) {
    return divisions!=oldDelegate.divisions || angle!=oldDelegate.angle || state!=oldDelegate.state;
  }

}

