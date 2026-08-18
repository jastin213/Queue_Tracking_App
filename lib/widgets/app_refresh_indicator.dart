import 'package:flutter/material.dart';

class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> {
  static const Color _primaryColor = Color(0xFF071F35);

  Future<void> _refresh() async {
    try {
      await widget.onRefresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 190,
            duration: Duration(milliseconds: 900),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: StadiumBorder(),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 7),
                Text(
                  "Refreshed just now",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 270,
            backgroundColor: Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: StadiumBorder(),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 7),
                Text(
                  "Unable to refresh. Please try again.",
                  style: TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: _primaryColor,
        backgroundColor: Colors.white,
        displacement: 30,
        edgeOffset: 0,
        elevation: 1,
        strokeWidth: 2,
        triggerMode: RefreshIndicatorTriggerMode.onEdge,
        semanticsLabel: "Refresh",
        child: widget.child,
      ),
    );
  }
}
