import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class _JalurInformationParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    return routeInformation.location;
  }

  @override
  RouteInformation restoreRouteInformation(String configuration) {
    return RouteInformation(
      location: configuration,
    );
  }
}

class _JalurDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  String _current;
  Jalur route;
  _JalurDelegate({@required this.route});
  List<_RouteInfo> builders = [];

  @override
  String get currentConfiguration => builders?.last?.path ?? _current;

  @override
  Widget build(BuildContext context) {
    return Navigate(
      delegate: this,
      child: Navigator(
        key: navigatorKey,
        pages: [
          if (builders.isEmpty)
            MaterialPage<String>(
              name: '/splashscreen',
              child: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          if (builders.isNotEmpty)
            for (var entry in builders)
              MaterialPage<String>(
                name: entry.path,
                key: ValueKey(entry.path),
                child: _ParameterScope(
                  parameters: entry.parameters,
                  child: Builder(builder: entry.builder),
                ),
              ),
        ],
        onPopPage: (route, result) {
          if (!route.didPop(result)) {
            return false;
          }

          builders.removeLast();
          _current = builders.last.path;
          notifyListeners();
          return true;
        },
      ),
    );
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    _current = configuration;
    Map<String, String> parameters = {};
    builders = route._getBuilders(_current, parameters: parameters).toList();

    notifyListeners();
  }

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
}

class Navigate extends InheritedWidget {
  final _JalurDelegate delegate;
  Navigate({Key key, Widget child, @required this.delegate})
      : super(key: key, child: child);

  static RouterDelegate routerDelegate(Jalur route) =>
      _JalurDelegate(route: route);

  static RouteInformationParser routeInformationParser() =>
      _JalurInformationParser();

  static void to(BuildContext context, String url) {
    context
        .dependOnInheritedWidgetOfExactType<Navigate>()
        .delegate
        .setNewRoutePath(url);
  }

  static String parameter(BuildContext context, String name) {
    return context
        .dependOnInheritedWidgetOfExactType<_ParameterScope>()
        .parameters[name];
  }

  @override
  bool updateShouldNotify(Navigate oldWidget) {
    return true;
  }
}

class _ParameterScope extends InheritedWidget {
  final Map<String, String> parameters;
  _ParameterScope({Key key, Widget child, @required this.parameters})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_ParameterScope oldWidget) {
    return true;
  }
}

class Jalur {
  final Map<String, dynamic> _routes;
  final WidgetBuilder _root;
  Jalur({
    WidgetBuilder index,
    Map<String, dynamic> subRoutes,
  })  : _routes = subRoutes,
        _root = index;

  Map<String, WidgetBuilder> get routes {
    final result = <String, WidgetBuilder>{};
    for (var key in _routes.keys) {
      final val = _routes[key];
      if (val is Jalur) {
        final childRoutes = val.routes;
        for (var childKey in childRoutes.keys) {
          var path = "$key$childKey";
          if (path.length > 1 && path.endsWith("/")) {
            path = path.substring(0, path.length - 1);
          }

          result[path] = childRoutes[childKey];
        }
      }

      if (val is WidgetBuilder) {
        result[key] = val;
      }
    }

    return result;
  }

  Iterable<_RouteInfo> _getBuilders(
    String url, {
    String previous = "/",
    Map<String, String> parameters = const {},
  }) sync* {
    if (_root != null) {
      yield _RouteInfo(
        path: previous,
        builder: _root,
        parameters: parameters,
      );
    }

    if (previous.startsWith("/")) {
      previous = previous.substring(1);
    }

    if (url?.isEmpty ?? true) return;

    var segments = _extractURL(url).toList();
    if (segments.isEmpty) return;

    var key = segments.first;
    if (_routes.containsKey(key)) {
      final val = _routes[key];
      if (val is WidgetBuilder) {
        if (previous.startsWith("/")) {
          previous = previous.substring(1);
        }

        yield _RouteInfo(
          path: "/$previous/$key",
          builder: val,
          parameters: parameters,
        );
      }

      if (val is Jalur) {
        var temp = segments
            .sublist(1)
            .fold("", (previousValue, element) => previousValue + "/$element");

        if (previous.startsWith("/")) {
          previous = previous.substring(1);
        }

        var res = val._getBuilders(
          temp,
          previous: "/$previous/$key",
          parameters: parameters,
        );
        for (var item in res) {
          yield item;
        }
      }
    } else {
      var paramKey = _routes.keys.firstWhere(
        (element) => element.startsWith(":"),
        orElse: () => null,
      );

      if (paramKey != null) {
        parameters[paramKey.substring(1)] = key;

        final val = _routes[paramKey];
        if (val is WidgetBuilder) {
          if (previous.startsWith("/")) {
            previous = previous.substring(1);
          }

          yield _RouteInfo(
            path: "/$previous/$key",
            builder: val,
            parameters: parameters,
          );
        }

        if (val is Jalur) {
          var temp = segments.sublist(1).fold(
              "", (previousValue, element) => previousValue + "/$element");
          if (previous.startsWith("/")) {
            previous = previous.substring(1);
          }
          var res = val._getBuilders(
            temp,
            previous: "/$previous/$key",
            parameters: parameters,
          );
          for (var item in res) {
            yield item;
          }
        }
      }
    }
  }
}

class _RouteInfo {
  final WidgetBuilder builder;
  final String path;
  final Map<String, String> parameters;
  _RouteInfo({this.builder, this.path, this.parameters});
}

Iterable<String> _extractURL(String url) sync* {
  String current = '';
  for (var i = 0; i < url.length; i++) {
    var chr = url[i];
    if (chr == '/') {
      if (current.isNotEmpty) {
        yield current;
        current = '';
      }

      continue;
    }

    current += chr;
  }

  yield current;
}
