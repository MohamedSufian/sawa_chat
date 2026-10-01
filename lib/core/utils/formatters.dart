import 'package:intl/intl.dart' show Bidi, DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

String _locale(BuildContext context) => Localizations.localeOf(context).toLanguageTag();

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// "14:05" for today, "Yesterday", a weekday this week, otherwise a short date.
String chatListTime(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final days = _day(DateTime.now()).difference(_day(local)).inDays;
  final locale = _locale(context);
  if (days == 0) return DateFormat.Hm(locale).format(local);
  if (days == 1) return AppLocalizations.of(context).yesterday;
  if (days < 7) return DateFormat.EEEE(locale).format(local);
  return DateFormat.yMd(locale).format(local);
}

/// Separator label between days inside a conversation.
String dayLabel(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final days = _day(DateTime.now()).difference(_day(local)).inDays;
  final l10n = AppLocalizations.of(context);
  if (days == 0) return l10n.today;
  if (days == 1) return l10n.yesterday;
  return DateFormat.yMMMMd(_locale(context)).format(local);
}

String messageTime(BuildContext context, DateTime time) => DateFormat.Hm(_locale(context)).format(time.toLocal());

/// "last seen today at 14:05" / "yesterday" / a date.
String lastSeenLabel(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final days = _day(DateTime.now()).difference(_day(local)).inDays;
  final l10n = AppLocalizations.of(context);
  final clock = messageTime(context, local);
  if (days <= 0) return l10n.lastSeenToday(clock);
  if (days == 1) return l10n.lastSeenYesterday(clock);
  return l10n.lastSeenOn(DateFormat.yMMMd(_locale(context)).format(local));
}

bool isSameDay(DateTime a, DateTime b) => _day(a.toLocal()) == _day(b.toLocal());

/// Direction of the text itself, so an English message reads LTR in an Arabic UI and vice versa.
TextDirection textDirectionOf(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
