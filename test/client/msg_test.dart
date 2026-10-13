import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/l10n/msg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  setUp(() {
    appLang.value = 'en';
    missingHindi.clear();
  });
  tearDown(() => appLang.value = 'en');

  group('plain values', () {
    test('a string is shown as it is', () => expect(msg('Hello'), 'Hello'));
    test('a string is not translated', () {
      appLang.value = 'hi';
      expect(msg('Please sign in.'), 'Please sign in.');
    });
    test('numbers show their digits', () {
      expect(msg(5), '5');
      expect(msg(2.5), '2.5');
    });
    test('null is nothing', () => expect(msg(null), ''));
    test('an empty map shows nothing', () => expect(msg(const {}), ''));
  });

  group('t and a', () {
    test('t alone is tr', () => expect(msg({'t': 'Please sign in.'}), 'Please sign in.'));

    test('int and string arguments go in unchanged', () {
      expect(msg({'t': '{n} alerts from {who}', 'a': {'n': 3, 'who': 'Dr. Rao'}}), '3 alerts from Dr. Rao');
    });

    test('a message argument is rendered first', () {
      final m = {
        't': 'Why: {why}',
        'a': {
          'why': {'t': 'Heart rate {hr} bpm', 'a': {'hr': 89}},
        },
      };
      expect(msg(m), 'Why: Heart rate 89 bpm');
    });

    test('a message argument is translated in Hindi, the outer text too', () {
      appLang.value = 'hi';
      final m = {
        't': 'Quality {q} · good, use it',
        'a': {'q': '0.92'},
      };
      expect(msg(m), 'क्वालिटी 0.92 · अच्छी, इस्तेमाल करें');
      expect(missingHindi, isEmpty);
    });

    test('a text with no Hindi is shown in English and noted', () {
      appLang.value = 'hi';
      expect(msg({'t': 'A sentence nobody has translated'}), 'A sentence nobody has translated');
      expect(missingHindi, contains('A sentence nobody has translated'));
    });

    test('arguments are filled in the order the server wrote them', () {
      // `tr` replaces placeholders one after the other, so an argument whose
      // text holds another placeholder gives a different result by order.
      final first = {'t': '{a} and {b}', 'a': {'a': '{b}', 'b': 'X'}};
      final second = {'t': '{a} and {b}', 'a': {'b': 'X', 'a': '{b}'}};
      expect(msg(first), 'X and X');
      expect(msg(second), '{b} and X');
    });
  });

  group('d, c, cap, lower', () {
    test('d is trData', () {
      expect(msg({'d': 'Cardiologist'}), 'Cardiologist');
      appLang.value = 'hi';
      expect(msg({'d': 'Cardiologist'}), 'हृदय रोग विशेषज्ञ');
      expect(msg({'d': 'No such value'}), 'No such value', reason: 'data with no translation is shown as entered');
    });

    test('c joins its parts with nothing between', () {
      expect(
        msg({
          'c': ['A', ' · ', {'t': 'Please sign in.'}, 7],
        }),
        'A · Please sign in.7',
      );
      expect(msg({'c': const []}), '');
    });

    test('c renders nested parts in Hindi', () {
      appLang.value = 'hi';
      expect(msg({'c': [{'t': 'Check-in'}, ' · ', {'t': 'Warning'}]}), 'हालचाल · चेतावनी');
    });

    test('cap upper-cases the first character only', () {
      expect(msg({'cap': 'heart rate'}), 'Heart rate');
      expect(msg({'cap': {'t': 'oxygen below your normal'}}), 'Oxygen below your normal');
      expect(msg({'cap': ''}), '');
      expect(msg({'cap': 'ÉCOLE'}), 'ÉCOLE');
      expect(msg({'cap': 'élan'}), 'Élan');
    });

    test('cap leaves Devanagari alone', () {
      appLang.value = 'hi';
      expect(msg({'cap': {'t': 'Check-in'}}), 'हालचाल');
    });

    test('lower lower-cases the shown text', () {
      expect(msg({'lower': 'Heart RATE'}), 'heart rate');
      expect(msg({'lower': {'t': 'Warning'}}), 'warning');
    });

    test('cap and lower nest', () {
      expect(msg({'cap': {'lower': 'HEART RATE'}}), 'Heart rate');
    });
  });

  group('dt and num', () {
    test('dt shows a UTC time in the phone\'s time zone', () {
      const iso = '2026-10-14T12:00:00Z';
      const f = 'EEE d MMM, h:mm a';
      final expected = DateFormat(f).format(DateTime.parse(iso).toLocal());
      expect(msg({'dt': iso, 'f': f}), expected);
      expect(msg({'dt': iso, 'f': 'yyyy-MM-dd HH:mm'}), DateFormat('yyyy-MM-dd HH:mm').format(DateTime.utc(2026, 10, 14, 12).toLocal()));
    });

    test('dt reads fractional seconds and offsets', () {
      expect(msg({'dt': '2026-10-14T06:30:00.000+05:30', 'f': 'HH:mm'}), DateFormat('HH:mm').format(DateTime.utc(2026, 10, 14, 1).toLocal()));
    });

    test('dt works inside a text', () {
      final when = DateFormat('d MMM').format(DateTime.utc(2026, 10, 14, 12).toLocal());
      expect(
        msg({
          't': 'Valid till {date}.',
          'a': {
            'date': {'dt': '2026-10-14T12:00:00Z', 'f': 'd MMM'},
          },
        }),
        'Valid till $when.',
      );
    });

    test('num uses the locale grouping', () {
      expect(msg({'num': 395000, 'f': 'en_IN'}), '3,95,000');
      expect(msg({'num': 395000, 'f': 'en_US'}), '395,000');
      expect(msg({'num': 1234.5, 'f': 'en_IN'}), '1,234.5');
    });

    test('num inside a text', () {
      expect(
        msg({
          't': '₹{left} left of ₹{total}',
          'a': {
            'left': {'num': 605000, 'f': 'en_IN'},
            'total': {'num': 1000000, 'f': 'en_IN'},
          },
        }),
        '₹6,05,000 left of ₹10,00,000',
      );
    });
  });

  test('the same message renders again in the new language', () {
    final m = {'c': [{'t': 'Check-in'}, ' · ', {'cap': {'t': 'Warning'}}]};
    expect(msg(m), 'Check-in · Warning');
    appLang.value = 'hi';
    expect(msg(m), 'हालचाल · चेतावनी');
    appLang.value = 'en';
    expect(msg(m), 'Check-in · Warning');
  });
}
