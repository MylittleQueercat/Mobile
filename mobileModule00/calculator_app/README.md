# Exercise 03: Calculator

This Flutter app has a calculator screen.

The first text field shows the expression. The second text field shows the result.

Press the digit and operator buttons to make an expression. Press `=` to calculate the result. The app calculates multiplication and division before addition and subtraction. You can use negative numbers and decimal numbers.

Press `C` to remove the last character. Press `AC` to clear the expression and the result.

If the expression is invalid or divides by zero, the result field shows `Error`. The app stays open.

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
cd /sgoinfre/goinfre/Perso/hguo/hguo/mobile0/mobileModule00/calculator_app
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/android-studio-rabbit1-linux/android-studio/jbr \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```

Wait for the app to open. The first build can take several minutes.

## Stop the app and emulator

Press `q` in the Flutter terminal to stop the app.

Run `adb emu kill` in that terminal to close the emulator. You can also close the emulator window.
