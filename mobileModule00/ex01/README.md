# Exercise 01: Say Hello to the World

This Flutter app has one page.

The page shows `Hello!` and a `Press me` button. Both items are at the center of the screen.

Press the button. The text changes to `Hello World!`. Press the button again. The text changes back to `Hello!`. Each press also writes `Button pressed` to the debug console.

## Start the emulator

Open a terminal. Run these commands:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
export ANDROID_AVD_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/android-avd
emulator -avd Pixel_10
```

Wait for the Android screen to appear.

## Run the app

Open a second terminal. Run these commands:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
cd /sgoinfre/goinfre/Perso/hguo/hguo/mobile0/mobileModule00/ex01
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/android-studio-rabbit1-linux/android-studio/jbr \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```

Wait for the app to open. The first build can take several minutes.

## Stop the app and emulator

Press `q` in the Flutter terminal to stop the app.

Run `adb emu kill` in that terminal to close the emulator. You can also close the emulator window.
