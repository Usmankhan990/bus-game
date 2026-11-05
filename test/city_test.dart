import 'package:bus_jam/models/city.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Har 20 level baad naya shehar, phir dobara chakkar', () {
    expect(City.of(1), City.karachi);
    expect(City.of(20), City.karachi);
    expect(City.of(21), City.lahore);
    expect(City.of(41), City.islamabad);
    expect(City.of(160), City.tokyo);
    expect(City.of(161), City.karachi);
    expect(City.tourOf(160), 1);
    expect(City.tourOf(161), 2);
    expect(City.startsCity(21), isTrue);
    expect(City.startsCity(22), isFalse);
    expect(City.progressIn(25), 4);
    expect(City.lahore.firstLevel(1), 21);
    expect(City.lahore.firstLevel(2), 181);
  });
}
