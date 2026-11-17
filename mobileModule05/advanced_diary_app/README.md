# Advanced Daybook

Piscine Mobile Module 05 app, continued from Module 04. It includes Google and
GitHub sign-in, a profile with recent entries and mood statistics, and an agenda
calendar for browsing entries by date. Entries support five paper styles
(classic, ruled, grid, dotted, and linen), plus weekly mood and writing-prompt
widgets.

## Firebase setup

Register the Android app with package ID `com.example.diary_app`, enable Google
and GitHub sign-in, configure the GitHub OAuth callback shown by Firebase, and
create a Cloud Firestore database. Place your Firebase Android config at
`android/app/google-services.json` (ignored by Git; use your own project file).

Firestore rules should allow each signed-in user to read and write only their own
entries:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/entries/{entryId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## Run on the Android emulator

Start the development environment and emulator in one terminal:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
emulator -avd Pixel_10 -gpu host -feature -Vulkan
```

In another terminal, run the app:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
cd /sgoinfre/goinfre/Perso/hguo/hguo/MobileRepo/mobileModule05/advanced_diary_app
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/gradle-cache/jdks/eclipse_adoptium-17-amd64-linux.2 \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```
