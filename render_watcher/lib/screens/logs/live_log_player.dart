import 'package:flutter/material.dart';

import '../../api/log_stream.dart';
import '../../data/models.dart';
import '../../motion/haptics.dart';
import '../../motion/transitions.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/primitives.dart';

/// YouTube-style persistent player for the live tail. [progress] runs from
/// 0 (docked mini bar) to 1 (full screen); the shell owns the controller and
/// interpolates the frame, this widget cross-fades the two layouts.
class LiveLogPlayer extends StatelessWidget {
  const LiveLogPlayer({
    super.key,
    required this.progress,
    required this.fullSize,
    required this.onTapMini,
    required this.onCollapse,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final double progress;
  final Size fullSize;
  final VoidCallback onTapMini;
  final VoidCallback onCollapse;
  final VoidCallback onClose;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final miniOpacity = (1 - p * 2.5).clamp(0.0, 1.0);
    final fullOpacity = ((p - 0.45) / 0.55).clamp(0.0, 1.0);

    Widget draggable(Widget child) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
          onVerticalDragEnd: (d) => onDragEnd(d.velocity.pixelsPerSecond.dy),
          child: child,
        );

    return Material(
      color: Color.lerp(AppColors.surface2, AppColors.bg, p),
      elevation: 10 * (1 - p),
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14 * (1 - p)),
        side: BorderSide(color: AppColors.outline.withValues(alpha: 1 - p)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        if (fullOpacity > 0)
          Positioned.fill(
            child: Opacity(
              opacity: fullOpacity,
              child: IgnorePointer(
                ignoring: fullOpacity < 0.5,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: fullSize.height,
                  maxHeight: fullSize.height,
                  child: _FullView(header: draggable, onCollapse: onCollapse),
                ),
              ),
            ),
          ),
        if (miniOpacity > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 64,
            child: Opacity(
              opacity: miniOpacity,
              child: IgnorePointer(
                ignoring: miniOpacity < 0.5,
                child: _MiniBar(drag: draggable, onTap: onTapMini, onClose: onClose),
              ),
            ),
          ),
      ]),
    );
  }
}

String _serviceLabel(AppState state, LogFilter f) => f.serviceId == null
    ? 'all services'
    : (state.serviceById(f.serviceId!)?.name ?? f.serviceId!);

/// One line of status for the stream, so an empty player never looks broken.
String _statusLine(AppState state) => switch (state.logStatus) {
      LogStreamStatus.live =>
        state.hasLogs ? 'waiting for the next line…' : 'connected · waiting for logs',
      LogStreamStatus.connecting => 'connecting to the log stream…',
      LogStreamStatus.retrying => 'reconnecting…',
      LogStreamStatus.needsSetup => 'connect Render and pick services first',
      LogStreamStatus.unauthorized => 'session expired · sign in again',
      LogStreamStatus.idle => 'live tail paused',
    };

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.drag, required this.onTap, required this.onClose});

  final Widget Function(Widget) drag;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final newest = state.visibleLogs(limit: 1).firstOrNull ?? state.newestLog;
    return Stack(children: [
      Row(children: [
        Expanded(
          child: drag(
            Semantics(
              button: true,
              label: 'Live logs for ${_serviceLabel(state, state.logFilter)}. Expand.',
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.logBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF262A36)),
                      ),
                      child: const Icon(Icons.terminal_rounded, size: 18, color: AppColors.accentText),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(_serviceLabel(state, state.logFilter),
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.mono(size: 12.5, color: AppColors.text, weight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            _LiveTag(paused: state.paused),
                          ]),
                          const SizedBox(height: 3),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Motion.decelerate,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                                child: child,
                              ),
                            ),
                            layoutBuilder: (current, previous) =>
                                Stack(alignment: Alignment.centerLeft, children: [?current]),
                            child: Text(
                              newest == null
                                  ? _statusLine(state)
                                  : '${state.serviceLabel(newest.serviceId)} · ${newest.message}',
                              key: ValueKey(newest?.index ?? -1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.mono(
                                  size: 11,
                                  color: newest?.level.color ?? AppColors.textFaint),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: state.paused ? 'Resume live tail' : 'Pause live tail',
          onPressed: () {
            Haptics.selection();
            state.setPaused(!state.paused);
          },
          icon: Icon(state.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        ),
        IconButton(
          tooltip: 'Close live tail',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
        ),
        const SizedBox(width: 4),
      ]),
      Positioned(left: 0, right: 0, bottom: 0, child: _StreamBar(active: !state.paused)),
    ]);
  }
}

class _LiveTag extends StatelessWidget {
  const _LiveTag({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    if (paused) {
      return const Text('PAUSED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.warningText));
    }
    return const Row(mainAxisSize: MainAxisSize.min, children: [
      LiveDot(size: 5),
      Text('LIVE',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.accentText)),
    ]);
  }
}

/// Thin violet activity bar along the mini player's bottom edge.
class _StreamBar extends StatefulWidget {
  const _StreamBar({required this.active});

  final bool active;

  @override
  State<_StreamBar> createState() => _StreamBarState();
}

class _StreamBarState extends State<_StreamBar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StreamBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 2,
        child: ColoredBox(
          color: AppColors.divider,
          child: widget.active
              ? AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment(-1 + Motion.standard.transform(_c.value) * 3 - 0.5, 0),
                    widthFactor: 0.4,
                    child: const ColoredBox(color: AppColors.accent),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _FullView extends StatelessWidget {
  const _FullView({required this.header, required this.onCollapse});

  final Widget Function(Widget) header;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    final lines = state.visibleLogs(limit: 80);
    final flagged = lines.take(15).where((l) => l.flagged).length;
    final filters = <(String, LogFilter)>[
      ('All services', const LogFilter()),
      for (final s in state.watchedServices) (s.shortName, LogFilter(serviceId: s.id)),
      ('Errors + warnings', const LogFilter(errorsOnly: true)),
    ];
    bool isSelected(LogFilter f) =>
        f.serviceId == state.logFilter.serviceId && f.errorsOnly == state.logFilter.errorsOnly;

    return Padding(
      padding: EdgeInsets.only(top: pad.top),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header(Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              CircleIconButton(icon: Icons.keyboard_arrow_down_rounded, tooltip: 'Collapse', onTap: onCollapse),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Live logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                  Text('${_serviceLabel(state, state.logFilter)} · '
                      '${state.watched.length} watched',
                      overflow: TextOverflow.ellipsis, style: AppText.mono(size: 11.5)),
                ]),
              ),
              Pressable(
                onTap: () {
                  Haptics.selection();
                  state.setPaused(!state.paused);
                },
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(Radii.pill),
                semanticLabel: state.paused ? 'Resume live tail' : 'Pause live tail',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (state.paused) const Icon(Icons.play_arrow_rounded, size: 16) else const LiveDot(size: 6),
                    const SizedBox(width: 4),
                    Text(state.paused ? 'Resume' : 'Live',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ]),
        )),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => FilterChipX(
              label: filters[i].$1,
              selected: isSelected(filters[i].$2),
              onTap: () {
                Haptics.selection();
                state.setLogFilter(filters[i].$2);
              },
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.logBg,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: lines.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (state.logStatus == LogStreamStatus.connecting ||
                            state.logStatus == LogStreamStatus.retrying)
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: AppColors.textFaint),
                          )
                        else
                          const Icon(Icons.terminal_rounded,
                              size: 24, color: AppColors.textGhost),
                        const SizedBox(height: 12),
                        Text(_statusLine(state),
                            textAlign: TextAlign.center,
                            style: AppText.mono(size: 11.5, color: AppColors.textFaint)),
                      ]),
                    ),
                  )
                : RepaintBoundary(
              child: ListView.custom(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                childrenDelegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final e = lines[i];
                    final row = _LogRow(entry: e);
                    return KeyedSubtree(
                      key: ValueKey(e.index),
                      child: i == 0 && !state.paused
                          ? FadeSlideIn(duration: const Duration(milliseconds: 250), offset: 6, child: row)
                          : row,
                    );
                  },
                  childCount: lines.length,
                  findChildIndexCallback: (key) {
                    final idx = (key as ValueKey<int>).value;
                    final i = lines.indexWhere((l) => l.index == idx);
                    return i < 0 ? null : i;
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + pad.bottom),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accentText),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Agent is reading along · '),
                  TextSpan(text: '$flagged flagged',
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                ]),
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            const Text('flagged', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final serviceName = AppScope.of(context).serviceLabel(entry.serviceId);
    final err = entry.level == LogLevel.err;
    final base = AppText.mono(size: 11.5, color: err ? AppColors.text : const Color(0xFFB4B9C7), height: 1.45);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 12, 3),
      decoration: BoxDecoration(
        color: err ? AppColors.critical.withValues(alpha: 0.08) : null,
        border: Border(left: BorderSide(color: entry.flagged ? AppColors.accent : Colors.transparent, width: 2)),
      ),
      child: Text.rich(TextSpan(style: base, children: [
        TextSpan(text: '${entry.time}  ', style: base.copyWith(color: AppColors.textGhost)),
        TextSpan(text: '${entry.level.label}  ',
            style: base.copyWith(color: entry.level.color, fontWeight: FontWeight.w600)),
        TextSpan(text: '$serviceName · ', style: base.copyWith(color: AppColors.textFaint)),
        TextSpan(text: entry.message),
      ])),
    );
  }
}
