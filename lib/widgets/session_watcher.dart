import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/auth_notifier.dart';

class SessionWatcher extends StatefulWidget {
  const SessionWatcher({super.key, required this.auth, required this.child});
  final AuthNotifier auth;
  final Widget child;
  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.auth.enabled) {
      HardwareKeyboard.instance.addHandler(_key);
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => widget.auth.checkSession(),
      );
    }
  }

  bool _key(KeyEvent event) {
    widget.auth.recordActivity();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.auth.checkSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.auth.enabled) {
      HardwareKeyboard.instance.removeHandler(_key);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => widget.auth.recordActivity(),
    onPointerMove: (_) => widget.auth.recordActivity(),
    onPointerHover: (_) => widget.auth.recordActivity(),
    onPointerSignal: (_) => widget.auth.recordActivity(),
    child: widget.child,
  );
}
