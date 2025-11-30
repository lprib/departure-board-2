import 'dart:convert';

import 'departure_model.dart';
import 'package:http/http.dart' as http;

/// We can reverse engineer this API which doesn't seem to be documented
/// https://www.trafficengland.com/traffic-report
///
/// GET https://www.trafficengland.com/api/network/getJunctionSections?roadName=M25&_=1764519008357
///   _ is current timestamp
///   COOKIE JSESSIONID	"dV9+Ujm4m7rSh6eX9n1dnnSJ.ha-ntis-app142" (cookie, does it matter?)
///   Returns a JSON list of sections between junctions
///
/// GET https://www.trafficengland.com/api/events/getByJunctionInterval
///   ?road=M25&fromId=203620
///   &toId=203613
///   &events=CONGESTION,INCIDENT,ROADWORKS,MAJOR_ORGANISED_EVENTS,ABNORMAL_LOADS
///   &includeUnconfirmedRoadworks=true
///   &_=1764519008358

// turns out A-roads don't have average speeds, just do motorways for now
// enum TrafficReportType { aRoad, motorway }

class TrafficReportSpec {
  final String name;
  final String motorway;
  final String fromJunctionName;
  final String toJunctionName;

  TrafficReportSpec({
    required this.name,
    required this.motorway,
    required this.fromJunctionName,
    required this.toJunctionName,
  });
}

class TrafficEnglandService extends StationDepartureService {
  static const double redSpeedThresh = 30.0;
  static const double yellowSpeedThresh = 50.0;

  final List<TrafficReportSpec> reportSpecs;

  TrafficEnglandService({ required super.name, required this.reportSpecs})
    : super(logo: StationLogo.highway, pollTime: Duration(seconds: 10));

  @override
  Future<StationData> getLatest() async {
    // we only want to request each motorway once because it is a phat json
    // blob, so keep a hashmap of motorway -> response
    //
    // This will be reused for each TrafficReportSpec that shares the motorway
    var motorwayResponses = <String, Map<String, dynamic>>{};
    for (final reportSpec in reportSpecs) {
      if (motorwayResponses.containsKey(reportSpec.motorway)) {
        // we've already requested this motorway
        continue;
      }
      final requestTime = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse(
          "https://www.trafficengland.com/api/network/getJunctionSections?roadName=${reportSpec.motorway}&_=$requestTime",
        ),
      );
      if (response.statusCode == 200) {
        try {
          motorwayResponses[reportSpec.motorway] =
              jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          return StationData.error("Invlid JSON from API");
        }
      } else {
        return StationData.error("Got HTTP ${response.statusCode}");
      }
    }

    final departures = <Departure>[];

    // now collate the reports
    for (final reportSpec in reportSpecs) {
      final response = motorwayResponses[reportSpec.motorway];
      if (response == null) {
        return StationData.error("missing report for ${reportSpec.motorway}");
      }
      final averageSpeed = parseSingleReport(reportSpec, response);
      if (averageSpeed == null) {
        return StationData.error(
          "malformed JSON for ${reportSpec.fromJunctionName}->${reportSpec.toJunctionName}",
        );
      }
      departures.add(averageSpeedToDeparture(reportSpec, averageSpeed));
    }

    return StationData.departures(departures);
  }

  // return avgerage speed or null on err
  // Look at traffic_england_m25.json for example of what we're parsing
  double? parseSingleReport(
    TrafficReportSpec spec,
    Map<String, dynamic> api_response,
  ) {
    for (final junctionData in api_response.values) {
      if (junctionData is! Map<String, dynamic>) continue;
      final junctionSectionKeys = [
        "primaryUpstreamJunctionSection",
        "primaryDownstreamJunctionSection",
        "secondaryUpstreamJunctionSection",
        "secondaryDownstreamJunctionSection",
      ];
      for (final sectionKey in junctionSectionKeys) {
        final sectionData = junctionData[sectionKey];
        if (sectionData == null || sectionData is! Map<String, dynamic>) {
          continue;
        }

        final upstreamJunction = sectionData["upStreamJunctionDescription"];
        final downstreamJunction = sectionData["downStreamJunctionDescription"];
        if (spec.fromJunctionName == upstreamJunction &&
            spec.toJunctionName == downstreamJunction) {
          final avgSpeed = sectionData["avgSpeed"];
          if (avgSpeed is num) {
            return avgSpeed.toDouble();
          }
        }
      }
    }
  }

  Departure averageSpeedToDeparture(
    TrafficReportSpec spec,
    double averageSpeed,
  ) {
    var type = DepartureType.normal;

    if (averageSpeed < redSpeedThresh) {
      type = DepartureType.cancelled;
    } else if (averageSpeed < yellowSpeedThresh) {
      type = DepartureType.delayed;
    }
    final speed = averageSpeed.round().toString();
    return Departure.traffic(
      leftmostText: spec.name,
      rightmostText: "${speed}mph",
      type: type,
    );
  }
}
