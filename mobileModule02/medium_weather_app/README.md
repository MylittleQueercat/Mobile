# Weather App

Piscine Mobile Module 02 app. It uses device location and Open-Meteo to show
current, hourly, and weekly forecasts. Search for a city to see matching
locations, then select one or submit the search directly. The three tabs keep
showing the latest forecast.

## Run on the Android emulator

Start the development environment and emulator in one terminal:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
emulator -avd Pixel_10
```

In a second terminal, run the app:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
cd /sgoinfre/goinfre/Perso/hguo/hguo/MobileRepo/mobileModule02/medium_weather_app
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/gradle-cache/jdks/eclipse_adoptium-17-amd64-linux.2 \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```
