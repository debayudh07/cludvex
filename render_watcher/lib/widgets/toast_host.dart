import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';

/// Inverse snackbar drawn above every route. Fades 150ms in / 75ms out.
class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<ToastData?>(
      valueListenable: state.toast,
      builder: (context, data, _) {
        return AnimatedPositioned(
          duration: Motion.press,
          curve: Motion.standard,
          left: 12,
          right: 12,
          bottom: safe + 12 + (data?.bottomInset ?? 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedSwitcher(
                duration: Motion.fadeIn,
                reverseDuration: Motion.fadeOut,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                            begin: const Offset(0, 0.25), end: Offset.zero)
                        .animate(a),
                    child: child,
                  ),
                ),
                child: data == null
                    ? const SizedBox.shrink()
                    : _Toast(key: ValueKey(data), data: data, state: state),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.data, required this.state});

  final ToastData data;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: AppColors.text,
        elevation: 8,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
            child: Row(children: [
              Expanded(
                child: Text(data.message,
                    style: const TextStyle(
                        color: AppColors.bg,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
              if (data.onUndo != null)
                TextButton(
                  onPressed: () {
                    final undo = data.onUndo!;
                    state.dismissToast();
                    undo();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onInverse,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  child: const Text('Undo'),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
