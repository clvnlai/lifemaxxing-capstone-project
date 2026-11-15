import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows the welcome screen first. When the user taps, it fades out and
/// shows [next] (the login page or the app, depending on login status).
class WelcomeGate extends StatefulWidget {
  final Widget next;
  const WelcomeGate({super.key, required this.next});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate>
    with TickerProviderStateMixin {
  // (quote, author) - add or remove lines freely
  static const _quotes = <(String, String)>[
    ('The only way to do great work is to love what you do.', 'Steve Jobs'),
    ('We are what we repeatedly do. Excellence, then, is not an act, but a habit.',
        'Will Durant'),
    ('Life is like riding a bicycle. To keep your balance, you must keep moving.',
        'Albert Einstein'),
    ("I've failed over and over and over again in my life. And that is why I succeed.",
        'Michael Jordan'),
    ('I learned that courage was not the absence of fear, but the triumph over it.',
        'Nelson Mandela'),
    ("You miss 100% of the shots you don't take.", 'Wayne Gretzky'),
    ('A journey of a thousand miles begins with a single step.', 'Lao Tzu'),
    ('Well done is better than well said.', 'Benjamin Franklin'),
    ('You must do the thing you think you cannot do.', 'Eleanor Roosevelt'),
    ('Genius is one percent inspiration, ninety-nine percent perspiration.',
        'Thomas Edison'),
  ];

  late final AnimationController _in; // fade-in of the contents
  late final AnimationController _out; // fade-out when tapped
  late final (String, String) _quote;
  bool _leaving = false;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward();
    _out = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450), value: 1);
    _quote = _quotes[Random().nextInt(_quotes.length)];
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_leaving) return;
    _leaving = true;
    await _out.reverse();
    if (mounted) setState(() => _entered = true);
  }

  Animation<double> _fade(double begin, double end) => CurvedAnimation(
        parent: _in,
        curve: Interval(begin, end, curve: Curves.easeOut),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _entered
          ? KeyedSubtree(key: const ValueKey('next'), child: widget.next)
          : _welcome(),
    );
  }

  Widget _welcome() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('welcome'),
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _continue,
        child: Scaffold(
          backgroundColor: const Color(0xFF151515),
          body: SafeArea(
            child: FadeTransition(
              opacity: _out,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _fade(0.0, 0.5),
                            child: const Column(
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 44, color: Colors.white),
                                SizedBox(height: 20),
                                Text(
                                  'LifeMaxxing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          FadeTransition(
                            opacity: _fade(0.3, 0.7),
                            child: const Text(
                              'Tap the screen to continue',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _fade(0.6, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: Column(
                        children: [
                          Text(
                            '“${_quote.$1}”',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '— ${_quote.$2}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}