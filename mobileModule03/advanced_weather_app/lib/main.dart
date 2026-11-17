import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const WeatherApp());

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Weather',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFB13B),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF090D0D),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    home: const WeatherHomePage(),
  );
}

class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region = '',
    this.country = '',
  });
  final String name;
  final double latitude;
  final double longitude;
  final String region;
  final String country;
  String get label => [
    name,
    if (region.isNotEmpty && region != name) region,
    if (country.isNotEmpty) country,
  ].join(', ');
}

class Forecast {
  const Forecast({
    required this.place,
    required this.currentTemp,
    required this.currentCode,
    required this.currentWind,
    required this.currentTime,
    required this.times,
    required this.hourTemps,
    required this.hourCodes,
    required this.hourWinds,
    required this.days,
    required this.minTemps,
    required this.maxTemps,
    required this.dayCodes,
  });
  final Place place;
  final double currentTemp;
  final int currentCode;
  final double currentWind;
  final String currentTime;
  final List<String> times;
  final List<double> hourTemps;
  final List<int> hourCodes;
  final List<double> hourWinds;
  final List<String> days;
  final List<double> minTemps;
  final List<double> maxTemps;
  final List<int> dayCodes;

  factory Forecast.fromJson(Place place, Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    return Forecast(
      place: place,
      currentTemp: _number(current['temperature_2m']),
      currentCode: _integer(current['weather_code']),
      currentWind: _number(current['wind_speed_10m']),
      currentTime: current['time'] as String,
      times: List<String>.from(hourly['time'] as List),
      hourTemps: (hourly['temperature_2m'] as List).map(_number).toList(),
      hourCodes: (hourly['weather_code'] as List).map(_integer).toList(),
      hourWinds: (hourly['wind_speed_10m'] as List).map(_number).toList(),
      days: List<String>.from(daily['time'] as List),
      minTemps: (daily['temperature_2m_min'] as List).map(_number).toList(),
      maxTemps: (daily['temperature_2m_max'] as List).map(_number).toList(),
      dayCodes: (daily['weather_code'] as List).map(_integer).toList(),
    );
  }
}

double _number(dynamic value) => (value as num).toDouble();
int _integer(dynamic value) => (value as num).toInt();

class WeatherApi {
  static Future<dynamic> _get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.userAgentHeader, 'MediumWeatherApp/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const WeatherException(
          'Could not connect to the weather service. Please try again.',
        );
      }
      return jsonDecode(body);
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(
        'Connection problem. Check your internet and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<Place>> search(String query) async {
    final data = await _get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '5',
        'language': 'en',
        'format': 'json',
      }),
    ) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];
    return results.map((item) {
      final row = item as Map<String, dynamic>;
      return Place(
        name: row['name'] as String,
        latitude: _number(row['latitude']),
        longitude: _number(row['longitude']),
        region: (row['admin1'] as String?) ?? '',
        country: (row['country'] as String?) ?? '',
      );
    }).toList();
  }

  static Future<Place> reverseGeocode(double latitude, double longitude) async {
    final data = await _get(
      Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'jsonv2',
        'zoom': '10',
      }),
    ) as Map<String, dynamic>;
    final address = data['address'] as Map<String, dynamic>? ?? {};
    final city =
        (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                address['county'] ??
                'Current location')
            as String;
    final region = (address['state'] ?? address['province'] ?? '') as String;
    final country = (address['country'] ?? '') as String;
    return Place(
      name: city,
      latitude: latitude,
      longitude: longitude,
      region: region,
      country: country,
    );
  }

  static Future<Forecast> forecast(Place place) async {
    final data = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${place.latitude}',
        'longitude': '${place.longitude}',
        'current': 'temperature_2m,weather_code,wind_speed_10m',
        'hourly': 'temperature_2m,weather_code,wind_speed_10m',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'forecast_days': '7',
        'timezone': 'auto',
        'wind_speed_unit': 'kmh',
      }),
    ) as Map<String, dynamic>;
    return Forecast.fromJson(place, data);
  }
}

class WeatherException implements Exception {
  const WeatherException(this.message);
  final String message;
}

class _WeatherTabData {
  const _WeatherTabData(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _tabs = <_WeatherTabData>[
  _WeatherTabData('Current', Icons.wb_sunny_outlined),
  _WeatherTabData('Today', Icons.today_outlined),
  _WeatherTabData('Weekly', Icons.calendar_view_week_outlined),
];

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});
  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabsController;
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<Place> _suggestions = [];
  Forecast? _forecast;
  String? _error;
  bool _loading = false;
  bool _locating = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _tabsController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _useLocation());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabsController.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await WeatherApi.search(query.trim());
        if (mounted && _search.text.trim() == query.trim()) {
          setState(() {
            _suggestions = results;
            _error = results.isEmpty ? 'No matching city found.' : null;
          });
        }
      } on WeatherException catch (error) {
        if (mounted)
          setState(() {
            _suggestions = [];
            _error = error.message;
          });
      }
    });
  }

  Future<void> _submitSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final results = await WeatherApi.search(query);
      if (results.isEmpty)
        throw const WeatherException(
          'City not found. Check the name and try again.',
        );
      await _loadPlace(results.first);
    } on WeatherException catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.message;
        });
    }
  }

  Future<void> _selectPlace(Place place) async {
    FocusScope.of(context).unfocus();
    _search.text = place.label;
    setState(() => _suggestions = []);
    await _loadPlace(place);
  }

  Future<void> _loadPlace(Place place) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await WeatherApi.forecast(place);
      if (mounted)
        setState(() {
          _forecast = result;
          _loading = false;
          _error = null;
        });
    } on WeatherException catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.message;
        });
    }
  }

  Future<void> _useLocation() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _locating = true;
      _error = null;
      _permissionDenied = false;
      _suggestions = [];
      _forecast = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const WeatherException(
          'Location services are off. Search for a city instead.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          setState(() {
            _permissionDenied = true;
            _locating = false;
            _error =
                'Location access denied. Search for a city to see its weather.';
          });
        return;
      }
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Current GPS fix failed: $error\n$stackTrace');
        throw const WeatherException(
          'Could not get a fresh GPS fix. Set the emulator location and try again.',
        );
      }
      debugPrint(
        'Current GPS fix: ${position.latitude}, ${position.longitude}',
      );

      Place place;
      try {
        place = await WeatherApi.reverseGeocode(
          position.latitude,
          position.longitude,
        );
      } catch (error, stackTrace) {
        debugPrint('Reverse geocoding failed: $error\n$stackTrace');
        place = Place(
          name: 'Current location',
          latitude: position.latitude,
          longitude: position.longitude,
          region:
              '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}',
        );
      }
      if (mounted)
        setState(() {
          _locating = false;
          _permissionDenied = false;
        });
      await _loadPlace(place);
    } on WeatherException catch (error) {
      if (mounted)
        setState(() {
          _locating = false;
          _error = error.message;
        });
    } catch (error, stackTrace) {
      debugPrint('Location lookup failed: $error\n$stackTrace');
      if (mounted)
        setState(() {
          _locating = false;
          _error = 'Unable to get your location. Search for a city instead.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/weather_background.png', fit: BoxFit.cover),
        ColoredBox(color: const Color(0xAA050909)),
        SafeArea(
          child: Column(
            children: [
              _searchBar(),
              if (_suggestions.isNotEmpty) _suggestionList(),
              if (_error != null) _errorBanner(),
              if (_loading || _locating)
                const LinearProgressIndicator(
                  color: Color(0xFFFFB13B),
                  minHeight: 2,
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabsController,
                  children: [_currentView(), _todayView(), _weeklyView()],
                ),
              ),
              _bottomTabs(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xD91A2020),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: TextField(
              controller: _search,
              onChanged: _onQueryChanged,
              onSubmitted: _submitSearch,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Search city, region or country',
                hintStyle: TextStyle(color: Color(0xFFABB2AE)),
                prefixIcon: Icon(Icons.search, color: Color(0xFFFFB13B)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFB13B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: _locating ? null : _useLocation,
            tooltip: 'Use current location',
            color: const Color(0xFF141712),
            icon: const Icon(Icons.near_me_rounded),
          ),
        ),
      ],
    ),
  );

  Widget _bottomTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xE6101515),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: AnimatedBuilder(
        animation: _tabsController,
        builder: (context, _) => Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _BottomTabButton(
                  tab: _tabs[i],
                  selected: _tabsController.index == i,
                  onTap: () => _tabsController.animateTo(i),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _suggestionList() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 74, 8),
    child: Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: const Color(0xF21A2020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
        itemBuilder: (context, index) {
          final place = _suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.location_on_outlined,
              color: Color(0xFFFFB13B),
            ),
            title: Text(
              place.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              [
                place.region,
                place.country,
              ].where((e) => e.isNotEmpty).join(' · '),
              style: const TextStyle(color: Color(0xFFB6C0B8)),
            ),
            onTap: () => _selectPlace(place),
          );
        },
      ),
    ),
  );

  Widget _errorBanner() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xDD401E1C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFFB4A9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: Colors.white)),
          ),
          if (_permissionDenied)
            TextButton(
              onPressed: () => _submitSearch(_search.text),
              child: const Text('Search'),
            ),
        ],
      ),
    ),
  );

  Widget _currentView() {
    final f = _forecast;
    if (f == null) return _emptyState('Current', Icons.cloud_outlined);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                f.place.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF68D8D0),
                ),
              ),
              Text(
                [
                  f.place.region,
                  f.place.country,
                ].where((s) => s.isNotEmpty).join(', '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD0D5CF), fontSize: 14),
              ),
              const SizedBox(height: 30),
              Icon(
                _weatherIcon(f.currentCode),
                size: 76,
                color: const Color(0xFF4DD9D0),
              ),
              const SizedBox(height: 4),
              Text(
                '${f.currentTemp.round()}°C',
                style: const TextStyle(
                  fontSize: 76,
                  height: 1.05,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFFFB13B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _weatherDescription(f.currentCode),
                style: const TextStyle(fontSize: 21, color: Colors.white),
              ),
              const SizedBox(height: 26),
              _GlassPanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.air_rounded, color: Color(0xFF4DD9D0)),
                    const SizedBox(width: 9),
                    Text(
                      'Wind  ${f.currentWind.round()} km/h',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayView() {
    final f = _forecast;
    if (f == null) return _emptyState('Today', Icons.today_outlined);
    final day = f.currentTime.substring(0, 10);
    final indices = [
      for (var i = 0; i < f.times.length; i++)
        if (f.times[i].startsWith(day)) i,
    ];
    final temps = indices.map((i) => f.hourTemps[i]).toList();
    final labels = indices.map((i) => f.times[i].substring(11, 13)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      children: [
        _locationHeading(f.place),
        const SizedBox(height: 18),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TODAY'S TEMPERATURE", style: _sectionLabel),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: _TemperatureChart(
                  values: temps,
                  labels: labels,
                  color: const Color(0xFFFFB13B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('HOURLY FORECAST', style: _sectionLabel),
        const SizedBox(height: 8),
        ...indices.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      f.times[i].substring(11, 16),
                      style: const TextStyle(color: Color(0xFFD0D5CF)),
                    ),
                  ),
                  Icon(
                    _weatherIcon(f.hourCodes[i]),
                    color: const Color(0xFF4DD9D0),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _weatherDescription(f.hourCodes[i]),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    '${f.hourTemps[i].round()}°',
                    style: const TextStyle(
                      color: Color(0xFFFFB13B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${f.hourWinds[i].round()} km/h',
                    style: const TextStyle(
                      color: Color(0xFFB6C0B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _weeklyView() {
    final f = _forecast;
    if (f == null)
      return _emptyState('Weekly', Icons.calendar_view_week_outlined);
    final count = f.days.length.clamp(0, 7);
    final labels = f.days.take(count).map((d) => _weekdayShort(d)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      children: [
        _locationHeading(f.place),
        const SizedBox(height: 18),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('7-DAY TEMPERATURE RANGE', style: _sectionLabel),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                child: _TemperatureChart(
                  values: f.maxTemps.take(count).toList(),
                  secondValues: f.minTemps.take(count).toList(),
                  labels: labels,
                  color: const Color(0xFFFFB13B),
                  secondColor: const Color(0xFF4DD9D0),
                  legend: const ['Max', 'Min'],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('DAILY FORECAST', style: _sectionLabel),
        const SizedBox(height: 8),
        ...List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      _weekdayShort(f.days[i]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _weatherIcon(f.dayCodes[i]),
                    color: const Color(0xFF4DD9D0),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _weatherDescription(f.dayCodes[i]),
                      style: const TextStyle(color: Color(0xFFD0D5CF)),
                    ),
                  ),
                  Text(
                    '${f.minTemps[i].round()}°',
                    style: const TextStyle(color: Color(0xFF4DD9D0)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${f.maxTemps[i].round()}°',
                    style: const TextStyle(
                      color: Color(0xFFFFB13B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationHeading(Place place) => Column(
    children: [
      Text(
        place.label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF68D8D0),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'LOCAL FORECAST',
        style: TextStyle(
          color: Color(0xFF9AA59F),
          fontSize: 10,
          letterSpacing: 2,
        ),
      ),
    ],
  );

  Widget _emptyState(String title, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: _GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFF4DD9D0)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 23,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for a city or use your location to load the forecast.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB6C0B8)),
            ),
          ],
        ),
      ),
    ),
  );
}

const _sectionLabel = TextStyle(
  color: Color(0xFFB7C2BC),
  fontSize: 11,
  letterSpacing: 1.6,
  fontWeight: FontWeight.w700,
);

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xE6111717),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .10)),
    ),
    child: child,
  );
}

class _TemperatureChart extends StatelessWidget {
  const _TemperatureChart({
    required this.values,
    required this.labels,
    required this.color,
    this.secondValues = const [],
    this.secondColor = const Color(0xFF4DD9D0),
    this.legend = const [],
  });
  final List<double> values;
  final List<double> secondValues;
  final List<String> labels;
  final Color color;
  final Color secondColor;
  final List<String> legend;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TemperatureChartPainter(
      values: values,
      secondValues: secondValues,
      labels: labels,
      color: color,
      secondColor: secondColor,
    ),
    child: Align(
      alignment: Alignment.topRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < legend.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: i == 0 ? color : secondColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    legend[i],
                    style: const TextStyle(
                      color: Color(0xFFD0D5CF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _TemperatureChartPainter extends CustomPainter {
  _TemperatureChartPainter({
    required this.values,
    required this.secondValues,
    required this.labels,
    required this.color,
    required this.secondColor,
  });
  final List<double> values, secondValues;
  final List<String> labels;
  final Color color, secondColor;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 30.0, top = 24.0, right = 8.0, bottom = 25.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final all = [...values, ...secondValues];
    var min = all.reduce((a, b) => a < b ? a : b);
    var max = all.reduce((a, b) => a > b ? a : b);
    if (max - min < 4) {
      min -= 2;
      max += 2;
    }
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: Color(0xFF9AA59F), fontSize: 9);
    for (var row = 0; row <= 3; row++) {
      final y = plot.top + plot.height * row / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawText(
        canvas,
        '${(max - (max - min) * row / 3).round()}°',
        Offset(0, y - 6),
        labelStyle,
      );
    }
    void drawSeries(List<double> series, Color strokeColor) {
      if (series.isEmpty) return;
      final path = Path();
      final points = <Offset>[];
      for (var i = 0; i < series.length; i++) {
        final x =
            plot.left +
            (series.length == 1 ? 0 : plot.width * i / (series.length - 1));
        final y = plot.bottom - ((series[i] - min) / (max - min)) * plot.height;
        final p = Offset(x, y);
        points.add(p);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (final point in points) {
        canvas.drawCircle(point, 3.2, Paint()..color = strokeColor);
        canvas.drawCircle(point, 1.3, Paint()..color = const Color(0xFF111717));
      }
    }

    drawSeries(values, color);
    drawSeries(secondValues, secondColor);
    if (labels.isNotEmpty) {
      final stride = labels.length > 8 ? (labels.length / 6).ceil() : 1;
      for (var i = 0; i < labels.length; i += stride) {
        final x =
            plot.left +
            (labels.length == 1 ? 0 : plot.width * i / (labels.length - 1));
        _drawText(
          canvas,
          labels[i],
          Offset(x - 11, plot.bottom + 7),
          labelStyle,
        );
      }
      if ((labels.length - 1) % stride != 0)
        _drawText(
          canvas,
          labels.last,
          Offset(plot.right - 19, plot.bottom + 7),
          labelStyle,
        );
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter old) =>
      old.values != values ||
      old.secondValues != secondValues ||
      old.labels != labels;
}

String _weekdayShort(String date) {
  final weekday = DateTime.parse(date).weekday;
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[weekday - 1];
}

String _weatherDescription(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 3) return 'Partly cloudy';
  if (code == 45 || code == 48) return 'Fog';
  if (code <= 57) return 'Drizzle';
  if (code <= 67) return 'Rain';
  if (code <= 77) return 'Snow';
  if (code <= 82) return 'Rain showers';
  if (code <= 86) return 'Snow showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Cloudy';
}

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code >= 95) return Icons.thunderstorm_outlined;
  if (code == 45 || code == 48) return Icons.foggy;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
    return Icons.water_drop_outlined;
  if (code >= 71 && code <= 86) return Icons.ac_unit;
  return Icons.cloud_outlined;
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  final _WeatherTabData tab;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, color: color),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
