import 'dart:js_interop';
import 'package:archbtw_sh/games/gamepad_poller.dart';

@JS('navigator.getGamepads')
external JSArray<_JSGamepad?>? _getGamepads();

extension type _JSGamepad._(JSObject _) implements JSObject {
  external bool get connected;
  external String get id;
  external JSArray<JSNumber> get axes;
  external JSArray<_JSGamepadButton> get buttons;
}

extension type _JSGamepadButton._(JSObject _) implements JSObject {
  external bool get pressed;
  external double get value;
}

GamepadInputState pollBrowserGamepad() {
  try {
    final JSArray<_JSGamepad?>? gamepads = _getGamepads();
    if (gamepads == null) return GamepadInputState.disconnected;
    final List<_JSGamepad?> list = gamepads.toDart;
    for (final _JSGamepad? pad in list) {
      if (pad != null && pad.connected) {
        final List<JSNumber> axes = pad.axes.toDart;
        final List<_JSGamepadButton> buttons = pad.buttons.toDart;

        double ax = axes.isNotEmpty ? axes[0].toDartDouble : 0.0;
        double ay = axes.length > 1 ? axes[1].toDartDouble : 0.0;

        bool btn(int idx) =>
            idx < buttons.length &&
            (buttons[idx].pressed || buttons[idx].value > 0.5);

        // D-Pad fallback (Standard Gamepad mapping: 12=Up, 13=Down, 14=Left, 15=Right)
        if (btn(14)) ax = -1.0;
        if (btn(15)) ax = 1.0;
        if (btn(12)) ay = -1.0;
        if (btn(13)) ay = 1.0;

        if (ax.abs() < 0.18) ax = 0.0;
        if (ay.abs() < 0.18) ay = 0.0;

        return GamepadInputState(
          connected: true,
          id: pad.id,
          axisX: ax.clamp(-1.0, 1.0),
          axisY: ay.clamp(-1.0, 1.0),
          jumpPressed: btn(0), // A / Cross
          punchPressed: btn(2), // X / Square
          kickPressed: btn(1), // B / Circle
          chordPressed: btn(3) || btn(5), // Y / Triangle or RB
          webPressed: btn(4) || btn(6) || btn(7), // LB / LT / RT
          mountPressed: btn(8) || btn(9), // Select / Start
        );
      }
    }
  } catch (_) {
    // Ignore browser gamepad security/availability exceptions
  }
  return GamepadInputState.disconnected;
}
