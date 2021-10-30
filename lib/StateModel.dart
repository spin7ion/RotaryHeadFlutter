import 'package:flutter/material.dart';

enum HeadState{
  STATE_WAITING,
  STATE_ROTATING
}

class StateModel extends ChangeNotifier {

  HeadState _state=HeadState.STATE_WAITING;

  double _currentAngle=0;
  double _targetAngle=0;
  num _divisions=2;
  num _index=0;
  bool _connected=false;
  bool _absolute=true;

  double get currentAngle => _currentAngle;
  double get targetAngle => _targetAngle;
  num get divisions => _divisions;
  num get currentIndex => _index;
  HeadState get state => _state;
  bool get connected => _connected;
  bool get absolute => _absolute;

  set currentIndex(num currentIndex) {
    _index=currentIndex;
    notifyListeners();
  }

  set currentAngle(double _a){
    _currentAngle=_a;
    notifyListeners();
  }

  set targetAngle(double _a){
    _targetAngle=_a;
    notifyListeners();
  }

  set state(HeadState _s){
    _state=_s;
    notifyListeners();
  }

  set divisions(num _d){
    _divisions=_d;
    notifyListeners();
  }

  set connected(bool _s){
    _connected=_s;
    notifyListeners();
  }

  set absolute(bool _s){
    _absolute=_s;
    notifyListeners();
  }
}