import 'dart:async';

import 'package:depboard2_flutter/ldbws_api.dart';
import 'package:depboard2_flutter/tfl_api.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// import 'package:window_manager/window_manager.dart';
import 'departure_model.dart';
import 'departure_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await windowManager.ensureInitialized();
  // final options = WindowOptions(size: Size(1920, 360));
  // await windowManager.waitUntilReadyToShow(options, () async {
  //   await windowManager.show();
  //   await windowManager.focus();
  // });

  final state = TrainboardState([
    TflBusDepartureService(
      naptanCodes: ["490011796S", "490011796N"],
      name: "Rushett Lane Bus",
      // No one gives a fuck that it's deepdene
      commonLocationNames: {"Dorking, Deepdene": "Dorking"},
    ),
    LdbwsService(
      crs: "CSS",
      name: "Chessington",
      logo: StationLogo.southWesternRailway,
      reportDestination: false,
    ),
    LdbwsService(
      crs: "WIM",
      name: "Wim Thameslink",
      logo: StationLogo.thamesLink,
      reportDestination: true,
      operatorCodeFilter: "TL",
    ),
  ], depRowLimit: 5);

  await state.runInitialQueries();

  runApp(
    ChangeNotifierProvider(
      create: (context) => state,
      child: const TrainboardApp(),
    ),
  );
}

class StationDepartureState {
  final StationDepartureService service;
  StationData data = StationData.error("Not yet polled");

  StationDepartureState({required this.service});
}

class TrainboardState extends ChangeNotifier {
  late final List<StationDepartureState> stationStates;
  final int depRowLimit;

  TrainboardState(
    List<StationDepartureService> services, {
    this.depRowLimit = 0,
  }) {
    stationStates =
        services.map((service) {
          var depState = StationDepartureState(service: service);
          Timer.periodic(
            service.pollTime,
            (t) async => onTimerExpired(depState),
          );
          return depState;
        }).toList();
  }

  Future<void> onTimerExpired(StationDepartureState state) async {
    state.data = await state.service.getLatest();
    // TODO(liam) change notification could be per-service to avoid everything
    // redrawing
    notifyListeners();
  }

  Future<void> runInitialQueries() async {
    final queries = stationStates.map((s) => s.service.getLatest()).toList();
    await Future.wait(queries);
  }
}

class TrainboardApp extends StatelessWidget {
  const TrainboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final commonTextColor = Color(0xffeeeeee);
    return MaterialApp(
      title: 'Trainboard',
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xff212121),
        useMaterial3: false,
        colorScheme: ColorScheme.dark(
          // primary = normal
          primary: Color(0xff313131),
          onPrimary: commonTextColor,

          // secondary = delayed
          secondary: Color(0xff664f0e),
          onSecondary: commonTextColor,

          // tertiary = cancelled
          tertiary: Color(0xff5a1919),
          onTertiary: commonTextColor,

          // used for lowkey icons on primary
          onPrimaryFixed: Color(0xff5b5b5b),
          // used for pop icons on primary
          onPrimaryFixedVariant: Color(0xffc5b019),
        ),
        textTheme: TextTheme(
          titleMedium: GoogleFonts.roboto(
            fontSize: 38,
            fontWeight: FontWeight.w200,
          ),
          bodyMedium: GoogleFonts.robotoMono(
            fontSize: 35,
            fontWeight: FontWeight.normal,
          ),
          bodySmall: GoogleFonts.robotoMono(
            fontSize: 20,
            fontWeight: FontWeight.w200,
          ),
        ),
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TrainboardState>(
        builder: (_, state, _) {
          return Row(
            children:
                state.stationStates
                    .map(
                      (station) => Expanded(
                        child: StationWidget(
                          station: station.data,
                          name: station.service.name,
                          logo: station.service.logo,
                          depRowLimit: state.depRowLimit,
                        ),
                      ),
                    )
                    .toList(),
          );
        },
      ),
    );
  }
}

