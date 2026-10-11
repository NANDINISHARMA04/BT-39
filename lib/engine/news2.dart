// NEWS2 (Royal College of Physicians, 2017), mirroring the BT39 service's
// tables. Used to colour values and to score the on-device demo ward.
// The service's own `news2` and `band` are the score of record.

int? news2Points(String vital, num? x, {bool onOxygen = false, int scale = 1}) {
  if (x == null) return null;
  switch (vital) {
    case 'rr':
      return x <= 8 ? 3 : x <= 11 ? 1 : x <= 20 ? 0 : x <= 24 ? 2 : 3;
    case 'sbp':
      return x <= 90 ? 3 : x <= 100 ? 2 : x <= 110 ? 1 : x <= 219 ? 0 : 3;
    case 'hr':
      return x <= 40 ? 3 : x <= 50 ? 1 : x <= 90 ? 0 : x <= 110 ? 1 : x <= 130 ? 2 : 3;
    case 'temp':
      return x <= 35 ? 3 : x <= 36 ? 1 : x <= 38 ? 0 : x <= 39 ? 1 : 2;
    case 'spo2':
      if (scale == 2) {
        if (x <= 83) return 3;
        if (x <= 85) return 2;
        if (x <= 87) return 1;
        if (x <= 92 || !onOxygen) return 0;
        return x <= 94 ? 1 : x <= 96 ? 2 : 3;
      }
      return x <= 91 ? 3 : x <= 93 ? 2 : x <= 95 ? 1 : 0;
    default:
      return 0;
  }
}

class News2Score {
  const News2Score(this.total, this.band, this.anyThree);
  final int total;
  final String band; // low | low_medium | medium | high
  final bool anyThree;
}

News2Score news2({num? rr, num? spo2, num? sbp, num? hr, num? temp, bool onOxygen = false, String consciousness = 'A', int scale = 1}) {
  final pts = <int?>[
    news2Points('rr', rr),
    news2Points('spo2', spo2, onOxygen: onOxygen, scale: scale),
    news2Points('sbp', sbp),
    news2Points('hr', hr),
    news2Points('temp', temp),
    onOxygen ? 2 : 0,
    consciousness == 'A' ? 0 : 3,
  ];
  final total = pts.whereType<int>().fold(0, (a, b) => a + b);
  final anyThree = pts.any((p) => p == 3);
  final band = total >= 7 ? 'high' : total >= 5 ? 'medium' : anyThree ? 'low_medium' : 'low';
  return News2Score(total, band, anyThree);
}

const bandLabel = {'low': 'Low', 'low_medium': 'Low–medium', 'medium': 'Medium', 'high': 'High'};
const severityLabel = {'low': 'Watch', 'medium': 'Urgent', 'high': 'Emergency'};
