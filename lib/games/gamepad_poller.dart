import 'package:archbtw_sh/games/gamepad_poller_stub.dart'
    if (dart.library.js_interop) 'package:archbtw_sh/games/gamepad_poller_web.dart';

class GamepadInputState {
  final bool connected;
  final String id;
  final double axisX;
  final double axisY;
  final bool jumpPressed;
  final bool punchPressed;
  final bool kickPressed;
  final bool chordPressed;
  final bool webPressed;
  final bool mountPressed;

  const GamepadInputState({
    this.connected = false,
    this.id = '',
    this.axisX = 0.0,
    this.axisY = 0.0,
    this.jumpPressed = false,
    this.punchPressed = false,
    this.kickPressed = false,
    this.chordPressed = false,
    this.webPressed = false,
    this.mountPressed = false,
  });

  static const GamepadInputState disconnected = GamepadInputState();
}

GamepadInputState pollGamepadState() => pollBrowserGamepad();

