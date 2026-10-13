import 'package:intl/intl.dart';

import 'l10n.dart';

/// Renders a message from the PulseOS service in the app's language.
///
/// The service never translates. It sends English text as a small tree and
/// the app turns it into words with [tr] and [trData] (see the service's
/// `docs/pulseos.md`, section 3):
///
///  * a string is shown as it is, a number as its digits, `null` as nothing
///  * `{t, a}` is `tr(t, args)`; an argument that is itself a message is
///    rendered first, a number or string goes in unchanged, and the arguments
///    are filled in their JSON order
///  * `{d}` is `trData`, `{c: [...]}` joins its parts with nothing between,
///    `{cap}` upper-cases the first character and `{lower}` lower-cases
///  * `{dt, f}` is a UTC time shown in the phone's time zone with pattern `f`
///  * `{num, f}` is a number in locale `f`, like `en_IN` for 3,95,000
///
/// Call it when text is shown, not when it arrives, so a language switch
/// re-renders everything at once.
String msg(Object? m) {
  if (m == null) return '';
  if (m is String) return m;
  if (m is! Map) return '$m';
  if (m.containsKey('t')) {
    final en = '${m['t']}';
    final a = m['a'];
    if (a is! Map || a.isEmpty) return tr(en);
    // Map literals keep insertion order, which `tr` relies on: it fills the
    // placeholders one after the other.
    return tr(en, {for (final e in a.entries) '${e.key}': e.value is Map ? msg(e.value) : e.value});
  }
  if (m.containsKey('d')) return trData(msg(m['d']));
  if (m.containsKey('c')) {
    final parts = m['c'];
    return parts is List ? parts.map(msg).join() : '';
  }
  if (m.containsKey('cap')) {
    final s = msg(m['cap']);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }
  if (m.containsKey('lower')) return msg(m['lower']).toLowerCase();
  if (m.containsKey('dt')) {
    final at = DateTime.parse('${m['dt']}').toLocal();
    final f = m['f'];
    return (f == null ? DateFormat.yMd().add_jm() : DateFormat('$f')).format(at);
  }
  if (m.containsKey('num')) {
    final n = m['num'];
    if (n is! num) return '$n';
    final f = m['f'];
    return NumberFormat.decimalPattern(f == null ? null : '$f').format(n);
  }
  return '';
}
