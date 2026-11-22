import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expr = '';
  String _result = '0';

  static const String _ops = '+−×÷';
  static final RegExp _digits = RegExp(r'^\d+$');

  static const List<List<String>> _rows = [
    ['C', '⌫', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['00', '0', '.', '='],
  ];

  bool _isOp(String c) => _ops.contains(c);
  String get _last => _expr.isEmpty ? '' : _expr[_expr.length - 1];

  void _onTap(String key) {
    setState(() {
      if (key == 'C') {
        _expr = '';
        _result = '0';
      } else if (key == '⌫') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        _preview();
      } else if (key == '=') {
        final r = _evaluate(_expr);
        if (r == null) {
          _result = 'Error';
        } else {
          _result = r;
          _expr = r;
        }
      } else {
        _append(key);
        _preview();
      }
    });
  }

  void _append(String key) {
    if (_digits.hasMatch(key)) {
      if (_last == '%') return;
      _expr += key;
    } else if (_isOp(key)) {
      if (_expr.isEmpty) {
        if (key == '−') _expr = key;
        return;
      }
      if (_isOp(_last)) {
        if (_expr.length == 1) return; // only a leading minus
        _expr = _expr.substring(0, _expr.length - 1) + key;
      } else if (_last != '.') {
        _expr += key;
      }
    } else if (key == '.') {
      final current = _currentNumber();
      if (current.contains('.') || _last == '%') return;
      _expr += current.isEmpty ? '0.' : '.';
    } else if (key == '%') {
      if (_digits.hasMatch(_last)) _expr += '%';
    }
  }

  String _currentNumber() {
    var i = _expr.length - 1;
    while (i >= 0 && !_isOp(_expr[i])) {
      i--;
    }
    return _expr.substring(i + 1);
  }

  void _preview() {
    var e = _expr;
    while (e.isNotEmpty && (_isOp(e[e.length - 1]) || e.endsWith('.'))) {
      e = e.substring(0, e.length - 1);
    }
    if (e.isEmpty) {
      _result = '0';
      return;
    }
    final r = _evaluate(e);
    if (r != null) _result = r;
  }

  String? _evaluate(String e) {
    if (e.isEmpty) return '0';
    try {
      final v = _Parser(e).parse();
      if (v.isNaN || v.isInfinite) return null;
      return _format(v);
    } catch (_) {
      return null;
    }
  }

  String _format(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    var s = v.toStringAsPrecision(12);
    if (s.contains('.') && !s.contains('e')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  // ---------------------------------------------------------------------------
  // Keyboard support (desktop / web / tablets with a keyboard)
  // ---------------------------------------------------------------------------

  static const Map<String, String> _charKeys = {
    '+': '+',
    '-': '−',
    '*': '×',
    'x': '×',
    'X': '×',
    '/': '÷',
    '%': '%',
    '.': '.',
    ',': '.',
    '=': '=',
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    String? key;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      key = '=';
    } else if (k == LogicalKeyboardKey.backspace) {
      key = '⌫';
    } else if (k == LogicalKeyboardKey.escape ||
        k == LogicalKeyboardKey.delete) {
      key = 'C';
    } else {
      final c = event.character;
      if (c != null && c.length == 1) {
        key = RegExp(r'^\d$').hasMatch(c) ? c : _charKeys[c];
      }
    }
    if (key == null) return KeyEventResult.ignored;
    _onTap(key);
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------
  // Responsive layout
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final landscape = c.maxWidth > c.maxHeight * 1.15 &&
                  c.maxWidth >= 480;
              // Cap the width so it stays comfortable on tablets / monitors.
              final maxW = landscape ? 1100.0 : 520.0;
              final pad = (c.maxWidth * 0.03).clamp(8.0, 24.0);
              final w = (c.maxWidth < maxW ? c.maxWidth : maxW) - pad * 2;
              final h = c.maxHeight - pad * 2;

              final keypad = _Keypad(rows: _rows, onTap: _onTap, isOp: _isOp);
              final display = _Display(expr: _expr, result: _result);

              final Widget content;
              if (landscape) {
                // Phones in landscape, tablets, desktop windows:
                // display on the left, keypad on the right.
                final keypadW = (w * 0.55).clamp(0.0, h * 1.25) - pad;
                content = Row(
                  children: [
                    Expanded(child: display),
                    SizedBox(width: pad),
                    SizedBox(width: keypadW, child: keypad),
                  ],
                );
              } else {
                // Portrait: display on top, keypad below. Keys stay roughly
                // square, but the keypad never takes more than 68% of height.
                final keypadH = (w * 1.25).clamp(0.0, h * 0.68) - pad / 2;
                content = Column(
                  children: [
                    Expanded(child: display),
                    SizedBox(height: pad / 2),
                    SizedBox(height: keypadH, child: keypad),
                  ],
                );
              }

              return Center(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: SizedBox(width: w, height: h, child: content),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Expression + live result. Font sizes scale with the available space.
class _Display extends StatelessWidget {
  final String expr;
  final String result;

  const _Display({required this.expr, required this.result});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Total text height ≈ result*1.2 + expr*1.5 (+16 padding); make sure
        // it always fits, even in very short windows.
        final fit = ((c.maxHeight - 24) / 2.1).clamp(1.0, double.infinity);
        final resultSize = (c.maxHeight * 0.38).clamp(28.0, 96.0).clamp(1.0, fit);
        final exprSize = resultSize * 0.45;
        return Container(
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Scrolls horizontally and stays pinned to the end, so the most
              // recently typed part of a long expression is always visible.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Text(
                  expr,
                  maxLines: 1,
                  style: TextStyle(fontSize: exprSize, color: Colors.white54),
                ),
              ),
              SizedBox(height: exprSize * 0.3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  result,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: resultSize,
                    fontWeight: FontWeight.w300,
                    color: result == 'Error' ? Colors.redAccent : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A grid of keys that fills whatever box it is given.
class _Keypad extends StatelessWidget {
  final List<List<String>> rows;
  final void Function(String) onTap;
  final bool Function(String) isOp;

  const _Keypad({required this.rows, required this.onTap, required this.isOp});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cellW = c.maxWidth / rows.first.length;
        final cellH = c.maxHeight / rows.length;
        final gap = (cellW < cellH ? cellW : cellH) * 0.07;
        return Column(
          children: [
            for (final row in rows)
              Expanded(
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(gap),
                          child: _KeyButton(
                            label: key,
                            onTap: () => onTap(key),
                            colors: _colorsFor(key),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  (Color bg, Color fg) _colorsFor(String key) {
    if (key == '=' || isOp(key)) return (Colors.orange, Colors.white);
    if (key == 'C' || key == '⌫' || key == '%') {
      return (const Color(0xFFA5A5A5), Colors.black);
    }
    return (const Color(0xFF333333), Colors.white);
  }
}

/// Circle when the cell is square, pill when it is wider/taller.
/// The label scales with the button size.
class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final (Color bg, Color fg) colors;

  const _KeyButton({
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(side / 2),
        );
        return Material(
          color: colors.$1,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(side * 0.12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: side * 0.4,
                      fontWeight: FontWeight.w500,
                      color: colors.$2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small math parser: supports + − × ÷, %, decimals, and a leading minus.
class _Parser {
  final String s;
  int i = 0;

  _Parser(this.s);

  double parse() {
    final v = _sum();
    if (i != s.length) throw const FormatException('Unexpected input');
    return v;
  }

  double _sum() {
    var v = _product();
    while (i < s.length && (s[i] == '+' || s[i] == '−')) {
      final op = s[i++];
      final r = _product();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double _product() {
    var v = _factor();
    while (i < s.length && (s[i] == '×' || s[i] == '÷')) {
      final op = s[i++];
      final r = _factor();
      if (op == '÷') {
        if (r == 0) throw UnsupportedError('Division by zero');
        v = v / r;
      } else {
        v = v * r;
      }
    }
    return v;
  }

  double _factor() {
    if (i < s.length && s[i] == '−') {
      i++;
      return -_factor();
    }
    final start = i;
    while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
      i++;
    }
    if (start == i) throw const FormatException('Number expected');
    var v = double.parse(s.substring(start, i));
    while (i < s.length && s[i] == '%') {
      i++;
      v = v / 100;
    }
    return v;
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}
