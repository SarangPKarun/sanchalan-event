import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/otp_boxes.dart';
import '../../shared/widgets/primary_button.dart';

const otpLength = 6;

/// Six-box code entry. [onVerify] checks the code and returns an error message
/// to show, or null on success; [onResend] asks for a new code the same way.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerify,
    required this.onResend,
    this.onChangeNumber,
    this.resendSeconds = 30,
  });

  final String phoneNumber;
  final Future<String?> Function(String otp) onVerify;
  final Future<String?> Function() onResend;
  final VoidCallback? onChangeNumber;
  final int resendSeconds;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  late int _remaining = widget.resendSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remaining = widget.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(
        () => _remaining = (_remaining - 1).clamp(0, widget.resendSeconds),
      );
      if (_remaining == 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != otpLength || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    final error = await widget.onVerify(_code.text);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _error = error;
    });
  }

  Future<void> _resend() async {
    if (_remaining > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    final error = await widget.onResend();
    if (!mounted) return;
    setState(() {
      _resending = false;
      _error = error;
    });
    if (error == null) {
      _code.clear();
      _focus.requestFocus();
      _startCountdown();
    }
  }

  String get _countdownLabel {
    final m = _remaining ~/ 60;
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return 'Resend code in $m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed:
              widget.onChangeNumber ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.s,
                  AppSpace.xl,
                  AppSpace.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Enter the code',
                        style: text.headlineLarge?.copyWith(
                          color: AppColors.maroon,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text('We sent a 6-digit code to', style: text.bodyLarge),
                    Text(widget.phoneNumber, style: text.titleMedium),
                    if (widget.onChangeNumber != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: widget.onChangeNumber,
                          // No side padding, so the text lines up with the heading.
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          child: const Text('Change number'),
                        ),
                      ),
                    const SizedBox(height: AppSpace.l),
                    OtpBoxes(
                      controller: _code,
                      focusNode: _focus,
                      length: otpLength,
                      hasError: _error != null,
                      onChanged: (_) => setState(() => _error = null),
                      onCompleted: (_) => _verify(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.m),
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color: AppColors.errorText,
                            ),
                            const SizedBox(width: AppSpace.s),
                            Expanded(
                              child: Text(
                                _error!,
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.errorText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                PrimaryButton(
                  label: 'Verify',
                  loading: _verifying,
                  onPressed: _code.text.length == otpLength ? _verify : null,
                ),
                const SizedBox(height: AppSpace.xs),
                Center(
                  child: _remaining > 0
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.m,
                          ),
                          child: Text(
                            _countdownLabel,
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: _resending ? null : _resend,
                          child: Text(
                            _resending ? 'Sending...' : 'Resend code',
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
