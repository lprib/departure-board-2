import 'dart:convert';

import 'departure_model.dart';
import 'package:http/http.dart' as http;

class TrafficMonitorSite {
  /// WEBTRIS id
  final int id;
  final String displayName;

  TrafficMonitorSite({required this.id, required this.displayName});
}

/// Of course this is a bastardization of the "Station" and "Departure" model,
/// but it avoids me having to implement custom UI. THe existing one works
/// surprisingly well.
///
/// There is one "station" for traffic, which generates a "departure" for each
/// traffic monitoring site of interest
/// 
/// API:
/// https://webtris.highwaysengland.co.uk/api/swagger/ui/index
class WebtrisTrafficService extends StationDepartureService {
  final List<TrafficMonitorSite> sites;

  WebtrisTrafficService({required this.sites, required super.name})
    : super(logo: StationLogo.highway, pollTime: Duration(seconds: 5));

  @override
  Future<StationData> getLatest() async {
    // TODO: implement getLatest
    throw UnimplementedError();
  }

  Future<Departure> getStatusForSite(TrafficMonitorSite site) async {
    final response = await http.get(
      Uri.parse(
        "https://webtris.nationalhighways.co.uk/api/v1.0/sites/${site.id}",
      ),
    );
    if (response.statusCode == 200) {
      return Departure.bus(time: "l", secondaryText: "s", isLive: false);
    } else {
      throw Exception(
        "webtris query for site ${site.id} returned HTTP ${response.statusCode}",
      );
    }
  }
}
