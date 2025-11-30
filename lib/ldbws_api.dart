import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';
import 'departure_model.dart';
import 'package:http/http.dart' as http;

// TODO(liam)
const String API_KEY = "e3d8b441-61aa-4ce8-9709-6872af719b2a";

/// API:
/// https://realtime.nationalrail.co.uk/OpenLDBWS/
class LdbwsService extends StationDepartureService {
  final String crs;
  final bool reportDestination;
  final String? operatorCodeFilter;
  final numRowsToRequest = 50;

  LdbwsService({
    required this.crs,
    required super.name,
    required super.logo,
    this.reportDestination = false,
    this.operatorCodeFilter,
  }) : super(pollTime: Duration(seconds: 5));

  @override
  Future<StationData> getLatest() async {
    try {
      // I don't actually know anything about the SOAP protocol or WSDL.
      // This was done via reverse engineering with wireshark and is definitely
      // no where near actual compliance with SOAP
      final wsdlResponse = await http.get(
        Uri.parse(
          "https://lite.realtime.nationalrail.co.uk/OpenLDBWS/wsdl.aspx?ver=2021-11-01",
        ),
      );
      if (wsdlResponse.statusCode != 200) {
        return StationData.error("Got HTTP ${wsdlResponse.statusCode}");
      }
      final wsdl = XmlDocument.parse(wsdlResponse.body);

      // return from API eg:
      //
      // <?xml version="1.0" encoding="utf-8"?>
      // <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/" xmlns:tns="http://thalesgroup.com/RTTI/2021-11-01/ldb/" targetNamespace="http://thalesgroup.com/RTTI/2021-11-01/ldb/">

      // <wsdl:import namespace="http://thalesgroup.com/RTTI/2021-11-01/ldb/" location="rtti_2021-11-01_ldb.wsdl" />

      // <wsdl:service name="ldb">
      //   <wsdl:port name="LDBServiceSoap" binding="tns:LDBServiceSoap">
      //     <soap:address location="https://lite.realtime.nationalrail.co.uk/OpenLDBWS/ldb12.asmx" />
      //   </wsdl:port>
      //   <wsdl:port name="LDBServiceSoap12" binding="tns:LDBServiceSoap12">
      //     <soap12:address location="https://lite.realtime.nationalrail.co.uk/OpenLDBWS/ldb12.asmx" />
      //   </wsdl:port>
      // </wsdl:service>

      // </wsdl:definitions>
      final soap12Location =
          wsdl
              .xpath(
                "/wsdl:definitions/wsdl:service/wsdl:port/soap12:address/@location[1]",
              )
              .firstOrNull
              ?.value;

      if (soap12Location == null) {
        return StationData.error(
          "Unable to locate soap12 location:\n${wsdlResponse.body}",
        );
      }

      // <soap-env:Envelope
      // 	xmlns:soap-env="http://schemas.xmlsoap.org/soap/envelope/">
      // 	<soap-env:Header>
      // 		<ns0:AccessToken
      // 			xmlns:ns0="http://thalesgroup.com/RTTI/2013-11-28/Token/types">
      // 			<ns0:TokenValue>e3d8b441-61aa-4ce8-9709-6872af719b2a</ns0:TokenValue>
      // 		</ns0:AccessToken>
      // 	</soap-env:Header>
      // 	<soap-env:Body>
      // 		<ns0:GetDepartureBoardRequest
      // 			xmlns:ns0="http://thalesgroup.com/RTTI/2021-11-01/ldb/">
      // 			<ns0:numRows>30</ns0:numRows>
      // 			<ns0:crs>KGX</ns0:crs>
      // 		</ns0:GetDepartureBoardRequest>
      // 	</soap-env:Body>
      // </soap-env:Envelope>

      final builder = XmlBuilder();
      builder.processing('xml', "version='1.0' encoding='utf-8'");
      final soapEnvNs = "http://schemas.xmlsoap.org/soap/envelope/";
      final tokenNs = "http://thalesgroup.com/RTTI/2013-11-28/Token/types";
      final ldbNs = "http://thalesgroup.com/RTTI/2021-11-01/ldb/";

      builder.element(
        "Envelope",
        namespace: soapEnvNs,
        nest: () {
          builder.namespace(soapEnvNs, "soap-env");
          builder.element(
            "Header",
            namespace: soapEnvNs,
            nest: () {
              builder.element(
                "AccessToken",
                namespace: tokenNs,
                nest: () {
                  builder.namespace(tokenNs, "token");
                  builder.element(
                    "TokenValue",
                    namespace: tokenNs,
                    nest: () {
                      builder.text(API_KEY);
                    },
                  );
                },
              );
            },
          );
          builder.element(
            "Body",
            namespace: soapEnvNs,
            nest: () {
              builder.element(
                "GetDepartureBoardRequest",
                namespace: ldbNs,
                nest: () {
                  builder.namespace(ldbNs, "ldb");
                  builder.element(
                    "numRows",
                    namespace: ldbNs,
                    nest: () {
                      builder.text(numRowsToRequest.toString());
                    },
                  );
                  builder.element(
                    "crs",
                    namespace: ldbNs,
                    nest: () {
                      builder.text(crs);
                    },
                  );
                },
              );
            },
          );
        },
      );

      // DANGER: the default XmlDocument.toString pretty-prints it. This adds
      // undue whitespace in the AccessToken/TokenValue field which breaks the
      // auth because of shit implementation on LDBWS's side.
      //
      // Explicitly don't pretty print it so there's no whitespace around the
      // auth token
      final depboardRequestDoc = builder.buildDocument().toXmlString(
        pretty: false,
      );

      final soap12Response = await http.post(
        headers: {
          "Content-Type": "text/xml; charset=utf-8",
          "SOAPAction":
              "\"http://thalesgroup.com/RTTI/2012-01-13/ldb/GetDepartureBoard\"",
        },
        Uri.parse(soap12Location),
        body: depboardRequestDoc,
      );

      return parseGetDepartureBoardResponse(soap12Response.body);
    } catch (e) {
      return StationData.error("$e");
    }
  }

  StationData parseGetDepartureBoardResponse(String responseBody) {
    // local-name() selects node name without namespace as all of the results
    // have namespace spam
    final servicesQuery =
        "/soap:Envelope/soap:Body/*[local-name() = 'GetDepartureBoardResponse']/*[local-name() = 'GetStationBoardResult']/*[local-name() = 'trainServices']/*[local-name() = 'service']";
    final doc = XmlDocument.parse(responseBody);
    final results = doc.xpath(servicesQuery);
    // <lt8:service>
    //     <lt4:std>22:00</lt4:std>
    //     <lt4:etd>On time</lt4:etd>
    //     <lt4:platform>5</lt4:platform>
    //     <lt4:operator>
    //         London North Eastern Railway
    //     </lt4:operator>
    //     <lt4:operatorCode>GR</lt4:operatorCode>
    //     <lt4:serviceType>train</lt4:serviceType>
    //     <lt4:serviceID>447492KNGX____</lt4:serviceID>
    //     <lt5:rsid>GR474100</lt5:rsid>
    //     <lt5:origin>
    //         <lt4:location>
    //             <lt4:locationName>
    //                 London Kings Cross
    //             </lt4:locationName>
    //             <lt4:crs>KGX</lt4:crs>
    //         </lt4:location>
    //     </lt5:origin>
    //     <lt5:destination>
    //         <lt4:location>
    //             <lt4:locationName>Newcastle</lt4:locationName>
    //             <lt4:crs>NCL</lt4:crs>
    //         </lt4:location>
    //     </lt5:destination>
    // </lt8:service>
    final departures = results
        .where((node) {
          // Filter based on op code if applicable
          if (operatorCodeFilter != null) {
            final operatorCodeNode =
                node.xpath("*[local-name()='operatorCode']").firstOrNull;
            if (operatorCodeNode == null) {
              throw Exception("Couldn't find `std` node via xpath query");
            }
            if (operatorCodeFilter!.toLowerCase() !=
                operatorCodeNode.innerText.toLowerCase()) {
              return false;
            }
          }
          return true;
        })
        .map((node) {
          final stdNode = node.xpath("*[local-name()='std']").firstOrNull;
          if (stdNode == null) {
            throw Exception("Couldn't find `std` node via xpath query");
          }

          final etdNode = node.xpath("*[local-name()='etd']").firstOrNull;
          if (etdNode == null) {
            throw Exception("Couldn't find `etd` node via xpath query");
          }
          var type = DepartureType.normal;
          String? secondaryText = etdNode.innerText;
          switch (etdNode.innerText.toLowerCase()) {
            case "on time":
              type = DepartureType.normal;
              secondaryText = null;
              break;
            case "cancelled":
            case "no report":
              type = DepartureType.cancelled;
              break;
            default:
              type = DepartureType.delayed;
              break;
          }

          if (reportDestination) {
            final destNode =
                node
                    .xpath(
                      "*[local-name()='destination']/*[local-name()='location']/*[local-name()='locationName']",
                    )
                    .firstOrNull;
            // messy but who cares
            if (destNode != null) {
              if (secondaryText == null) {
                secondaryText = "${destNode.innerText}";
              } else {
                secondaryText = "$secondaryText ${destNode.innerText}";
              }

            }
          }

          return Departure.train(
            leftmostText: stdNode.innerText,
            type: type,
            rightmostText: secondaryText,
          );
        });
    return StationData.departures(departures.toList());
  }
}
