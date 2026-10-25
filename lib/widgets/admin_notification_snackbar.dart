import 'dart:async';

import 'package:flutter/material.dart';

/// Owns only the transient admin popup, not its read state or navigation.
class AdminNotificationSnackBarPresenter {
  _PresentedAdminNotification? _active;
  Timer? _dismissTimer;

  String? get activeEventKey => _active?.eventKey;

  void show({
    required ScaffoldMessengerState messenger,
    required String eventKey,
    required Widget content,
    required VoidCallback onCheck,
  }) {
    if (!messenger.mounted) return;

    final previous = _active;
    if (previous != null) {
      _releaseOwnership(previous);
      if (!identical(previous.messenger, messenger)) {
        _closeOwned(previous);
      }
    }

    // Do not retain a backlog of outdated notifications. Removing the current
    // item after clearing its queue also makes the new controller the owner of
    // the currently displayed snackbar, rather than a discarded queued item.
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar();

    late final _PresentedAdminNotification notification;
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: content,
        action: SnackBarAction(
          label: 'CHECK',
          textColor: Colors.white,
          onPressed: () {
            _releaseOwnership(notification);
            onCheck();
          },
        ),
      ),
    );
    notification = _PresentedAdminNotification(
      eventKey: eventKey,
      messenger: messenger,
      controller: controller,
    );
    _active = notification;

    // Action snackbars can otherwise persist under accessibility navigation.
    // This timer preserves the agreed auto-dismissal without disabling swipe.
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (identical(_active, notification)) dismiss();
    });
    unawaited(
      controller.closed.then((_) {
        notification.closed = true;
        _releaseOwnership(notification);
      }),
    );
  }

  void dismiss() {
    final notification = _active;
    if (notification == null) return;
    _releaseOwnership(notification);
    _closeOwned(notification);
  }

  void _releaseOwnership(_PresentedAdminNotification notification) {
    if (!identical(_active, notification)) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _active = null;
  }

  void _closeOwned(_PresentedAdminNotification notification) {
    // Give completed closed futures their microtasks before invoking close.
    // Another feature may have replaced this snackbar in the same frame; its
    // old controller must not dismiss the new one. No cleanup timer is needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(() {
        if (!notification.closed && notification.messenger.mounted) {
          notification.controller.close();
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

class _PresentedAdminNotification {
  _PresentedAdminNotification({
    required this.eventKey,
    required this.messenger,
    required this.controller,
  });

  final String eventKey;
  final ScaffoldMessengerState messenger;
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
  bool closed = false;
}
