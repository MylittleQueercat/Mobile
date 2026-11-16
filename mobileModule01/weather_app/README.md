# Weather App

Piscine Mobile Module 01 app. The search field and geolocation button update the
result shown on all three tabs. Tabs can be changed by tapping the bottom bar or
swiping between pages.

## Run on the Android emulator

Start the development environment and emulator in one terminal:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
emulator -avd Pixel_10
```

In a second terminal, run the app:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
cd /sgoinfre/goinfre/Perso/hguo/hguo/MobileRepo/mobileModule01/weather_app
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/android-studio-rabbit1-linux/android-studio/jbr \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```
