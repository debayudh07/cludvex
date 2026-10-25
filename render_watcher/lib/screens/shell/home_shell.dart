import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../data/models.dart';
import '../../motion/haptics.dart';
import '../../motion/transitions.dart';
import '../../state/app_state.dart';
import '../../theme/responsive.dart';
import '../../theme/tokens.dart';
import '../activity/activity_screen.dart';
import '../alerts/alert_detail_screen.dart';
import '../alerts/alerts_screen.dart';
import '../logs/live_log_player.dart';
import '../mandate/mandate_screen.dart';
import '../overview/overview_screen.dart';
import 'incoming_banner.dart';
import 'nav.dart';

/// Root of the signed-in app. Owns the chrome that outlives tabs: nav, the
/// live-log mini-player (YouTube-style, persists across tabs) and the
/// in-app alert banner.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  static const _miniHeight = 64.0;
  static const _navContent = 64.0;

  ShellTab _tab = ShellTab.overview;
  bool _navHidden = false;
  bool _playerVisible = true;
  bool _playerExpanded = false;
  int _badgeBump = 0;

  late final AnimationController _player = AnimationController(vsync: this);
  late final AnimationController _banner = AnimationController(
    vsync: this,
    duration: Motion.enter,
    reverseDuration: Motion.exit,
  );
  final _bannerKey = GlobalKey();
  Timer? _bannerShow;
  Timer? _bannerHide;
  bool _started = false;
  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final state = AppScope.read(context);
      // Held so dispose() needn't look up an inherited widget, which asserts
      // once the element is defunct.
      _appState = state;
      state.startStreaming();
      state.startPolling();
      state.addListener(_onStateChanged);
      _onStateChanged();
    }
  }

  /// The banner and deep links are driven by state rather than a timer: a
  /// push or a poll surfaces a new alert, and a notification tap asks for
  /// one by id.
  void _onStateChanged() {
    if (!mounted) return;
    final state = AppScope.read(context);

    final open = state.pendingOpen;
    if (open != null) {
      state.consumePendingOpen();
      final alert = state.allAlerts.where((a) => a.id == open).firstOrNull;
      if (alert != null) {
        _hideBanner();
        // Deep link from a notification: there is no card to grow out of.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openAlert(alert, Rect.zero);
        });
        return;
      }
    }

    if (state.incoming != null && !_banner.isForwardOrCompleted) _showBanner();
  }

  @override
  void dispose() {
    _appState?.removeListener(_onStateChanged);
    _bannerShow?.cancel();
    _bannerHide?.cancel();
    _player.dispose();
    _banner.dispose();
    super.dispose();
  }

  AppState get _state => AppScope.read(context);

  // ---- banner
  void _showBanner() {
    if (!mounted || AppScope.read(context).incoming == null) return;
    _bannerHide?.cancel();
    setState(() => _badgeBump++);
    _banner.forward();
    Haptics.alert(Severity.critical);
    _bannerHide = Timer(const Duration(seconds: 6), _hideBanner);
  }

  void _hideBanner() {
    _bannerHide?.cancel();
    if (mounted) _banner.reverse();
  }

  // ---- navigation
  void _select(ShellTab tab) {
    Haptics.selection();
    if (tab == ShellTab.logs) {
      _expandPlayer();
      return;
    }
    if (_playerExpanded) _settlePlayer(false);
    setState(() {
      _tab = tab;
      _navHidden = false;
    });
  }

  void _setChromeHidden(bool hidden) {
    if (hidden != _navHidden) setState(() => _navHidden = hidden);
  }

  double _bottomInset(BuildContext context) {
    final mini = _playerVisible ? _miniHeight + 8 : 0.0;
    if (context.isExpanded) return mini + 16;
    return _navContent + MediaQuery.paddingOf(context).bottom + mini + 8;
  }

  Future<void> _openAlert(Alert alert, Rect source) async {
    _hideBanner();
    _state.dismissIncoming();
    final action = await Navigator.of(context).push<DetailAction>(
      ContainerTransformRoute(
        sourceRect: source,
        builder: (_) => AlertDetailScreen(alert: alert),
      ),
    );
    if (!mounted || action == null) return;
    final inset = _bottomInset(context);
    switch (action) {
      case DetailAction.ignored:
        await _state.ignore(alert.id);
        if (!mounted) return;
        _state.showToast('Alert ignored',
            bottomInset: inset, onUndo: () => _state.unignore(alert.id));
      case DetailAction.silenced:
        await _state.silence(alert.id);
        if (!mounted) return;
        _state.showToast('Silenced for 1 hour',
            bottomInset: inset, onUndo: () => _state.unignore(alert.id));
      case DetailAction.restarted:
        _state.showToast('Restart sent to Render · logged', bottomInset: inset);
      case DetailAction.logs:
        _openLogs(alert.serviceId);
    }
  }

  void _openLogs(String? serviceId) {
    _state.setLogFilter(LogFilter(serviceId: serviceId));
    _state.setPaused(false);
    _expandPlayer();
  }

  void _openMandate() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MandateScreen()));
  }

  // ---- player
  void _expandPlayer() {
    if (!_playerVisible) {
      _player.value = 0;
      setState(() => _playerVisible = true);
    }
    _settlePlayer(true);
  }

  /// Spring release (M3 DefaultSpatial) carrying the finger's velocity.
  void _settlePlayer(bool expand, {double velocity = 0}) {
    setState(() => _playerExpanded = expand);
    if (context.reduceMotion) {
      _player.animateTo(expand ? 1 : 0, duration: Motion.fadeIn);
      return;
    }
    _player.animateWith(SpringSimulation(
      Motion.sheetSpring,
      _player.value,
      expand ? 1 : 0,
      velocity,
    ));
  }

  void _closePlayer() {
    setState(() => _playerVisible = false);
    _state.showToast('Live tail closed',
        bottomInset: _bottomInset(context) - _miniHeight - 8,
        onUndo: () => setState(() => _playerVisible = true));
  }

  @override
  Widget build(BuildContext context) {
    final expanded = context.isExpanded;
    final inset = _bottomInset(context);
    final selected = _playerExpanded ? ShellTab.logs : _tab;
    final state = AppScope.of(context);
    final openCount = state.openAlertCount;
    final incoming = state.incoming;

    final tabs = TabStack(
      index: _tab.index.clamp(0, 2),
      children: [
        OverviewScreen(
          bottomInset: inset,
          onReplayBanner: _showBanner,
          onOpenMandate: _openMandate,
          onOpenLogs: _openLogs,
        ),
        AlertsScreen(
          bottomInset: inset,
          onOpen: _openAlert,
          onChromeHidden: _setChromeHidden,
        ),
        ActivityScreen(bottomInset: inset, onChromeHidden: _setChromeHidden),
      ],
    );

    final stage = LayoutBuilder(builder: (context, c) {
      final area = Size(c.maxWidth, c.maxHeight);
      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: tabs),
        if (!expanded)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _navHidden && !_playerExpanded ? const Offset(0, 1) : Offset.zero,
              duration: Motion.tab,
              curve: Motion.standard,
              child: BottomNav(
                selected: selected,
                badge: openCount,
                badgeBump: _badgeBump,
                onSelect: _select,
              ),
            ),
          ),
        if (_playerVisible) _buildPlayer(context, area, expanded),
        if (incoming != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 10,
            right: 10,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -1.6), end: Offset.zero).animate(
                    CurvedAnimation(
                        parent: _banner,
                        curve: Motion.decelerate,
                        reverseCurve: Motion.accelerate),
                  ),
                  child: IncomingBanner(
                    key: _bannerKey,
                    alert: incoming,
                    onTap: () => _openAlert(incoming, rectOf(_bannerKey.currentContext!)),
                    onDismiss: _hideBanner,
                  ),
                ),
              ),
            ),
          ),
      ]);
    });

    return PopScope(
      canPop: !_playerExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _playerExpanded) _settlePlayer(false);
      },
      child: Scaffold(
        body: expanded
            ? Row(children: [
                SideRail(selected: selected, badge: openCount, onSelect: _select),
                const VerticalDivider(width: 1),
                Expanded(child: stage),
              ])
            : stage,
      ),
    );
  }

  Widget _buildPlayer(BuildContext context, Size area, bool expanded) {
    final pad = MediaQuery.paddingOf(context);
    final Rect mini;
    if (expanded) {
      const w = 400.0;
      mini = Rect.fromLTWH(area.width - w - 16, area.height - _miniHeight - 16 - pad.bottom, w, _miniHeight);
    } else {
      final navOffset = _navHidden && !_playerExpanded ? pad.bottom : _navContent + pad.bottom;
      mini = Rect.fromLTWH(8, area.height - navOffset - 8 - _miniHeight, area.width - 16, _miniHeight);
    }
    final full = Offset.zero & area;
    final travel = mini.top.clamp(1.0, double.infinity);

    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final p = _player.value.clamp(0.0, 1.0);
        return Positioned.fromRect(
          rect: Rect.lerp(mini, full, p)!,
          child: LiveLogPlayer(
            progress: p,
            fullSize: area,
            onTapMini: _expandPlayer,
            onCollapse: () => _settlePlayer(false),
            onClose: _closePlayer,
            onDragUpdate: (dy) => _player.value = (_player.value - dy / travel).clamp(0.0, 1.0),
            onDragEnd: (vy) {
              final v = -vy / travel; // progress units per second
              final expand = v.abs() > 0.8 ? v > 0 : _player.value > 0.5;
              _settlePlayer(expand, velocity: v);
            },
          ),
        );
      },
    );
  }
}

/// Keeps every visited tab alive and fades through between them with a
/// small upward offset (M3 fade-through, YouTube's slide-up tab switch).
class TabStack extends StatefulWidget {
  const TabStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<TabStack> createState() => _TabStackState();
}

class _TabStackState extends State<TabStack> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.tab, value: 1);
  late final _curve = CurvedAnimation(parent: _c, curve: Motion.decelerate);
  late final Set<int> _visited = {widget.index};

  @override
  void didUpdateWidget(TabStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _visited.add(widget.index);
      if (context.reduceMotion) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < widget.children.length; i++)
        if (_visited.contains(i))
          i == widget.index
              ? AnimatedBuilder(
                  animation: _curve,
                  child: widget.children[i],
                  builder: (context, child) => Opacity(
                    opacity: _curve.value,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - _curve.value)),
                      child: child,
                    ),
                  ),
                )
              : Offstage(child: TickerMode(enabled: false, child: widget.children[i])),
    ]);
  }
}

/// Reports scroll direction so lists can hide the chrome (YouTube feed).
bool handleChromeScroll(UserScrollNotification n, ValueChanged<bool> onHidden) {
  if (n.depth != 0) return false;
  if (n.metrics.pixels <= n.metrics.minScrollExtent + 8) {
    onHidden(false);
  } else if (n.direction == ScrollDirection.reverse) {
    onHidden(true);
  } else if (n.direction == ScrollDirection.forward) {
    onHidden(false);
  }
  return false;
}
