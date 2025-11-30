enum DepartureType { normal, delayed, cancelled }

enum DepartureIcon { none, check, live, scheduled, speed }

class Departure {
  final DepartureType type;
  final String leftmostText;
  final bool timeStrikethrough;
  final String? rightmostText;
  final DepartureIcon icon;

  Departure(
    this.type,
    this.leftmostText,
    this.timeStrikethrough,
    this.rightmostText,
    this.icon,
  );
  Departure.train({
    required this.leftmostText,
    required this.type,
    this.rightmostText,
  }) : timeStrikethrough =
           (type == DepartureType.delayed || type == DepartureType.cancelled),
       icon =
           type == DepartureType.normal
               ? DepartureIcon.check
               : DepartureIcon.none;

  Departure.bus({
    required this.leftmostText,
    required this.rightmostText,
    required bool isLive,
  }) : type = DepartureType.normal,
       timeStrikethrough = false,
       icon = isLive ? DepartureIcon.live : DepartureIcon.scheduled;

  Departure.traffic({
    required this.leftmostText,
    required this.rightmostText,
    required this.type,
  }) : timeStrikethrough = false,
       icon = DepartureIcon.speed;
}

enum StationLogo { southWesternRailway, thamesLink, tflBus, digico, highway }

class StationData {
  final String? errorText;
  final List<Departure> departures;

  StationData({required this.departures, this.errorText});
  StationData.departures(this.departures) : errorText = null;
  StationData.error(this.errorText) : departures = [];
}

abstract class StationDepartureService {
  final String name;
  final StationLogo logo;
  final Duration pollTime;
  final Map<String, String> commonLocationNames;

  StationDepartureService({
    required this.name,
    required this.logo,
    this.pollTime = const Duration(seconds: 5),
    this.commonLocationNames = const {},
  });

  Future<StationData> getLatest();
}
