import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'departure_model.dart';
import 'shared_widgets.dart';

class StationWidget extends StatelessWidget {
  final String name;
  final StationLogo logo;
  final StationData station;

  /// Limit number of departures to this. If zero, unlimited
  final int depRowLimit;

  const StationWidget({
    super.key,
    required this.station,
    required this.name,
    required this.logo,
    required this.depRowLimit,
  });

  @override
  Widget build(BuildContext context) {
    final svgHeight = 30.0;

    Widget logoWidget;
    switch (logo) {
      case StationLogo.southWesternRailway:
        logoWidget = SvgPicture.asset("assets/swr_logo.svg", height: svgHeight);
        break;
      case StationLogo.thamesLink:
        logoWidget = SvgPicture.asset(
          "assets/thameslink_logo.svg",
          height: svgHeight,
        );
        break;
      case StationLogo.tflBus:
        logoWidget = SvgPicture.asset(
          "assets/buses_roundel.svg",
          height: svgHeight,
        );
        break;
      case StationLogo.digico:
        logoWidget = SvgPicture.asset("assets/digico.svg", height: svgHeight);
        break;
      case StationLogo.highway:
        logoWidget = SvgPicture.asset(
          "assets/uk_motorway_symbol.svg",
          height: svgHeight,
        );
        break;
    }

    List<Widget> departuresList;
    if (station.errorText != null) {
      departuresList = [ErrorBoxWidget(errorText: station.errorText!)];
    } else {
      var depWidgets = station.departures.map(
        (dep) => DepartureWidget(departure: dep),
      );
      if (depRowLimit != 0) {
        departuresList = depWidgets.take(depRowLimit).toList();
      } else {
        departuresList = depWidgets.toList();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TitleCard(title: name, icon: logoWidget),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: departuresList),
            ),
          ),
        ],
      ),
    );
  }
}

class DepartureWidget extends StatelessWidget {
  const DepartureWidget({super.key, required this.departure});

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bg;
    Color fg;
    switch (departure.type) {
      case DepartureType.normal:
        bg = theme.colorScheme.primary;
        fg = theme.colorScheme.onPrimary;
        break;
      case DepartureType.delayed:
        bg = theme.colorScheme.secondary;
        fg = theme.colorScheme.onSecondary;
        break;
      case DepartureType.cancelled:
        bg = theme.colorScheme.tertiary;
        fg = theme.colorScheme.onTertiary;
        break;
    }

    final timeTextDecoration =
        departure.timeStrikethrough
            ? TextDecoration.lineThrough
            : TextDecoration.none;

    IconData icon;
    Color iconColor;
    switch (departure.icon) {
      case DepartureIcon.none:
        icon = Icons.abc;
        iconColor = Colors.black;
        break;
      case DepartureIcon.check:
        icon = Icons.check_rounded;
        iconColor = theme.colorScheme.onPrimaryFixed;
        break;
      case DepartureIcon.live:
        icon = Icons.rss_feed;
        iconColor = theme.colorScheme.onPrimaryFixedVariant;
        break;
      case DepartureIcon.scheduled:
        icon = Icons.calendar_month;
        iconColor = theme.colorScheme.onPrimaryFixed;
        break;
      case DepartureIcon.speed:
        icon = Icons.speed;
        iconColor = theme.colorScheme.onPrimaryFixed;
        break;
    }

    return Container(
      padding: EdgeInsets.only(top: 5, bottom: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 10),
          child: Row(
            spacing: 30,
            children: [
              Text(
                departure.leftmostText,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: fg,
                  decoration: timeTextDecoration,
                ),
              ),
              Expanded(
                child: Row(
                  spacing: 5,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (departure.rightmostText != null)
                      Flexible(
                        child: Text(
                          departure.rightmostText!,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: fg,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    if (departure.icon != DepartureIcon.none)
                      Icon(icon, color: iconColor, size: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
