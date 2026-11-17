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
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3977D5)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F8FC),
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
        'count': '8',
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
    appBar: AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: _onQueryChanged,
              onSubmitted: _submitSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search a city',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _locating ? null : _useLocation,
            tooltip: 'Use current location',
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_suggestions.isNotEmpty) _suggestionList(),
          if (_error != null) _errorBanner(),
          if (_loading || _locating) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabsController,
              children: [_currentView(), _todayView(), _weeklyView()],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
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
    ),
  );

  Widget _suggestionList() => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 250),
    child: Material(
      color: Colors.white,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = _suggestions[index];
          return ListTile(
            leading: const Icon(Icons.location_city),
            title: Text(place.name),
            subtitle: Text(
              [
                place.region,
                place.country,
              ].where((e) => e.isNotEmpty).join(', '),
            ),
            onTap: () => _selectPlace(place),
          );
        },
      ),
    ),
  );

  Widget _errorBanner() => Material(
    color: const Color(0xFFFFE8E6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFF8C1D18)),
            ),
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
    return _page('Current', [
      Text(
        f.place.label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 28),
      Icon(
        _weatherIcon(f.currentCode),
        size: 84,
        color: Theme.of(context).colorScheme.primary,
      ),
      Text(
        '${f.currentTemp.round()}°C',
        style: Theme.of(context).textTheme.displayLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(
        _weatherDescription(f.currentCode),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        'Wind ${f.currentWind.round()} km/h',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ]);
  }

  Widget _todayView() {
    final f = _forecast;
    if (f == null) return _emptyState('Today', Icons.today_outlined);
    final day = f.currentTime.substring(0, 10);
    final indices = <int>[];
    for (var i = 0; i < f.times.length; i++) {
      if (f.times[i].startsWith(day)) indices.add(i);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          f.place.label,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...indices.map(
          (i) => Card(
            child: ListTile(
              leading: Icon(
                _weatherIcon(f.hourCodes[i]),
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                '${f.hourTemps[i].round()}°C · ${_weatherDescription(f.hourCodes[i])}',
              ),
              subtitle: Text(
                '${f.times[i].substring(11, 16)}   •   Wind ${f.hourWinds[i].round()} km/h',
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          f.place.label,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...List.generate(
          f.days.length,
          (i) => Card(
            child: ListTile(
              leading: Icon(
                _weatherIcon(f.dayCodes[i]),
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(_formatDate(f.days[i])),
              subtitle: Text(_weatherDescription(f.dayCodes[i])),
              trailing: Text(
                '${f.minTemps[i].round()}° / ${f.maxTemps[i].round()}°',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String title, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 68, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Search for a city or use your location to load the forecast.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _page(String title, List<Widget> children) => LayoutBuilder(
    builder: (context, size) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: size.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _formatDate(String date) {
  final parsed = DateTime.parse(date);
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[parsed.weekday - 1]}, ${months[parsed.month - 1]} ${parsed.day}';
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
