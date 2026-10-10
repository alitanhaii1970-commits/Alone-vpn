import 'package:flutter/painting.dart';
import 'palette.dart';
import 'settings.dart';
import 'strings.dart';
import 'strings_extra.dart';

/// Translate a key. `{s}` / `{d}` style placeholders are filled from [v].
String tr(String key, [Map<String, String>? v]) {
  final fa = AppSettings.I.fa;
  var s = (fa ? kFa[key] : kEn[key]) ?? kFa[key] ?? (fa ? kFaExtra[key] : kEnExtra[key]) ?? kFaExtra[key] ?? key;
  if (v != null) {
    v.forEach((k, val) {
      s = s.replaceAll('{$k}', val);
    });
  }
  return s;
}

const List<String> _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Localise digits when the user chose Persian numerals.
String loc(Object? v) {
  final s = '$v';
  if (AppSettings.I.digits != 'fa') return s;
  return s.replaceAllMapped(RegExp(r'\d'), (m) => _faDigits[int.parse(m[0]!)]);
}

String fmtBytes(num n) {
  if (n < 1024) return '${loc(n.round())} B';
  if (n < 1048576) return '${loc((n / 1024).toStringAsFixed(1))} KB';
  if (n < 1073741824) return '${loc((n / 1048576).toStringAsFixed(1))} MB';
  return '${loc((n / 1073741824).toStringAsFixed(2))} GB';
}

String mmss(int s) => '${loc(s ~/ 60)}:${loc((s % 60).toString().padLeft(2, '0'))}';

/// Latency presentation, same thresholds as the design.
Color latTone(Pal p, int? ms) => ms == null ? p.error : ms < 80 ? p.ok : ms < 150 ? p.warn : p.error;
String latText(int? ms) => ms == null ? tr('timeout') : '${loc(ms)} ms';
int latBars(int? ms) => ms == null ? 0 : ms < 70 ? 4 : ms < 120 ? 3 : ms < 200 ? 2 : 1;

/// Like [tr], but with an inline fallback for strings that only exist in this app.
String trOr(String key, String fa, String en) {
  final s = AppSettings.I.fa ? (kFa[key] ?? kFaExtra[key]) : (kEn[key] ?? kEnExtra[key]);
  return s ?? (AppSettings.I.fa ? fa : en);
}
