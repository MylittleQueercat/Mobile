# Weather App

Piscine Mobile Module 03 app. It continues the Module 02 weather app with a
fixed illustrated background, a styled city search with up to five suggestions,
and temperature charts for today and the coming week.

## Run on the Android emulator

Start the development environment and emulator in one terminal:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
emulator -avd Pixel_10
```

In a second terminal, run the app:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
cd /sgoinfre/goinfre/Perso/hguo/hguo/MobileRepo/mobileModule03/advanced_weather_app
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/gradle-cache/jdks/eclipse_adoptium-17-amd64-linux.2 \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```
