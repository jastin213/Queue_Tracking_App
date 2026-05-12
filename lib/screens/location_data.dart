class MunicipalityLocation {
  final String name;
  final double lat;
  final double lon;

  MunicipalityLocation({
    required this.name,
    required this.lat,
    required this.lon,
  });
}

final List<MunicipalityLocation> albayThirdDistrictLocations = [
  MunicipalityLocation(
    name: "Ligao",
    lat: 13.2167,
    lon: 123.5333,
  ),
  MunicipalityLocation(
    name: "Guinobatan",
    lat: 13.1913,
    lon: 123.5986,
  ),
  MunicipalityLocation(
    name: "Jovellar",
    lat: 13.0667,
    lon: 123.6000,
  ),
  MunicipalityLocation(
    name: "Libon",
    lat: 13.2997,
    lon: 123.4386,
  ),
  MunicipalityLocation(
    name: "Oas",
    lat: 13.2589,
    lon: 123.4953,
  ),
  MunicipalityLocation(
    name: "Pio Duran",
    lat: 13.0293,
    lon: 123.4442,
  ),
  MunicipalityLocation(
    name: "Polangui",
    lat: 13.2923,
    lon: 123.4856,
  ),
];

MunicipalityLocation getMunicipalityLocation(String municipality) {
  return albayThirdDistrictLocations.firstWhere(
    (location) => location.name.toLowerCase() == municipality.toLowerCase(),
    orElse: () => albayThirdDistrictLocations.first,
  );
}