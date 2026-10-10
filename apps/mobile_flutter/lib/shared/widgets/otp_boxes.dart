import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// One-time-code entry shown as separate boxes. A transparent text field sits on
/// top of the boxes, so the system keyboard, paste and the keyboard's
/// "one-time code" suggestion all work as for a normal field.
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    this.length = 6,
    this.hasError = false,
    this.autofocus = true,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpace.s;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = ((constraints.maxWidth - gap * (length - 1)) / length)
            .clamp(36.0, 52.0);
        final rowWidth = boxWidth * length + gap * (length - 1);
        return Center(
          child: SizedBox(
            width: rowWidth,
            height: 58,
            child: Stack(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([controller, focusNode]),
                  builder: (context, _) {
                    final text = controller.text;
                    final focusedIndex = focusNode.hasFocus
                        ? text.length.clamp(0, length - 1)
                        : -1;
                    return ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < length; i++)
                            _Box(
                              width: boxWidth,
                              char: i < text.length ? text[i] : '',
                              focused: i == focusedIndex,
                              filled: i < text.length,
                              error: hasError,
                            ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Semantics(
                    textField: true,
                    label: 'One-time code, $length digits',
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: autofocus,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(length),
                      ],
                      showCursor: false,
                      enableInteractiveSelection: false,
                      cursorColor: Colors.transparent,
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 1,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        onChanged?.call(value);
                        if (value.length == length) onCompleted?.call(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.width,
    required this.char,
    required this.focused,
    required this.filled,
    required this.error,
  });

  final double width;
  final String char;
  final bool focused;
  final bool filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? AppColors.error
        : focused
        ? AppColors.primary
        : filled
        ? AppColors.primary
        : AppColors.outlineStrong;
    return AnimatedContainer(
      duration: AppMotion.quick,
      width: width,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled && !error
            ? AppColors.primaryContainer
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: borderColor,
          width: focused || error ? 2 : 1.5,
        ),
      ),
      child: Text(
        char,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontSize: 24),
      ),
    );
  }
}
