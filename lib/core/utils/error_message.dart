import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Turns any thrown error into a message that is safe to show the user.
String errorMessage(AppLocalizations l10n, Object error) {
  if (error is SocketException || error is AuthRetryableFetchException) {
    return l10n.errorNetwork;
  }
  if (error is AuthException) {
    if (error.statusCode == '429' || error.code == 'over_sms_send_rate_limit') {
      return l10n.errorTooManyRequests;
    }
    if (error.code == 'otp_expired' || error.code == 'invalid_credentials') {
      return l10n.otpInvalid;
    }
  }
  return l10n.errorGeneric;
}
