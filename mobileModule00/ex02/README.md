# Exercise 02: More Buttons

This Flutter app shows a calculator screen.

The title is `Calculator`. Two text fields show `0`. One field is for the expression. The other field is for the result.

The screen has buttons for digits, a decimal point, four operators, `AC`, `C`, and `=`. Press a button. The app writes its text to the debug console. The values in the text fields do not change in this exercise.

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
cd /sgoinfre/goinfre/Perso/hguo/hguo/mobile0/mobileModule00/ex02
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/android-studio-rabbit1-linux/android-studio/jbr \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```

Wait for the app to open. The first build can take several minutes.

## Stop the app and emulator

Press `q` in the Flutter terminal to stop the app.

Run `adb emu kill` in that terminal to close the emulator. You can also close the emulator window.
