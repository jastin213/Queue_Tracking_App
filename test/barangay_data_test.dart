import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/screens/barangay_data.dart';

void main() {
  test('provides complete barangay lists for supported locations', () {
    expect(getBarangaysForMunicipality('Ligao').length, 55);
    expect(getBarangaysForMunicipality('Guinobatan').length, 44);
    expect(getBarangaysForMunicipality('Jovellar').length, 23);
    expect(getBarangaysForMunicipality('Libon').length, 47);
    expect(getBarangaysForMunicipality('Oas').length, 53);
    expect(getBarangaysForMunicipality('Pio Duran').length, 33);
    expect(getBarangaysForMunicipality('Polangui').length, 44);
  });

  test('includes Matacon under Polangui and no duplicate entries', () {
    final barangays = getBarangaysForMunicipality('Polangui');

    expect(barangays, contains('Matacon'));
    expect(barangays.toSet().length, barangays.length);
  });

  test('returns an empty list for an unsupported municipality', () {
    expect(getBarangaysForMunicipality('Unknown'), isEmpty);
  });
}
