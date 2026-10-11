import 'package:bt39_care/engine/news2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NEWS2 points follow the RCP tables', () {
    expect(news2Points('hr', 40), 3);
    expect(news2Points('hr', 91), 1);
    expect(news2Points('hr', 131), 3);
    expect(news2Points('spo2', 93), 2);
    expect(news2Points('spo2', 91), 3);
    expect(news2Points('temp', 39.1), 2);
    expect(news2Points('rr', 25), 3);
    expect(news2Points('sbp', 100), 2);
    expect(news2Points('hr', null), isNull);
  });

  test('bands: total 7+ is high, a single 3 is low-medium', () {
    expect(news2(rr: 26, spo2: 93, sbp: 92, hr: 128, temp: 38.6).band, 'high');
    expect(news2(rr: 16, spo2: 97, sbp: 120, hr: 75, temp: 36.8).band, 'low');
    expect(news2(rr: 26, spo2: 97, sbp: 120, hr: 75, temp: 36.8).band, 'low_medium');
    expect(news2(rr: 16, spo2: 97, sbp: 120, hr: 75, temp: 36.8, onOxygen: true).total, 2);
  });
}
