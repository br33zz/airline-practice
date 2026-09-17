import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

class SessionWatcher extends StatefulWidget {
  final Widget child;
  const SessionWatcher({super.key, required this.child});

  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher> {
  static const inactivity = Duration(minutes: 3);
  static const warningBefore = Duration(seconds: 30);
  static const maxSession = Duration(minutes: 30);
  Timer? warningTimer;
  Timer? inactivityTimer;
  Timer? sessionTimer;
  bool warningVisible = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  bool _onKey(KeyEvent event) {
    _activity();
    return false;
  }

  void _activity() {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) return;
    auth.recordActivity();
    if (warningVisible && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      warningVisible = false;
    }
    _scheduleInactivity();
  }

  void _schedule() {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) return;
    _scheduleInactivity();
    final started = auth.sessionStarted ?? DateTime.now();
    final remaining = maxSession - DateTime.now().difference(started);
    sessionTimer?.cancel();
    if (remaining <= Duration.zero) {
      _expire('Сессия завершена: истекло максимальное время работы.');
    } else {
      sessionTimer = Timer(
        remaining,
        () => _expire('Сессия завершена: истекло максимальное время работы.'),
      );
    }
  }

  void _scheduleInactivity() {
    warningTimer?.cancel();
    inactivityTimer?.cancel();
    final auth = context.read<AuthNotifier>();
    final last = auth.lastActivity ?? DateTime.now();
    final elapsed = DateTime.now().difference(last);
    final untilExit = inactivity - elapsed;
    if (untilExit <= Duration.zero) {
      _expire('Сессия завершена из-за неактивности.');
      return;
    }
    final untilWarning = untilExit - warningBefore;
    warningTimer = Timer(
      untilWarning > Duration.zero ? untilWarning : Duration.zero,
      _showWarning,
    );
    inactivityTimer = Timer(
      untilExit,
      () => _expire('Сессия завершена из-за неактивности.'),
    );
  }

  Future<void> _showWarning() async {
    if (!mounted || warningVisible) return;
    warningVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Сессия скоро завершится'),
        content: const Text(
          'Через 30 секунд будет выполнен выход из-за неактивности.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _activity();
            },
            child: const Text('Продолжить работу'),
          ),
        ],
      ),
    );
    warningVisible = false;
  }

  Future<void> _expire(String reason) async {
    if (!mounted) return;
    if (warningVisible && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      warningVisible = false;
    }
    await context.read<AuthNotifier>().logout(reason: reason);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _activity(),
    onPointerMove: (_) => _activity(),
    onPointerSignal: (_) => _activity(),
    child: widget.child,
  );

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    warningTimer?.cancel();
    inactivityTimer?.cancel();
    sessionTimer?.cancel();
    super.dispose();
  }
}
