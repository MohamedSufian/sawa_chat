import 'dart:async';

import 'package:flutter/material.dart' as legacy show Material, MaterialType;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _resendSeconds = 60;

  final _pinController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify(String code) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // On success the session controller notices the new session and the router moves on.
      await ref.read(authRepositoryProvider).verifyOtp(phone: widget.phone, code: code);
    } catch (e) {
      if (!mounted) return;
      _pinController.clear();
      setState(() => _error = errorMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      if (!mounted) return;
      _startTimer();
      showErrorSnack(context, context.l10n.codeResent);
    } catch (e) {
      if (mounted) showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final pinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(l10n.otpTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              l10n.otpSubtitle(ltrIsolate(widget.phone)),
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Directionality(
              textDirection: TextDirection.ltr,
              // Pinput still asserts on package:flutter/material's Material ancestor,
              // which material_ui's Scaffold doesn't provide. Remove once Pinput migrates.
              child: legacy.Material(
                type: legacy.MaterialType.transparency,
                child: Pinput(
                  length: 6,
                  controller: _pinController,
                  autofocus: true,
                  enabled: !_loading,
                  defaultPinTheme: pinTheme,
                  focusedPinTheme: pinTheme.copyDecorationWith(border: Border.all(color: scheme.primary, width: 1.5)),
                  errorPinTheme: pinTheme.copyDecorationWith(border: Border.all(color: scheme.error, width: 1.5)),
                  forceErrorState: _error != null,
                  errorText: _error,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onCompleted: _verify,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        l10n.resendIn(_secondsLeft),
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    : TextButton(onPressed: _resend, child: Text(l10n.resendCode)),
              ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(onPressed: () => context.pop(), child: Text(l10n.editNumber)),
            ),
          ],
        ),
      ),
    );
  }
}
